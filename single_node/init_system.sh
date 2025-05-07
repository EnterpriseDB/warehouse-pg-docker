#!/bin/bash
## ======================================================================
## Container initialization script
## ======================================================================

# ----------------------------------------------------------------------
# Start SSH daemon and setup for SSH access
# ----------------------------------------------------------------------
# The SSH daemon is started to allow remote access to the container via
# SSH. This is useful for development and debugging purposes. If the SSH
# daemon fails to start, the script exits with an error.
# ----------------------------------------------------------------------
if ! sudo /usr/sbin/sshd; then
    echo "Failed to start SSH daemon" >&2
    exit 1
fi

sudo ln -sf /usr/bin/python2.7 /usr/bin/python

# ----------------------------------------------------------------------
# Remove /run/nologin to allow logins
# ----------------------------------------------------------------------
# The /run/nologin file, if present, prevents users from logging into
# the system. This file is removed to ensure that users can log in via SSH.
# ----------------------------------------------------------------------
sudo rm -rf /run/nologin

# ## Change ownership to gpadmin 
sudo chown -R gpadmin.gpadmin /usr/local/greenplum-db \
                              /tmp/gpinitsystem_singlenode \
                              /tmp/gpdb-hosts 

# ----------------------------------------------------------------------
# Configure passwordless SSH access for 'gpadmin' user
# ----------------------------------------------------------------------
# The script sets up SSH key-based authentication for the 'gpadmin' user,
# allowing passwordless SSH access. It generates a new SSH key pair if one
# does not already exist, and configures the necessary permissions.
# ----------------------------------------------------------------------
mkdir -p /home/gpadmin/.ssh
chmod 700 /home/gpadmin/.ssh

if [ ! -f /home/gpadmin/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -C gpadmin -f /home/gpadmin/.ssh/id_rsa -P "" > /dev/null 2>&1
fi

cat /home/gpadmin/.ssh/id_rsa.pub >> /home/gpadmin/.ssh/authorized_keys
chmod 600 /home/gpadmin/.ssh/authorized_keys

# Add the container's hostname to the known_hosts file to avoid SSH warnings
ssh-keyscan -t rsa mdw > /home/gpadmin/.ssh/known_hosts 2>/dev/null

# Source environment variables and set MASTER_DATA_DIRECTORY
source /usr/local/greenplum-db/greenplum_path.sh
export MASTER_DATA_DIRECTORY=/data/master/gpseg-1

# Initialize single node WarehousePG cluster
gpinitsystem -a \
                 -c /tmp/gpinitsystem_singlenode \
                 -h /tmp/gpdb-hosts

if [ $HOSTNAME == "mdw" ]; then
     ## Allow any host access the WarehousePG Cluster
     echo 'host all all 0.0.0.0/0 trust' >> /data/master/gpseg-1/pg_hba.conf
     gpstop -u

     psql -d template1 \
          -c "ALTER USER gpadmin PASSWORD 'changeme@123'"

     cat <<-'EOF'
EOF

     cat <<-'EOF'

======================================================================
Sandbox: WarehousePG Database Cluster details
======================================================================

EOF

     echo "Current time: $(date)"
     source /etc/os-release
     echo "OS Version: ${NAME} ${VERSION}"

     ## Set gpadmin password, display version and cluster configuration
     psql -P pager=off -d template1 -c "SELECT VERSION()"
     psql -P pager=off -d template1 -c "SELECT * FROM gp_segment_configuration ORDER BY dbid"
     psql -P pager=off -d template1 -c "SHOW optimizer"
fi

# PXF Build and Install START
# TODO: Remove this once the package is available in the cloudsmith repo

source /usr/local/greenplum-db/greenplum_path.sh
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk/jre/
export PXF_BASE=/home/gpadmin/pxf-base
export PXF_HOME=/usr/local/pxf-gp6
export PATH=$PXF_HOME/bin/:$PATH

cd /tmp/pxf
make clean && make CC=gcc
make -C /tmp/pxf install-server cli
make -C /tmp/pxf/external-table install

chown -R gpadmin:gpadmin /usr/local/pxf-gp6 && \
echo "export PXF_BASE=/home/gpadmin/pxf-base" >> /home/gpadmin/.bashrc && \
echo "export PXF_HOME=/usr/local/pxf-gp6" >> /home/gpadmin/.bashrc && \
echo "export PATH=$PATH:/usr/local/pxf-gp6/bin" >> /home/gpadmin/.bashrc

pxf prepare
pxf register
#pxf start
# PXF Build and Install END

echo '
===========================
=  DEPLOYMENT SUCCESSFUL  =
===========================


======================================================================
 __          __            _                          _____   _____ 
 \ \        / /           | |                        |  __ \ / ____|
  \ \  /\  / /_ _ _ __ ___| |__   ___  _   _ ___  ___| |__) | |  __ 
   \ \/  \/ / _` | '__/ _ \ '_ \ / _ \| | | / __|/ _ \  ___/| | |_ |
    \  /\  / (_| | | |  __/ | | | (_) | |_| \__ \  __/ |    | |__| |
     \/  \/ \__,_|_|  \___|_| |_|\___/ \__,_|___/\___|_|     \_____|
                                                                    
======================================================================'

# ----------------------------------------------------------------------
# Start an interactive bash shell
# ----------------------------------------------------------------------
# Finally, the script starts an interactive bash shell to keep the
# container running and allow the user to interact with the environment.
# ----------------------------------------------------------------------
/bin/bash
