#!/usr/bin/env bash
#
# Copy AIDB artifacts (produced by aidb-builder.Dockerfile) into each running
# WHPG container. Skips the gpfdist container — it's a file server, not a DB.
#
# Usage:
#   ./aidb-install.sh [path/to/aidb-out]   # default: ./aidb-out
set -euo pipefail

OUT_DIR="${1:-$(dirname "$0")/aidb-out}"
LIB_DIR="${OUT_DIR}/lib"
EXT_DIR="${OUT_DIR}/extension"

if [[ ! -f "${LIB_DIR}/aidb.so" || ! -f "${EXT_DIR}/aidb.control" ]]; then
    echo "ERROR: expected aidb.so in ${LIB_DIR}/ and aidb.control in ${EXT_DIR}/" >&2
    echo "Did you run the aidb-builder image first?" >&2
    exit 1
fi

# WHPG install prefix inside the container
GPHOME=/usr/local/greenplum-db
TARGET_LIB="${GPHOME}/lib/postgresql"
TARGET_EXT="${GPHOME}/share/postgresql/extension"

CONTAINERS=(
    warehousepg7-from-rpms-rh9-multi-node-coordinator-1
    warehousepg7-from-rpms-rh9-multi-node-standby-1
    warehousepg7-from-rpms-rh9-multi-node-seg1-1
    warehousepg7-from-rpms-rh9-multi-node-seg2-1
)

for c in "${CONTAINERS[@]}"; do
    if ! docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
        echo "SKIP: $c not running" >&2
        continue
    fi
    echo "==> $c"
    docker cp "${LIB_DIR}/aidb.so"           "${c}:${TARGET_LIB}/aidb.so"
    docker cp "${EXT_DIR}/aidb.control"      "${c}:${TARGET_EXT}/aidb.control"
    for f in "${EXT_DIR}"/aidb--*.sql; do
        docker cp "$f" "${c}:${TARGET_EXT}/$(basename "$f")"
    done
done

# Register AIDB in shared_preload_libraries cluster-wide and restart. Needed
# for AIDB's background workers, and the restart also makes postgres pick up
# the freshly-copied aidb.so (any earlier version would still be mapped into
# the running postmaster's memory).
COORDINATOR=warehousepg7-from-rpms-rh9-multi-node-coordinator-1
echo ""
echo "==> Setting shared_preload_libraries='aidb' and restarting the cluster"

# pg_isready needs LD_LIBRARY_PATH from greenplum_path.sh or it can't find
# its own libpq.so.5. Source it explicitly, otherwise this check gives a
# false "not reachable" result on a perfectly healthy cluster.
if ! docker exec -u gpadmin "$COORDINATOR" bash -lc '
    source /usr/local/greenplum-db/greenplum_path.sh
    pg_isready -h 127.0.0.1 -p 5432 -U gpadmin -d postgres -q
' >/dev/null 2>&1; then
    cat >&2 <<EOF

WARN: coordinator DB is not reachable. Skipping gpconfig + restart.
      Once the cluster is up, run manually:
        docker exec -u gpadmin -it $COORDINATOR bash -lc \\
          "source /usr/local/greenplum-db/greenplum_path.sh && \\
           gpconfig -c shared_preload_libraries -v \"'aidb'\" && \\
           gpstop -a -M fast && gpstart -a"
EOF
    exit 0
fi

# Pass the value BARE (no quotes) — gpconfig wraps the value in single
# quotes itself when it writes postgresql.conf. Passing "'aidb'" here
# ended up writing shared_preload_libraries='''aidb''', which postgres
# parses as a string literally containing single quotes, and refuses
# to start with "could not access file ''aidb''".
docker exec -u gpadmin "$COORDINATOR" bash -lc '
    set -e
    source /usr/local/greenplum-db/greenplum_path.sh
    gpconfig -c shared_preload_libraries -v aidb
    # AIDB spawns 2 bgworkers per non-template DB plus one per pipeline,
    # on top of what WHPG itself uses (FTS probe, WAL sender/receiver,
    # autovacuum, GP-internal workers). WHPG default (13) runs out fast.
    gpconfig -c max_worker_processes -v 32
    echo ""
    echo ">>> Restarting cluster"
    gpstop -a -M fast
    gpstart -a
    echo ""
    gpconfig -s shared_preload_libraries
    gpconfig -s max_worker_processes
'

cat <<EOF

AIDB installed and enabled in shared_preload_libraries.
To create the extension:
  make psql-coordinator
  # then in psql:
  CREATE EXTENSION aidb CASCADE;
EOF
