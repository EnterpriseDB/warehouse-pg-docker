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

cat <<EOF

Copied AIDB artifacts into all running WHPG DB containers.

Next steps (inside coordinator):
  # if AIDB needs to be preloaded, add to postgresql.conf and restart:
  #   shared_preload_libraries = 'aidb'         # add 'vchord' too if you built with it
  # then, once the cluster is up:
  psql -U gpadmin -d whpgtest -c "CREATE EXTENSION vector;"
  psql -U gpadmin -d whpgtest -c "CREATE EXTENSION aidb CASCADE;"
EOF
