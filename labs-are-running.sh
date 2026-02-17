#!/bin/bash
#
# This script ensures that only one lab is running at the same time
# The different Docker Compose scripts don't like sharing the same port
#
# Written by Andreas 'ads' Scherbaum <andreas.scherbaum@enterprisedb.com>


# set to 'true' to enable verbose output, 'false' otherwise.
VERBOSE=false


START_DIR="$(pwd)"
START_DIR_BASENAME="$(basename "$START_DIR")"
LABS_ARE_RUNNING=false


log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "VERBOSE: $1"
    fi
}

log_error() {
    echo "ERROR: $1" >&2
}

log_success() {
    echo "SUCCESS: $1"
}


log_verbose "Starting directory: $START_DIR"
log_verbose "Base name of starting directory: $START_DIR_BASENAME"

PARENT_DIR="$(dirname "$START_DIR")"
if [ ! -d "$PARENT_DIR" ]; then
    # how did we even end up here?
    log_error "Parent directory '$PARENT_DIR' not found. Exiting."
    exit 1
fi
log_verbose "Parent directory: $PARENT_DIR"


cd "$PARENT_DIR" || { log_error "Could not change to parent directory '$PARENT_DIR'. Exiting."; exit 1; }

echo "Scanning for running Labs ..."

# find all directories in the parent directory, excluding the one we started in
while IFS= read -r -d $'\0' dir; do
    # remove leading './' from the directory name
    dir_name="${dir#./}"

    # skip the current directory ('.') and the original starting directory.
    if [[ "$dir_name" == "." || "$dir_name" == "$START_DIR_BASENAME" ]]; then
        log_verbose "Skipping directory: $dir_name"
        continue
    fi

    # check if the directory is valid and we can enter it.
    if [ -d "$dir_name" ]; then
        log_verbose "Processing directory: $dir_name"
        echo "  Scanning Lab directory: $dir_name"
        cd "$dir_name" || { log_error "Could not enter directory '$dir_name'. Skipping."; continue; }

        # check for docker-compose.yml or docker-compose.yaml before running ps.
        if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] || [ -f "compose.yaml" ]; then
            log_verbose "  Found docker-compose file in $dir_name. Running 'docker compose ps -q'"
            # run "docker compose ps -q" and capture output
            CONTAINER_IDS=$(docker compose ps -q 2>/dev/null)

            if [ -n "$CONTAINER_IDS" ]; then
                echo "    WARNING: Lab is running in '$dir_name'!"
                #echo "$CONTAINER_IDS" | sed 's/^/      - /'
                LABS_ARE_RUNNING=true
                echo "    make -C ../$dir_name stop"
            else
                log_verbose "    No running Docker containers found in '$dir_name'"
            fi
        else
            log_verbose "  No docker-compose file found in '$dir_name'. Skipping Docker check."
        fi

        # go back to the parent directory for the next iteration
        cd .. || { log_error "Could not return to parent directory from '$dir_name'. This might cause issues."; exit 1; }
    else
        log_verbose "  '$dir_name' is not a valid directory or accessible. Skipping."
    fi
# this avoids starting a subshell for each iteration
# which in turn makes $LABS_ARE_RUNNING a local variable
done < <(find . -maxdepth 1 -type d -print0)

cd "$START_DIR" || { log_error "Could not return to starting directory '$START_DIR'."; exit 1; }

if [ "$LABS_ARE_RUNNING" = true ]; then
    log_error "Check finished: Found running Labs! Please stop other Labs first!"
    exit 1
else
    log_success "Check completed, good to go for starting Lab ..."
    exit 0
fi
