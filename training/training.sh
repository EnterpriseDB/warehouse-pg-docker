#!/bin/bash

STATUS_FILE="progress.txt"

# Colors
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[38;5;81m"
RESET="\033[0m"

# Ensure progress file exists
touch "$STATUS_FILE"

# Function to check progress
is_done() {
    grep -q "^$1$" "$STATUS_FILE"
}

# Function to mark task as done
mark_done() {
    echo "$1" >> "$STATUS_FILE"
}

print_status() {
    TASK=$1
    MESSAGE=$2

    if is_done "$TASK"; then
        echo -e "${GREEN}✅ $MESSAGE${RESET}"
        return 0
    else
        echo -e "${YELLOW}🛠 $MESSAGE${RESET}"
        return 1
    fi
}


echo -e "----------------------------------------------"
echo -e "${BLUE}🚀 WarehousePG Hands-on Setup 🚀${RESET}"
echo -e "----------------------------------------------"
echo -e ""

### TASK 1: Create gpadmin user
print_status "create_gpadmin_user" "Task 1: Create gpadmin user"

if ! is_done "create_gpadmin_user"; then
    if id "gpadmin" &>/dev/null; then
        echo -e "${GREEN}✅ Task 1 Completed. gpadmin user exists!${RESET}"
        mark_done "create_gpadmin_user"
        echo -e ""
    else
        echo -e ""
        echo -e "${RED}❌ gpadmin user not found! ${RESET}"
        echo -e ""
        echo -e "${BLUE} Create a dedicated OS user 'gpadmin'.\n"\
        "The gpadmin user must have permission to access the services and directories\n"\
        "required to install and run WarehousePG Database.${RESET}"

        echo -e ""
        echo -e "${YELLOW}👉 Run the following commands on each host - master, seg1, and seg2 as 'root':${RESET}"

        cat <<EOF

        groupadd gpadmin
        useradd gpadmin -r -m -g gpadmin
        echo 'gpadmin:changeme' | chpasswd
        usermod -aG wheel gpadmin
EOF
        echo -e ""
        echo -e "${BLUE} Above commands add a system user 'gpadmin', create '/home/gpadmin' and assign the user to group 'gpadmin'${RESET}"
        echo -e ""
        echo -e "${YELLOW} Run /tmp/training.sh again for the next step.${RESET}"
        echo -e ""

        exit 1
    fi
fi

### TASK 2(a): Setup SSH keys
print_status "setup_ssh_keys" "Task 2(a): Set up SSH keys"

if ! is_done "setup_ssh_keys"; then
    if sudo -i -u gpadmin test -f /home/gpadmin/.ssh/id_rsa; then
        echo -e "${GREEN}✅ Task 2(a): Completed. SSH keys already exist!${RESET}"
        mark_done "setup_ssh_keys"
    else
        echo -e ""
        echo -e "${RED}❌ SSH keys missing!${RESET}"
        echo -e ""

        echo -e "${BLUE} The 'gpadmin' user on each WarehousePG host must have an.\n"\
        "SSH key pair installed and be able to SSH from any host in the cluster to\n"\
        "called 'passwordless SSH'${RESET}"

        echo -e ""
        echo -e "${YELLOW}👉 Please manually set up SSH keys for gpadmin on Master and Segment Hosts (seg1 and seg2) by running the following commands:${RESET}"
        echo -e ""
        echo -e "${BLUE} Switch to gpadmin user and generate SSH key pair for the gpadmin user.${RESET}"

        cat <<EOF

        su - gpadmin
        ssh-keygen -t rsa -b 4096 -C gpadmin -f /home/gpadmin/.ssh/id_rsa -P "" > /dev/null 2>&1
        exit

EOF
        echo -e "${YELLOW}Run /tmp/training.sh again for the next step.${RESET}"
        echo -e ""
        exit 1
    fi
fi

### TASK 2(b): Passwordless SSH setup
print_status "setup_passwordless_ssh" "Task 2(b): Set up passwordless SSH"

if ! is_done "setup_passwordless_ssh"; then
    if sudo -i -u gpadmin ssh -o BatchMode=yes -o ConnectTimeout=5 seg1 "echo connected" &>/dev/null && \
       sudo -i -u gpadmin ssh -o BatchMode=yes -o ConnectTimeout=5 seg2 "echo connected" &>/dev/null; then
        echo -e "${GREEN}✅ Task 2(b): Completed. Passwordless SSH to seg1 and seg2 is working.${RESET}"
        mark_done "setup_passwordless_ssh"
    else
        echo ""
        echo -e "${RED}❌ Passwordless SSH is not yet set up.${RESET}"
        echo -e "${BLUE}👉 Please run the following commands as user 'gpadmin' on master:${RESET}"
        echo ""
        cat <<EOF

        su - gpadmin

        sshpass -p "changeme" ssh-copy-id -o StrictHostKeyChecking=no seg1
        sshpass -p "changeme" ssh-copy-id -o StrictHostKeyChecking=no seg2

        exit

EOF
        echo -e "${YELLOW}Run /tmp/training.sh again for the next step.${RESET}"
        echo -e ""
        exit 1
    fi
fi

### TASK 3: STEP 1. INSTALL WarehousePG ON MASTER NODE ###
print_status "install_gp_master" "Task 3(a): Install WarehousePG on Master Node"
if ! is_done "install_gp_master"; then

    if [ -d "/usr/local/greenplum-db" ]; then
        echo -e "${GREEN}✅ WarehousePG is already installed on Master.${RESET}"
    else
        echo -e "${RED}❌ WarehousePG is NOT installed on Master!${RESET}"
        echo -e "${BLUE}👉 Install WarehousePG using the following command:${RESET}"
        echo -e ""
        echo -e "       sudo dnf -y install warehouse-pg-6"
        echo -e ""
        echo -e "${BLUE}👉 After install, change ownership to 'gpadmin':${RESET}"
        echo -e ""
        echo -e "       chown -R gpadmin:gpadmin /usr/local/greenplum*"
        echo -e "       chgrp -R gpadmin /usr/local/greenplum*"
        echo -e ""
        exit 1
    fi

    mark_done "install_gp_master"
fi

### TASK 3: STEP 2. INSTALL WarehousePG ON SEGMENT NODES ###
print_status "install_gp_segments" "Task 3(a): Install WarehousePG on Segment Nodes"
if ! is_done "install_gp_segments"; then

    # Source the WarehousePG path on the Master node
    source /usr/local/greenplum-db/greenplum_path.sh
    gpssh -u root -f /tmp/hostfile 'if [ -d "/usr/local/greenplum-db" ]; then echo "true"; else echo "false"; fi' > /tmp/greenplum_check_results.txt

    # Check if WarehousePG is not installed on any segment
    if grep "false" /tmp/greenplum_check_results.txt > /dev/null; then


        echo -e "${BLUE}Follow the instructions below to install it on all the segment nodes.\n"\

        echo -e "${BLUE}👉 On Master Node, run:${RESET}"
        echo -e "       source /usr/local/greenplum-db/greenplum_path.sh"
        echo -e ""

        echo -e "${BLUE}👉 Then run this command to install WarehousePG on segment nodes:${RESET}"
        echo -e "       gpssh -u root -f /tmp/hostfile -e 'sudo dnf -y install warehouse-pg-6'"
        echo -e ""

        echo -e "${BLUE}👉 After installation, set ownership on each segment node:${RESET}"
        echo -e "       gpssh -u root -f /tmp/hostfile -e 'chown -R gpadmin:gpadmin /usr/local/greenplum*'"
        echo -e ""

        echo -e "${BLUE} Check the installation by running this command:${RESET}"
        echo -e "       gpssh -u root -f /tmp/hostfile -e 'ls -l /usr/local/greenplum-db'"
        echo -e ""

        echo -e "${YELLOW}Run /tmp/training.sh again for the next step.${RESET}"
        
        exit 1
    else
        echo -e "${GREEN}✅ WarehousePG is already installed on Segment Nodes.${RESET}"
    fi 

    # Mark task as done once installation is verified
    mark_done "install_gp_segments"
fi


### TASK GROUP 4: SET UP DATA STORAGE AREAS ###
print_status "setup_gp_dirs" "Task 4: Set Up Data Storage Areas for WarehousePG"
if ! is_done "setup_gp_dirs"; then

    echo -e "${BLUE}📂 WarehousePG requires data directories for the master, standby master, and segment hosts.${RESET}"
    echo -e "${BLUE}👉 Follow these steps to create them manually.${RESET}"

    echo -e "\n${BLUE}🔹 Step 1: Create Master Data Directory${RESET}"
    echo -e ""
    echo -e "${BLUE}Run the following commands as root:${RESET}"

    cat <<EOF
        mkdir -p /data/master
        chown gpadmin:gpadmin /data/master

EOF

#    echo -e "\n${BLUE}🔹 Step 2: Create Standby Master Data Directory${RESET}"
#    echo -e "${YELLOW}Run the following commands from the master to set up the standby host:${RESET}"
#    cat <<EOF
#source /usr/local/greenplum-db/greenplum_path.sh
#gpssh -h smdw -e 'mkdir -p /data/master'
#gpssh -h smdw -e 'chown gpadmin:gpadmin /data/master'
#EOF

    echo -e "\n${BLUE}🔹 Step 2: Create Segment Data Directories${RESET}"
    echo -e "${BLUE}Run the following commands from the master using gpssh on segment hosts:${RESET}"
    cat <<EOF
        source /usr/local/greenplum-db/greenplum_path.sh
        gpssh -u root -f /tmp/hostfile -e 'mkdir -p /data/primary'
        gpssh -u root -f /tmp/hostfile -e 'mkdir -p /data/mirror'
        gpssh -u root -f /tmp/hostfile -e 'chown gpadmin:gpadmin /data/primary'
        gpssh -u root -f /tmp/hostfile -e 'chown gpadmin:gpadmin /data/mirror'

EOF

    echo -e "${YELLOW}Run /tmp/training.sh again for the next step.${RESET}"

    mark_done "setup_gp_dirs"

    exit 1

fi


### TASK GROUP 5: INITIALIZE WarehousePG ###
print_status "init_gp" "Task 5: Run gpinitsystem"
if ! is_done "init_gp"; then

    if sudo -i -u gpadmin bash -c "source /usr/local/greenplum-db/greenplum_path.sh && psql -d postgres -c '\l' &>/dev/null"; then
        echo -e "${GREEN}✅ WarehousePG is already initialized!${RESET}"
    else
        echo -e "${RED}❌ WarehousePG is not initialized!${RESET}"
        echo -e "${BLUE}👉 Follow these steps to initialize Greenplum:${RESET}"

        echo -e "${BLUE}=> Switch to gpadmin user${RESET}"
        echo -e "       su - gpadmin"
        echo -e ""

        echo -e "${BLUE}=> Source WarehousePG environment variables${RESET}"
        echo -e "       source /usr/local/greenplum-db/greenplum_path.sh"
        echo -e ""

        echo -e "${BLUE}👉 Run the following command to ensure 'n:n passwordless ssh'.\n"\
        "  All hosts shoule be able to communicate with each other, else gpinitsystem will fail.:${RESET}"
        echo -e "       gpssh-exkeys -f /tmp/hostfile"
        echo -e ""

        echo -e "${BLUE}=> Copy hostfile and gpinitsystem_config from /tmp to /home/gpadmin for future reference. ${RESET}"
        cat <<EOF
        cp /tmp/gpinitsystem_config /home/gpadmin/
        cp /tmp/hostfile /home/gpadmin/

EOF
    
        echo -e "${BLUE}=> gpinitsystem_config contains the required parameters needed to initialize the database.\n"\
        "  Take few mins to review this file and change these parameters as needed. ${RESET}"

        echo -e ""
        echo -e "  ${BLUE} Required Parameters for gpinitsystem: ${RESET}"
        echo -e "  ${YELLOW}-----------------------------------------------------------------------------------------------------------------------------${RESET}"
        echo -e "  ${BLUE}SEG_PREFIX = gpseg            ${RESET}                  # Prefix for naming segment instances"
        echo -e "  ${BLUE}PORT_BASE  = 6000             ${RESET}                  # Starting port number for segments (increments per segment)"
        echo -e "  ${BLUE}DATA_DIRECTORY = (/data/primary /data/primary)${RESET}  # Locations for primary segment data directories"
        echo -e "  ${BLUE}MIRROR_DATA_DIRECTORY = (/data/mirror /data/mirror)${RESET}  # Locations for mirror segment data directories ( not required but we are creating mirrors here) "
        echo -e "  ${BLUE}MASTER_HOSTNAME = master        ${RESET}                # Hostname of the WarehousePG master node"
        echo -e "  ${BLUE}MASTER_DIRECTORY = /data/master${RESET}                 # Directory path where master stores its data"
        echo -e "  ${BLUE}MASTER_PORT = 5432           ${RESET}                   # Port used by the master to listen for connections"
        echo -e "  ${BLUE}TRUSTED_SHELL = ssh          ${RESET}                   # Protocol used by WarehousePG to connect to remote segment hosts"
        echo -e "  ${BLUE}CHECK_POINT_SEGMENTS = 8     ${RESET}                   # Number of WAL segments before a checkpoint is triggered"
        echo -e "  ${BLUE}ENCODING = UNICODE           ${RESET}                   # Default database encoding for storing character data"
        echo -e "  ${BLUE}ENCODING = UNICODE           ${RESET}                   # Not required as this can be created later as well."
        echo -e "  ${YELLOW}-----------------------------------------------------------------------------------------------------------------------------${RESET}"


        echo -e ""
        echo -e "${BLUE}=> Run gpinitsystem with config file${RESET}"
        echo -e "       gpinitsystem -c /home/gpadmin/gpinitsystem_config -h /home/gpadmin/hostfile"
        echo -e ""

        echo -e "${BLUE}=> Verify the initialization${RESET}"
        echo -e "       gpstate -s"
        echo -e ""

        echo -e "${BLUE}=> export these variables${RESET}"
        echo -e "       export PGPORT=5432"
        echo -e "       export MASTER_DATA_DIRECTORY=/data/master/gpseg-1"
        echo -e ""

        echo -e "${BLUE}=> Connect to the gpadmin database using psql${RESET}"
        echo -e "       psql"
        echo -e ""

        echo -e "${YELLOW}Run /tmp/training.sh again for the next step.${RESET}"
        exit 0
    fi

    mark_done "init_gp"


fi

echo -e ""
echo -e "-----------------------------------------------------------------------------------------"
echo -e "${BLUE}🎉 WarehousePG system setup is complete! Your system is now up and running.${RESET}"
echo -e "-----------------------------------------------------------------------------------------"
echo -e ""
echo -e "${BLUE}📌 Add the following to gpadmin profile file (such as .bashrc):${RESET}"
echo -e ""
echo -e "       source /usr/local/greenplum-db/greenplum_path.sh"
echo -e "       export GPHOME=/usr/local/greenplum-db"
echo -e "       export MASTER_DATA_DIRECTORY=/data/master/gpseg-1"
echo -e "       export PGPORT=5432"
echo -e "       export PGUSER=gpadmin"
echo -e "       export PGDATABASE=gpadmin"
echo -e ""
echo -e "${BLUE}📌 Then run: ${RESET}source ~/.bashrc"
echo -e ""


