#!/bin/bash
#
# Initialize a WarehousePG database cluster
#
# written by Andreas 'ads' Scherbaum <andreas.scherbaum@enterprisedb.com>
#
# - this script "survives" multiple restarts of the Docker containers,
#   and handles database initialization accordingly
# - this script uses insecure plaintext passwords
#   this is NOT suitable for production!


# this script is not to run with root or equivalent privileges
if [ $EUID -eq 0 ]
then
   echo "This script must not run as root or with sudo privileges!"
   exit 1
fi


# variables
WHPG_HOME="/usr/local/greenplum-db"
WHPG_USER="gpadmin"
DATA_DIR="/whpgdata"
COORDINATOR_DATA_DIR="${DATA_DIR}/coordinator"
STANDBY_DATA_DIR="${DATA_DIR}/standby"
SEGMENT1_DATA_DIR="${DATA_DIR}/segments/whpgdata1"
SEGMENT2_DATA_DIR="${DATA_DIR}/segments/whpgdata2"
MIRROR1_DATA_DIR="${DATA_DIR}/mirrors/whpgdata1"
MIRROR2_DATA_DIR="${DATA_DIR}/mirrors/whpgdata2"
HOSTNAME=$(hostname)
# THIS IS UNSAFE AND NOT FOR PRODUCTION!
PASSWORD="whpg5432"
# use Postgres default port in Docker image
# can be mapped to a different port in Docker
PORT=5432
MAX_CONNECTIONS=10

# export environment variables
export COORDINATOR_DATA_DIRECTORY=${COORDINATOR_DATA_DIR}
export STANDBY_DATA_DIR=$STANDBY_DATA_DIR
export PATH=$WHPG_HOME/bin:$PATH
export COORDINATOR_MAX_CONNECT=$MAX_CONNECTIONS
export LANG=en_US.UTF-8

# remove this if it exists, prevents logins into the system
sudo rm -f /run/nologin

echo "Generating sshd host keys ..."
sudo ssh-keygen -A -v
echo "Generating sshd host keys ... done"
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo mkdir -p /run/sshd

echo "Starting sshd ..."
sudo /usr/sbin/sshd -o "ListenAddress=0.0.0.0"
echo "Starting sshd ... done"

# directories already created in Dockerfile
# do it again in case this is a Docker mounted directory
sudo mkdir -p ${COORDINATOR_DATA_DIR} $SEGMENT1_DATA_DIR $SEGMENT2_DATA_DIR $MIRROR1_DATA_DIR $MIRROR2_DATA_DIR
sudo chown -R ${WHPG_USER}:${WHPG_USER} ${DATA_DIR}

# Set passwordless ssh for database user
if [ ! -d /home/${WHPG_USER}/.ssh ];
then
    sudo mkdir -p /home/${WHPG_USER}/.ssh
fi
if [ ! -O /home/${WHPG_USER}/.ssh ];
then
    sudo chown -R gpadmin:gpadmin /home/${WHPG_USER}/.ssh
fi
if ! test -f /home/${WHPG_USER}/.ssh/id_rsa;
then
    ssh-keygen -q -t rsa -b 2048 -f /home/${WHPG_USER}/.ssh/id_rsa -N ""
fi
cat /home/${WHPG_USER}/.ssh/id_rsa.pub >> /home/${WHPG_USER}/.ssh/authorized_keys

# set permissions, otherwise ssh refuses to use the keys
chmod 0700 /home/${WHPG_USER}/.ssh
chmod 0600 /home/${WHPG_USER}/.ssh/authorized_keys
chmod 0644 /home/${WHPG_USER}/.ssh/id_rsa.pub
chmod 0600 /home/${WHPG_USER}/.ssh/id_rsa

# auto-accept keys for localhost
ssh-keygen -F 127.0.0.1 > /dev/null 2>&1
if [ "$?" -gt 0 ];
then
    ssh-keyscan 127.0.0.1 >> /home/${WHPG_USER}/.ssh/known_hosts 2> /dev/null
fi

ssh-keygen -F ${HOSTNAME} > /dev/null 2>&1
if [ "$?" -gt 0 ];
then
    ssh-keyscan ${HOSTNAME} >> /home/${WHPG_USER}/.ssh/known_hosts 2> /dev/null
fi

# Set passwordless ssh for root user
sudo mkdir -p /root/.ssh
if ! sudo test -f /root/.ssh/id_rsa;
then
    sudo -- sh -c 'ssh-keygen -q -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""'
fi
sudo -- sh -c 'cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys'

# set permissions, otherwise ssh refuses to use the keys
sudo chmod 0700 /root/.ssh
sudo chmod 0600 /root/.ssh/authorized_keys
sudo chmod 0644 /root/.ssh/id_rsa.pub
sudo chmod 0600 /root/.ssh/id_rsa
sudo chown -R root:root /root/.ssh

# auto-accept keys for localhost
sudo ssh-keygen -F 127.0.0.1 > /dev/null 2>&1
if [ "$?" -gt 0 ];
then
    sudo -- sh -c 'ssh-keyscan 127.0.0.1 >> /root/.ssh/known_hosts 2> /dev/null'
fi
sudo ssh-keygen -F ${HOSTNAME} > /dev/null 2>&1
if [ "$?" -gt 0 ];
then
    sudo -- sh -c 'ssh-keyscan '${HOSTNAME}' >> /root/.ssh/known_hosts 2> /dev/null'
fi

if [ "${HOSTNAME}" == "coordinator" -o "${HOSTNAME}" == "standby" ];
then
    # populate ~/.bash_history with common commands
    if [ ! -f /home/${WHPG_USER}/.bash_history ];
    then
        touch /home/${WHPG_USER}/.bash_history
        chown ${WHPG_USER}:${WHPG_USER} /home/${WHPG_USER}/.bash_history
        chmod 0600 /home/${WHPG_USER}/.bash_history
        echo "source /usr/local/greenplum-db/greenplum_path.sh" >> /home/${WHPG_USER}/.bash_history
        echo "psql whpgtest" >> /home/${WHPG_USER}/.bash_history
        echo "sudo /bin/bash --login" >> /home/${WHPG_USER}/.bash_history
        echo "gpstart -a" >> /home/${WHPG_USER}/.bash_history
        echo "gpstop -a -M fast" >> /home/${WHPG_USER}/.bash_history
        echo "gpstate -a" >> /home/${WHPG_USER}/.bash_history
    fi
else
    # populate ~/.bash_history with common commands
    if [ ! -f /home/${WHPG_USER}/.bash_history ];
    then
        touch /home/${WHPG_USER}/.bash_history
        chown ${WHPG_USER}:${WHPG_USER} /home/${WHPG_USER}/.bash_history
        chmod 0600 /home/${WHPG_USER}/.bash_history
        echo "source /usr/local/greenplum-db/greenplum_path.sh" >> /home/${WHPG_USER}/.bash_history
        echo "PGOPTIONS='-c gp_session_role=utility' psql -d whpgtest -p " >> /home/${WHPG_USER}/.bash_history
        echo "sudo /bin/bash --login" >> /home/${WHPG_USER}/.bash_history
    fi
fi

# populate ~/.psql_history with common commands
if [ ! -f /home/${WHPG_USER}/.psql_history ];
then
    touch /home/${WHPG_USER}/.psql_history
    chown ${WHPG_USER}:${WHPG_USER} /home/${WHPG_USER}/.psql_history
    chmod 0600 /home/${WHPG_USER}/.psql_history
    echo "SELECT version();" >> /home/${WHPG_USER}/.psql_history
    echo "SELECT * from gp_segment_configuration;" >> /home/${WHPG_USER}/.psql_history
fi

# populate ~/.bashrc.d/warehousepg
if [ ! -f /home/${WHPG_USER}/.bashrc.d/warehousepg ];
then
    mkdir -p /home/${WHPG_USER}/.bashrc.d
    chown ${WHPG_USER}:${WHPG_USER} /home/${WHPG_USER}/.bashrc.d
    chmod 0700 /home/${WHPG_USER}/.bashrc.d
    touch /home/${WHPG_USER}/.bashrc.d/warehousepg
    chown ${WHPG_USER}:${WHPG_USER} /home/${WHPG_USER}/.bashrc.d/warehousepg
    chmod 0600 /home/${WHPG_USER}/.bashrc.d/warehousepg
    echo "export PGPORT=5432" >> /home/${WHPG_USER}/.bashrc.d/warehousepg
    echo "export PGUSER=gpadmin" >> /home/${WHPG_USER}/.bashrc.d/warehousepg
fi


# loop over all hosts, and:
#  - check if the host is available (wait up to 10 seconds)
#  - accept the ssh keys from remote host
#  - install ssh keys on the remote host
# the hostfile_ssh_whpginitsystem file includes all extra hosts which do not run a database
SSH_HOSTFILE="/home/${WHPG_USER}/hostfile_ssh_whpginitsystem"
while IFS= read -r host; do
    [[ -z "${host}" ]] && continue

    host_available=0
    for ((i=0; i<10; i++)); do
        if ping -c 1 -W 1 "${host}" >/dev/null 2>&1; then
            host_available=1
            break
        fi
        echo "Waiting for host: ${host}"
        sleep 1
    done
    if [ "${host_available}" -eq 0 ]; then
        echo "Host ${host} is not available!"
        exit 1
    fi

    ssh_available=0
    for ((i=0; i<10; i++)); do
        if nc -z "${host}" "22" >/dev/null 2>&1; then
            ssh_available=1
            break
        fi
        echo "Waiting for sshd on host: ${host}"
        sleep 1
    done
    if [ "${ssh_available}" -eq 0 ]; then
        echo "sshd on host ${host} is not available!"
        exit 1
    fi

    ssh-keygen -F ${host} > /dev/null 2>&1
    if [ "$?" -gt 0 ];
    then
        echo "Adding ${WHPG_USER} ssh key for host: ${host}"
        ssh-keyscan ${host} >> /home/${WHPG_USER}/.ssh/known_hosts 2> /dev/null
        #ssh-keyscan ${host} >> /home/${WHPG_USER}/.ssh/known_hosts
    fi
    sudo ssh-keygen -F ${host} > /dev/null 2>&1
    if [ "$?" -gt 0 ];
    then
        echo "Adding root ssh key for host: ${host}"
        sudo -- sh -c "ssh-keyscan ${host} >> /root/.ssh/known_hosts 2> /dev/null"
        #sudo -- sh -c "ssh-keyscan ${host} >> /root/.ssh/known_hosts"
    fi

    # THIS IS UNSAFE AND NOT FOR PRODUCTION!
    # install ssh keys on the other host
    echo "Adding ssh keys for user ${WHPG_USER} to host ${host}"
    ssh_max_attempts=5
    ssh_attempt_num=1
    ssh_operation_successful=false
    ssh_check_logs=false
    while [ $ssh_attempt_num -le $ssh_max_attempts ]; do
        echo "Attempt ${ssh_attempt_num}/${ssh_max_attempts}: Adding keys for user ${WHPG_USER} to host ${host} ..."
        sshpass -p "${PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no "${WHPG_USER}@${host}" > /tmp/add-ssh-keys-user-${ssh_attempt_num}.log 2>&1
        #sshpass -p "${PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no "${WHPG_USER}@${host}"
        exit_status=$?

        if [ "$exit_status" -eq 0 ]; then
            echo "Successfully added keys for user ${WHPG_USER} to host ${host}."
            ssh_operation_successful=true
            break
        else
            echo "Something went wrong adding ssh keys for user ${WHPG_USER} to host ${host}."
            echo "Here is the log output:"
            echo ""
            cat /tmp/add-ssh-keys-user-${ssh_attempt_num}.log
            echo ""
        fi

        echo "Attempt ${ssh_attempt_num} failed with exit code ${exit_status}."

        if [ $ssh_attempt_num -lt $ssh_max_attempts ]; then
            echo "Retrying in 1 second..."
            ssh_check_logs=true
            sleep 1
        fi

        ssh_attempt_num=$((ssh_attempt_num + 1))
    done
    if [ "$ssh_operation_successful" = false ]; then
        echo "ERROR: Adding keys for user ${WHPG_USER} to host ${host} failed after ${ssh_attempt_num} attempts!"
        exit 1
    fi
    echo "Adding ssh keys for user ${WHPG_USER} to host ${host} completed"
    # occasionally the files are not owned by root - don't know why
    #sudo ls -ld /etc/ssh/* /etc/ssh-install/*
    echo "Adding ssh keys for user root to host ${host}"
    ssh_max_attempts=5
    ssh_attempt_num=1
    ssh_operation_successful=false
    while [ $ssh_attempt_num -le $ssh_max_attempts ]; do
        # sometimes files not owned by root appear in /etc/ssh/ even after a restart
        # that's hard to debug where this is coming from
        # run another chown, all files in /etc/ssh/ are supposed to be root owned
        sudo chown -R root:root /etc/ssh/
        echo "Attempt ${ssh_attempt_num}/${ssh_max_attempts}: Adding keys for user root to host ${host} ..."
        sudo sh -c 'sshpass -v -p "'${PASSWORD}'" ssh-copy-id -o StrictHostKeyChecking=no "root@'${host}'" > /tmp/add-ssh-keys-root-'${ssh_attempt_num}'.log 2>&1'
        #sudo sh -c 'sshpass -v -p "'${PASSWORD}'" ssh-copy-id -o StrictHostKeyChecking=no "root@'${host}'"'
        exit_status=$?

        if [ "$exit_status" -eq 0 ]; then
            echo "Successfully added keys for user root to host ${host}."
            ssh_operation_successful=true
            break
        else
            echo "Something went wrong adding ssh keys for user root to host ${host}."
            echo "Here is the log output:"
            echo ""
            sudo cat /tmp/add-ssh-keys-root-${ssh_attempt_num}.log
            echo ""
        fi

        echo "Attempt ${ssh_attempt_num} failed with exit code ${exit_status}."

        if [ $ssh_attempt_num -lt $ssh_max_attempts ]; then
            echo "Retrying in 1 second..."
            ssh_check_logs=true
            sleep 1
        fi

        ssh_attempt_num=$((ssh_attempt_num + 1))
    done
    if [ "$ssh_operation_successful" = false ]; then
        echo "ERROR: Adding keys for user root to host ${host} failed after ${ssh_attempt_num} attempts!"
        exit 1
    fi
    echo "Adding ssh keys for user root to host ${host} completed"
done < ${SSH_HOSTFILE}

if [ "$ssh_check_logs" = true ]; then
    echo ""
    echo ""
    echo "CHECK LOGS!"
fi


# check if all hostnames appear in the authorized_keys file
# other hosts might need more attempts
# eventually the hosts finish the setup, but we might need the file earlier
SSH_HOSTS=$(cat "$SSH_HOSTFILE")
SSH_ALL_HOSTS_FOUND=1
# start the retry loop (10 attempts max)
for i in {1..10}; do
    echo "Authorized Keys Check: Attempt ${i}/10"
    SSH_ALL_HOSTS_FOUND=0

    for SSH_HOSTNAME in ${SSH_HOSTS}; do
        # check if the pattern "SSH_HOSTNAME@" is present in authorized_keys.
        # -q (quiet) suppresses output; return code 0 means match found.
        if ! grep -q "@${SSH_HOSTNAME}" "/home/${WHPG_USER}/.ssh/authorized_keys"; then
            echo "  [ERROR] Host '${SSH_HOSTNAME}' not found in authorized_keys!"
            SSH_ALL_HOSTS_FOUND=1
            break
        fi
    done

    if [ ${SSH_ALL_HOSTS_FOUND} -eq 0 ]; then
        echo "SUCCESS: All host keys confirmed after ${i} attempts."
        break
    fi

    # If not all hosts were found, and it's not the last attempt, wait
    if [ ${i} -lt 10 ]; then
        echo "Waiting 1 second before retrying the test ..."
        sleep 1
    fi
done

if [ $SSH_ALL_HOSTS_FOUND -ne 0 ]; then
    echo "ERROR: Not all hosts were confirmed after 10 attempts"
    exit 1
fi

echo "Init completed ..."
#tail -f /dev/null

# at this point we already know that all containers are up and running
if [ "${HOSTNAME}" == "coordinator" ];
then
    # initialize the primary WarehousePG database
    # do NOT source greenplum_path.sh here, this will pollute the remaining script
    # instead use sub shells where greenplum_path.sh is required
    #echo "Sourcing greenplum_path.sh ..."
    #source ${WHPG_HOME}/greenplum_path.sh
    if [ ! -f ${DATA_DIR}/coordinator/whpgmne-1/postgresql.conf ];
    then
        echo "Running gpinitsystem ..."
        # FIXME: specify max connections
        # otherwise initialization fails with:
        #   postgres: max_wal_senders must be less than max_connections
        ( source ${WHPG_HOME}/greenplum_path.sh && gpinitsystem -c /home/${WHPG_USER}/whpginitsystem_multinode -m 100 -a --mirror-mode=group -s standby -P 5432 -S ${STANDBY_DATA_DIR} )
        echo "Running gpinitsystem ... done"
    else
        echo "Starting WarehousePG ..."
        ( source ${WHPG_HOME}/greenplum_path.sh && gpstart -a -d ${COORDINATOR_DATA_DIR}/whpgdr-1/ )
        echo "Starting WarehousePG ... done"
    fi


    # do NOT do this in production, this grants full access to the database over the Docker network
    before_sha256=`sha256sum ${COORDINATOR_DATA_DIR}/whpgmne-1/pg_hba.conf`
    HBALINE="host     all         all             0.0.0.0/0       trust"
    HBAFILE="${COORDINATOR_DATA_DIR}/whpgmne-1/pg_hba.conf"
    if ! grep -Fq "${HBALINE}" "${HBAFILE}"; then
        echo "Enabling access in pg_hba.conf"
        sed -i '/# replication privilege./a\host     all         all             0.0.0.0\/0       trust' ${COORDINATOR_DATA_DIR}/whpgmne-1/pg_hba.conf
    fi
    after_sha256=`sha256sum ${COORDINATOR_DATA_DIR}/whpgmne-1/pg_hba.conf`

    if [ "${before_sha256}" != "${after_sha256}" ];
    then
        # reload the database, to apply pg_hba.conf changes
        echo "Reloading WarehousePG Database ..."
        #( source ${WHPG_HOME}/greenplum_path.sh && gpstop -M fast -a -d ${COORDINATOR_DATA_DIR}/whpgmne-1/ )
        #( source ${WHPG_HOME}/greenplum_path.sh && gpstart -a -d ${COORDINATOR_DATA_DIR}/whpgmne-1/ )
        ( source ${WHPG_HOME}/greenplum_path.sh && gpstop -u -d ${COORDINATOR_DATA_DIR}/whpgmne-1/ )
        echo "Reloading WarehousePG Database ... done"
    fi

    # run a test query
    set -e
    # run a test query
    ( source ${WHPG_HOME}/greenplum_path.sh && psql -d postgres -p ${PORT} -c "SELECT version();" || { echo "Failed to query the database." >&2; exit 1; } )
    set +e

    echo "WarehousePG database initialized and started successfully."
elif [ "${HOSTNAME}" == "gpfdist" ];
then
    echo "Sourcing greenplum_path.sh ..."
    source ${WHPG_HOME}/greenplum_path.sh
    echo "Sourcing greenplum_path.sh ... done"
    echo "Starting gpfdist on port 30000, serving directory ${DATA_DIR}"
    gpfdist -d ${DATA_DIR} -p 30000 -V
else
    echo "Not the coordinator, nothing to do"
fi

# keep image running, otherwise the Docker CMD ends here
tail -f /dev/null
