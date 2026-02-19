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
MASTER_DATA_DIR="${DATA_DIR}/master"
SEGMENT1_DATA_DIR="${DATA_DIR}/segments/whpgdata1"
SEGMENT2_DATA_DIR="${DATA_DIR}/segments/whpgdata2"
HOSTNAME=$(hostname)
# THIS IS UNSAFE AND NOT FOR PRODUCTION!
PASSWORD="whpg5432"
# use Postgres default port in Docker image
# can be mapped to a different port in Docker
PORT=5432
MAX_CONNECTIONS=10

# export environment variables
export MASTER_DATA_DIRECTORY=${MASTER_DATA_DIR}
export PATH=$WHPG_HOME/bin:$PATH
export MASTER_MAX_CONNECT=$MAX_CONNECTIONS
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
sudo mkdir -p ${MASTER_DATA_DIR} $SEGMENT1_DATA_DIR $SEGMENT2_DATA_DIR
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


# initialize the WarehousePG database
echo "Sourcing greenplum_path.sh ..."
source ${WHPG_HOME}/greenplum_path.sh
echo "Sourcing greenplum_path.sh ... done"
if [ ! -f ${DATA_DIR}/master/whpgsne-1/postgresql.conf ];
then
    echo "Running gpinitsystem ..."
    hostname > /home/${WHPG_USER}/hostfile_whpginitsystem
    # FIXME: specify max connections
    # otherwise initialization fails with:
    #   postgres: max_wal_senders must be less than max_connections
    #gpinitsystem -c /home/${WHPG_USER}/whpginitsystem_singlenode -D -m 100 -a
    gpinitsystem -c /home/${WHPG_USER}/whpginitsystem_singlenode -m 100 -a
    echo "Running gpinitsystem ... done"
else
    echo "Starting WarehousePG ..."
    gpstart -a -d ${MASTER_DATA_DIR}/whpgsne-1/
    echo "Starting WarehousePG ... done"
fi


# do NOT do this in production, this grants full access to the database over the Docker network
before_sha256=`sha256sum ${MASTER_DATA_DIR}/whpgsne-1/pg_hba.conf`
HBALINE="host     all         all             0.0.0.0/0       trust"
HBAFILE="${MASTER_DATA_DIR}/whpgsne-1/pg_hba.conf"
if ! grep -Fq "${HBALINE}" "${HBAFILE}"; then
    echo "Enabling access in pg_hba.conf"
    sed -i '/# replication privilege./a\host     all         all             0.0.0.0\/0       trust' ${MASTER_DATA_DIR}/whpgsne-1/pg_hba.conf
fi
after_sha256=`sha256sum ${MASTER_DATA_DIR}/whpgsne-1/pg_hba.conf`

if [ "${before_sha256}" != "${after_sha256}" ];
then
    # reload the database, to apply pg_hba.conf changes
    echo "Reloading WarehousePG Database ..."
    #gpstop -M fast -a -d ${MASTER_DATA_DIR}/whpgsne-1/
    #gpstart -a -d ${MASTER_DATA_DIR}/whpgsne-1/
    gpstop -u -d ${MASTER_DATA_DIR}/whpgsne-1/
    echo "Reloading WarehousePG Database ... done"
fi

# run a test query
psql -d postgres -p ${PORT} -c "SELECT version();" || { echo "Failed to query the database." >&2; exit 1; }

echo "WarehousePG database initialized and started successfully."

# keep image running, otherwise the Docker CMD ends here
tail -f /dev/null
