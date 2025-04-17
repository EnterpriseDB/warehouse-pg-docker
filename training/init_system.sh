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

ssh-keygen -t rsa -b 4096 -C "root" -f /root/.ssh/id_rsa -N ""
sshpass -p "changeme@123" ssh-copy-id -o StrictHostKeyChecking=no seg1
sshpass -p "changeme@123" ssh-copy-id -o StrictHostKeyChecking=no seg2


sudo ln -sf /usr/bin/python2.7 /usr/bin/python

# ----------------------------------------------------------------------
# Remove /run/nologin to allow logins
# ----------------------------------------------------------------------
# The /run/nologin file, if present, prevents users from logging into
# the system. This file is removed to ensure that users can log in via SSH.
# ----------------------------------------------------------------------
sudo rm -rf /run/nologin


echo '
==========================================
=  Welcome to the WarehousePG Training  =
==========================================


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
