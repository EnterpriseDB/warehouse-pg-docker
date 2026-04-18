#!/bin/bash

# Initialize a WarehousePG database cluster.

if [ $EUID -eq 0 ]
then
   echo "This script must not run as root or with sudo privileges!"
   exit 1
fi


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
PASSWORD="whpg5432"
PORT=5432
MAX_CONNECTIONS=10

export COORDINATOR_DATA_DIRECTORY=${COORDINATOR_DATA_DIR}
export STANDBY_DATA_DIR=$STANDBY_DATA_DIR
export PATH=$WHPG_HOME/bin:$PATH
export COORDINATOR_MAX_CONNECT=$MAX_CONNECTIONS
export LANG=en_US.UTF-8

sudo rm -f /run/nologin

echo "Generating sshd host keys ..."
sudo ssh-keygen -A -v
echo "Generating sshd host keys ... done"
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo mkdir -p /run/sshd

echo "Starting sshd ..."
sudo /usr/sbin/sshd -o "ListenAddress=0.0.0.0"
echo "Starting sshd ... done"

sudo mkdir -p ${COORDINATOR_DATA_DIR} $SEGMENT1_DATA_DIR $SEGMENT2_DATA_DIR $MIRROR1_DATA_DIR $MIRROR2_DATA_DIR
sudo chown -R ${WHPG_USER}:${WHPG_USER} ${DATA_DIR}

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

chmod 0700 /home/${WHPG_USER}/.ssh
chmod 0600 /home/${WHPG_USER}/.ssh/authorized_keys
chmod 0644 /home/${WHPG_USER}/.ssh/id_rsa.pub
chmod 0600 /home/${WHPG_USER}/.ssh/id_rsa

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

sudo mkdir -p /root/.ssh
if ! sudo test -f /root/.ssh/id_rsa;
then
    sudo -- sh -c 'ssh-keygen -q -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""'
fi
sudo -- sh -c 'cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys'

sudo chmod 0700 /root/.ssh
sudo chmod 0600 /root/.ssh/authorized_keys
sudo chmod 0644 /root/.ssh/id_rsa.pub
sudo chmod 0600 /root/.ssh/id_rsa
sudo chown -R root:root /root/.ssh

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

if [ ! -f /home/${WHPG_USER}/.psql_history ];
then
    touch /home/${WHPG_USER}/.psql_history
    chown ${WHPG_USER}:${WHPG_USER} /home/${WHPG_USER}/.psql_history
    chmod 0600 /home/${WHPG_USER}/.psql_history
    echo "SELECT version();" >> /home/${WHPG_USER}/.psql_history
    echo "SELECT * from gp_segment_configuration;" >> /home/${WHPG_USER}/.psql_history
fi

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

SSH_HOSTFILE=$1
ssh_check_logs=false
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
    fi
    sudo ssh-keygen -F ${host} > /dev/null 2>&1
    if [ "$?" -gt 0 ];
    then
        echo "Adding root ssh key for host: ${host}"
        sudo -- sh -c "ssh-keyscan ${host} >> /root/.ssh/known_hosts 2> /dev/null"
    fi

    echo "Adding ssh keys for user ${WHPG_USER} to host ${host}"
    ssh_max_attempts=5
    ssh_attempt_num=1
    ssh_operation_successful=false
    while [ $ssh_attempt_num -le $ssh_max_attempts ]; do
        echo "Attempt ${ssh_attempt_num}/${ssh_max_attempts}: Adding keys for user ${WHPG_USER} to host ${host} ..."
        sshpass -p "${PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no "${WHPG_USER}@${host}" > /tmp/add-ssh-keys-user-${ssh_attempt_num}.log 2>&1
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

    echo "Adding ssh keys for user root to host ${host}"
    ssh_max_attempts=5
    ssh_attempt_num=1
    ssh_operation_successful=false
    while [ $ssh_attempt_num -le $ssh_max_attempts ]; do
        sudo chown -R root:root /etc/ssh/
        echo "Attempt ${ssh_attempt_num}/${ssh_max_attempts}: Adding keys for user root to host ${host} ..."
        sudo sh -c 'sshpass -v -p "'${PASSWORD}'" ssh-copy-id -o StrictHostKeyChecking=no "root@'${host}'" > /tmp/add-ssh-keys-root-'${ssh_attempt_num}'.log 2>&1'
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

source ${WHPG_HOME}/greenplum_path.sh
if [ "${HOSTNAME}" == "coordinator" ]; then
    if [ ! -f ${DATA_DIR}/coordinator/whpgmne-1/postgresql.conf ]; then
        echo "Running gpinitsystem ..."
        gpinitsystem -c /home/gpadmin/whpginitsystem_multinode
        echo "Running gpinitsystem ... done"
    else
        echo "Starting WarehousePG ..."
        gpstart -a -d ${COORDINATOR_DATA_DIR}/whpgmne-1/
        echo "Starting WarehousePG ... done"
    fi

    before_sha256=`sha256sum ${COORDINATOR_DATA_DIR}/whpgmne-1/pg_hba.conf`
    HBALINE="host     all         all             0.0.0.0/0       trust"
    HBAFILE="${COORDINATOR_DATA_DIR}/whpgmne-1/pg_hba.conf"
    if ! grep -Fq "${HBALINE}" "${HBAFILE}"; then
        echo "Enabling access in pg_hba.conf"
        sed -i '/# replication privilege./a\host     all         all             0.0.0.0\/0       trust' ${COORDINATOR_DATA_DIR}/whpgmne-1/pg_hba.conf
    fi
    after_sha256=`sha256sum ${COORDINATOR_DATA_DIR}/whpgmne-1/pg_hba.conf`

    if [ "${before_sha256}" != "${after_sha256}" ]; then
        echo "Reloading WarehousePG Database ..."
        gpstop -u -d ${COORDINATOR_DATA_DIR}/whpgmne-1/
        echo "Reloading WarehousePG Database ... done"
    fi

    psql -d postgres -p ${PORT} -c "SELECT version();" || { echo "Failed to query the database." >&2; exit 1; }

    echo "WarehousePG database initialized and started successfully."
fi

tail -f /dev/null
