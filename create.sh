#!/bin/bash
#===============================================================================
#          FILE:  create.sh
#         USAGE:  ./create.sh <config.json>
#   DESCRIPTION: Create the development environment based on the configuration
#                file given.
#
#       OPTIONS:  $1 The file we use to configure the development environment
#
#  REQUIREMENTS:  /
#        AUTHOR:  Xavier Geerinck (thebillkidy@gmail.com)
#       COMPANY:  /
#       VERSION:  1.0.0
#       CREATED:  07/APR/15 15:59 CET
#       UPDATED:  07/APR/15 15:59 CET
#      REVISION:  1.0 - Base Project
#===============================================================================
# 0) Base Path is /takeoff/
# 1) Check if the config file is valid json and valid structure
# 2) Check if Docker is installed, if not print an error
#    (error because CoreOS has this installed by default)
# 3) For every program configured do:
# 3.1) Run dockerfile
# 3.2) Copy over configuration files
# 3.3) Run custom commands
# 3.4) If auto_start == true, then install auto startup script
#===============================================================================
BASE_PATH='/takeoff/'
BASE_PATH_PROJECTS='projects/'
BASE_PATH_IMAGES='images/'
BASE_PROJECT_NAME=$1
# $1 is the project name, so need to correct project dir config file
CONFIG_FILE=$BASE_PATH$BASE_PATH_PROJECTS$1'/config.json'
IMAGE_PATH=$BASE_PATH$BASE_PATH_PROJECTS$1'/'$BASE_PATH_IMAGES

validate_parameters () {
    if [ -z "$1" ]; then
        echo "Usage: `basename $0` <project_name>"
    	echo "Example: ./create.sh takeoff"

    	exit 0
    fi
}

# jq -r gives the raw value (no quotes)
process_config_file () {
    # First try to remove the docker containers in case they exist
    remove_docker_containers

    # Start installing
    PROGRAM_COUNT=`cat $CONFIG_FILE | ./jq ".programs | length" -r`
    DATA_FOLDER_LOCATION=`cat $CONFIG_FILE | ./jq ".data_folder_location // empty" -r`
    DATA_FOLDER_LOCATION=${DATA_FOLDER_LOCATION:-'$PROJECT_DIR$/data'} # Default path is $PROJECT_DIR$/data
    DATA_FOLDER_LOCATION=${DATA_FOLDER_LOCATION/\$PROJECT_DIR\$/$BASE_PATH$BASE_PATH_PROJECTS$1} # Replace $PROJECT_DIR$ if exist

    LOG_FOLDER_LOCATION=`cat $CONFIG_FILE | ./jq ".log_folder_location  // empty" -r`
    LOG_FOLDER_LOCATION=${LOG_FOLDER_LOCATION:-'$PROJECT_DIR$/logs'} # Default path is $PROJECT_DIR$/logs
    LOG_FOLDER_LOCATION=${LOG_FOLDER_LOCATION/\$PROJECT_DIR\$/$BASE_PATH$BASE_PATH_PROJECTS$1} # Replace $PROJECT_DIR$ if exist

    for ((PROGRAM_IDX=0;PROGRAM_IDX<PROGRAM_COUNT;PROGRAM_IDX++));
    do
        PROGRAM_NAME=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].name" -r`
        PROGRAM_BASEPATH=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].basepath" -r`
        PROGRAM_AUTOSTART=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].auto_start" -r`
        PROGRAM_CONTAINER_NAME=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].container_name" -r`

        PROGRAM_CONFIG_FILE_COUNT=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].config_files | length" -r`
        PROGRAM_CUSTOM_COMMAND_COUNT=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].custom_commands | length" -r`
        DOCKER_RUN_PARAM_COUNT=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].docker_run_parameters | length" -r`

        # Debug Line
        echo "name: $PROGRAM_NAME, path: $PROGRAM_BASEPATH, file: $PROGRAM_DOCKERFILE, autostart: $PROGRAM_AUTOSTART, config_files: $PROGRAM_CONFIG_FILE_COUNT, custom_command: $PROGRAM_CUSTOM_COMMAND_COUNT"
        echo "DATA_FOLDER_LOCATION: $DATA_FOLDER_LOCATION/$PROGRAM_BASEPATH"
        echo "LOG_FOLDER_LOCATION: $LOG_FOLDER_LOCATION/$PROGRAM_BASEPATH"

        # If container name set, use that else use the name
        if [[ -z "$PROGRAM_CONTAINER_NAME" || "$PROGRAM_CONTAINER_NAME" == "" || "$PROGRAM_CONTAINER_NAME" == "null" ]]
            then
            PROGRAM_CONTAINER_NAME="$PROGRAM_NAME"
        fi

        # Process the docker run parameters into a command string
        DOCKER_RUN_CMD=""

        # Process RUN CMD params
        for ((DOCKER_RUN_PARAM_IDX=0;DOCKER_RUN_PARAM_IDX<DOCKER_RUN_PARAM_COUNT;DOCKER_RUN_PARAM_IDX++));
        do
            PARAM_DESCRIPTION=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].docker_run_parameters[$DOCKER_RUN_PARAM_IDX].description" -r`
            PARAM_VALUE=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].docker_run_parameters[$DOCKER_RUN_PARAM_IDX].value" -r`
            PARAM_KEY=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].docker_run_parameters[$DOCKER_RUN_PARAM_IDX].param" -r`

            # Replace Built In variables:
            # $PROJECT_DIR$ --> This is the project directory (example: /takeoff/projects/takeoff)
            # $DATA_DIR$ --> Replace with data_folder_location
            # $LOG_DIR$ --> Replace with log_folder_location
            PARAM_VALUE=${PARAM_VALUE/\$PROJECT_DIR\$/$BASE_PATH$BASE_PATH_PROJECTS$1}
            PARAM_VALUE=${PARAM_VALUE/\$DATA_DIR\$/$DATA_FOLDER_LOCATION}
            PARAM_VALUE=${PARAM_VALUE/\$LOG_DIR\$/$LOG_FOLDER_LOCATION}

            # Add to the run cmd
            DOCKER_RUN_CMD="$DOCKER_RUN_CMD $PARAM_KEY $PARAM_VALUE"
        done

        # Forward the vagrant synced dir project dir to the docker container
        DOCKER_RUN_CMD="$DOCKER_RUN_CMD -v $BASE_PATH$BASE_PATH_PROJECTS$1:/takeoff"

        # Install docker container
        install_docker_container "$IMAGE_PATH" "$PROGRAM_BASEPATH" "$PROGRAM_NAME"

        # Start the docker container with the run cmd
        run_docker_container "$PROGRAM_NAME" "$PROGRAM_CONTAINER_NAME" "$DOCKER_RUN_CMD"

        # If auto_start is set, create a systemd file
        if [[ "$PROGRAM_AUTOSTART" -eq "true" ]]
            then
            create_docker_startup "$PROGRAM_NAME" "$PROGRAM_CONTAINER_NAME" "$DOCKER_RUN_CMD"
        fi

        # Copy over the config files
        for ((CONFIG_FILE_IDX=0;CONFIG_FILE_IDX<PROGRAM_CONFIG_FILE_COUNT;CONFIG_FILE_IDX++));
        do
            CONFIG_FILE_SRC=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].config_files[$CONFIG_FILE_IDX].src" -r`
            CONFIG_FILE_DEST=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].config_files[$CONFIG_FILE_IDX].dest" -r`

            copy_over_file "$PROGRAM_CONTAINER_NAME" "$CONFIG_FILE_SRC" "$CONFIG_FILE_DEST"
        done

        # Run the custom commands
        for ((CUSTOM_COMMAND_IDX=0;CUSTOM_COMMAND_IDX<PROGRAM_CUSTOM_COMMAND_COUNT;CUSTOM_COMMAND_IDX++));
        do
            COMMAND_DESCRIPTION=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].custom_commands[$CUSTOM_COMMAND_IDX].description" -r`
            COMMAND_CMD=`cat $CONFIG_FILE | ./jq ".programs[$PROGRAM_IDX].custom_commands[$CUSTOM_COMMAND_IDX].command" -r`

            # Replace hardcoded params
            COMMAND_CMD=${COMMAND_CMD/\$DATA_DIR\$/$DATA_FOLDER_LOCATION}
            COMMAND_CMD=${COMMAND_CMD/\$LOG_DIR\$/$LOG_FOLDER_LOCATION}

            run_command "$PROGRAM_CONTAINER_NAME" "$COMMAND_CMD" "$COMMAND_DESCRIPTION"
        done

        echo ""
        echo ""
    done
}

# $1 = Container Name
# $2 = src
# $3 = dest
copy_over_file () {
    echo "Installing ${BASE_PATH}images/${PROGRAM_BASEPATH}$2 into $3"
    docker exec $1 sh -c "mkdir -p `dirname $3` && cp ${BASE_PATH}images/${PROGRAM_BASEPATH}$2 $3"
}

# $1 = DOCKER CONTAINER
# $2 = COMMAND
# $3 = COMMAND DESCR
run_command () {
    echo "Running command: $2 in docker container $1 description: $3"
    docker exec $1 sh -c "$2"
}

# $1 = IMAGE_PATH
# $2 = PROGRAM_BASEPATH
# $3 = CONTAINER_NAME
# NOTE: Might need to provide --rm=false to not remove the container on start
install_docker_container () {
    echo "Building $3 dockerfile located at: $1$2Dockerfile"
    docker build -t "$3" "$1$2"
}

# $1 = CONTAINER_NAME
# $2 = DOCKER CONTAINER NAME
# $3 = DOCKER RUN COMMAND
# -i, --interactive=false    Keep STDIN open even if not attached
# -d, --detach=false         Detached mode: run the container in the background and print the new container ID
# -t, --tty=false            Allocate a pseudo-TTY
# docker run --name mariadb -t -d -i -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root -v #{data_folder_location}/mariadb:/var/lib/mysql mariadb
run_docker_container () {
    echo "Starting container: $1, with parameters $3"
    docker run -i -d -t --name $2 $3 $1
}

create_docker_startup () {
    echo "Creating startup file for container: $1, at /var/lib/${BASE_PROJECT_NAME}-$1.service"

    if [[ ! -d "/etc/systemd/system/multi-user.target.wants" ]]; then
        mkdir -p '/etc/systemd/system/multi-user.target.wants'
    fi

    if [[ ! -d "/var/lib/takeoff" ]]; then
        mkdir -p '/var/lib/takeoff'
    fi

parm3=$3

# Configure auto restart, note we allow 5 restarts every hour! ( > so overwrite, >> is append )
# Note, we use -a to attach to the STDOUT/STDERR since we manage docker with systemd
cat > /var/lib/takeoff/${BASE_PROJECT_NAME}-$1.service <<HERE
[Unit]
Description=${BASE_PROJECT_NAME}-$1-container
Requires=docker.service
After=docker.service

[Service]
Restart=always
RestartSec=5
StartLimitInterval=3600
StartLimitBurst=5
TimeoutStartSec=5
ExecStart=/bin/bash -c "\
    while [[ ! -d ${IMAGE_PATH} ]]; do \
        sleep 1; \
    done; \
/usr/bin/docker start -a $2"
ExecStop=/usr/bin/docker stop $2
StandardInput=tty-force

[Install]
WantedBy=multi-user.target
HERE

# Enable the file
sudo systemctl enable /var/lib/takeoff/${BASE_PROJECT_NAME}-$1.service
}

# Removes all currently installed docker containers
remove_docker_containers() {
    if [[ `docker ps --no-trunc -aq | wc -l` -gt 0 ]]
        then
        echo "Removing all docker containers"
        docker stop `docker ps --no-trunc -aq`
        docker rm `docker ps --no-trunc -aq`
    fi
}

validate_parameters $*
process_config_file $*
