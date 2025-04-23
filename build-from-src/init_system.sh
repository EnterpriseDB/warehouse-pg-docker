#!/bin/bash
## ======================================================================
## Container initialization script
## ======================================================================


sudo chown -R gpadmin.gpadmin /tmp/warehouse-pg

source /usr/local/greenplum-db/greenplum_path.sh

cd /tmp/warehouse-pg
make create-demo-cluster 

source /tmp/warehouse-pg/gpAux/gpdemo/gpdemo-env.sh


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

     # Create the default gpadmin database
     psql -d template1 -c "create database gpadmin"

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
