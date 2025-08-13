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
                              /tmp/gpinitsystem_config \
                              /tmp/hostfile_gpinitsystem \
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
ssh-keyscan -t rsa cdw > /home/gpadmin/.ssh/known_hosts 2>/dev/null

# Source environment variables and set MASTER_DATA_DIRECTORY
source /usr/local/greenplum-db/greenplum_path.sh
export MASTER_DATA_DIRECTORY=/data/master/gpseg-1

#Initialize multi node WarehousePG cluster

    sshpass -p "changeme@123" ssh-copy-id -o StrictHostKeyChecking=no sdw1
    sshpass -p "changeme@123" ssh-copy-id -o StrictHostKeyChecking=no sdw2
    sshpass -p "changeme@123" ssh-copy-id -o StrictHostKeyChecking=no scdw
    #sshpass -p "changeme@123" ssh-copy-id -o StrictHostKeyChecking=no smdw
    gpinitsystem -a \
                 -c /tmp/gpinitsystem_config \
                 -h /tmp/hostfile_gpinitsystem \
                 --max_connections=100

    printf "sdw1\nsdw2\n" >> /tmp/gpdb-hosts

if [ $HOSTNAME == "cdw" ]; then
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
