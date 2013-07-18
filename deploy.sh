#!/bin/bash

#   Copyright 2013 Claudio "Dawson" d'Angelis <http://claudiodangelis.com/+>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

VERSION=0.1

function _dump_config {
    echo "Dumping config to $CONFIG_FILE ..."
    echo "LOCAL_DIR=$LOCAL_DIR">>$CONFIG_FILE
    echo "CONFIG_DIR=$CONFIG_DIR">>$CONFIG_FILE
    echo "REMOTE_DIR=$REMOTE_DIR">>$CONFIG_FILE
    echo "CONFIG_FILE=$CONFIG_FILE">>$CONFIG_FILE
    echo "KEYPAIR=$KEYPAIR">>$CONFIG_FILE
    echo "REMOTE_USER=$REMOTE_USER">>$CONFIG_FILE
    echo "REMOTE_HOST=$REMOTE_HOST">>$CONFIG_FILE
    echo "NOTIFICATIONS=$NOTIFICATIONS">>$CONFIG_FILE
    echo "PATH_TO_CLOUDIO=$PATH_TO_CLOUDIO">>$CONFIG_FILE
}

function _replace_var {
    sed -e "s/^$1=\"\"$/$1=\"$(eval echo \$$1 | sed 's/\//\\\//g')\"/g"
}

function _install_cloudio {
    cat cloudio.sh | _replace_var LOCAL_DIR    | \
                     _replace_var CONFIG_DIR   | \
                     _replace_var REMOTE_DIR   | \
                     _replace_var CONFIG_FILE  | \
                     _replace_var KEYPAIR      | \
                     _replace_var REMOTE_USER  | \
                     _replace_var REMOTE_HOST  | \
                     _replace_var NOTIFICATIONS>$PATH_TO_CLOUDIO/cloudio.sh

    chmod +x $PATH_TO_CLOUDIO/cloudio.sh
    echo ""
    echo "cloudio.sh successfully installed!"
    echo ""

    _dump_config

    echo "Do you want to run it now?"
    
    while [[ true ]]; do
        echo "[y/n]"
        read FIRST_RUN
        FIRST_RUN=$(echo $FIRST_RUN | tr '[A-Z]' '[a-z]')
        if [[ $FIRST_RUN == "y" || $FIRST_RUN == "yes" ||\
              $FIRST_RUN == "n" || $FIRST_RUN == "no" ]]; then
              break;
        fi
    done

    if [[ ${FIRST_RUN:0:1} == "y" ]]; then
        $PATH_TO_CLOUDIO/cloudio.sh
    fi

}

echo "Welcome to cloudio.sh's deploy script."
echo "cloudio.sh will keep in-sync a remote folder and a local folder"
echo ""
echo "!!! Warning: garbage in -> garbage out !!!"
echo ""
echo "If you want to use an existing config file, type its path, e.g."
echo "~/.cloudio/config"
echo ""
echo "Press [Enter] if you don't have any existing config file or [CTRL+C] to \
exit"

read CONFIG_FILE

eval CONFIG_FILE=$CONFIG_FILE

if [[ $CONFIG_FILE == "" ]]; then
    # You don't want to use an existing config file


    echo "Where do you want to install cloudio.sh? e.g. ~/scripts/"
    echo "(if path does not exist, it will be created)"
    read PATH_TO_CLOUDIO

    eval PATH_TO_CLOUDIO=$PATH_TO_CLOUDIO
    if [[ ! -d $PATH_TO_CLOUDIO ]]; then
        # It does not exist, creating it
        mkdir -p $PATH_TO_CLOUDIO
    fi

    echo "Where do you want to keep your config file? Recommended: ~/.cloudio"
    read CONFIG_DIR
    eval CONFIG_DIR=$CONFIG_DIR
    CONFIG_FILE=$CONFIG_DIR/config
    
    if [[ ! -d $CONFIG_DIR ]]; then
        mkdir $CONFIG_DIR
    fi
    touch $CONFIG_FILE

    # Configuration:
    echo "Good. Do you use a .pem keypair file to store your SSH credential?"
    KEYPAIR_ACCESS=false
    while [[ true ]]; do
        echo "[y/n]"
        read USING_KEYPAIR
        USING_KEYPAIR=$(echo $USING_KEYPAIR | tr '[A-Z]' '[a-z]')
        if [[ $USING_KEYPAIR == "y" || $USING_KEYPAIR == "yes" ||\
              $USING_KEYPAIR == "n" || $USING_KEYPAIR == "no" ]]; then
              break;
        fi
    done

    if [[ ${USING_KEYPAIR:0:1} == "y" ]]; then
        KEYPAIR_ACCESS=true
        echo "Path to your .pem file? e.g. ~/secrets/remote.pem"
        read KEYPAIR
        eval KEYPAIR=$KEYPAIR
    else
        KEYPAIR=""
    fi

    echo "What's the remote host address?"
    read REMOTE_HOST

    echo "What's the name of the remote user?"
    read REMOTE_USER

    echo "Ok, now, *full* path to your remote cloud folder? e.g. \
/home/remote_user/cloud"

    read REMOTE_DIR

    echo "Almost done. Path to your *local* folder? e.g. ~/cloud"
    echo "(if folder does not exist it will be created)"

    read LOCAL_DIR
    eval LOCAL_DIR=$LOCAL_DIR

    if [[ ! -d $LOCAL_DIR ]]; then
        # It does not exist, creating it
        mkdir -p $LOCAL_DIR
    fi

    echo "Do you want notifications? (\`notify-send\` required)"
    while [[ true ]]; do
        echo "[y/n]"
        read NOTIFICATIONS
        NOTIFICATIONS=$(echo $NOTIFICATIONS | tr '[A-Z]' '[a-z]')
        if [[ $NOTIFICATIONS == "y" || $NOTIFICATIONS == "yes" ||\
              $NOTIFICATIONS == "n" || $NOTIFICATIONS == "no" ]]; then
              break;
        fi
    done

    if [[ ${NOTIFICATIONS:0:1} == "y" ]]; then
        NOTIFICATIONS=true
    else
        NOTIFICATIONS=false
    fi

    echo "All done!"
    echo "Installing cloudio.sh ..."

    _install_cloudio
    
else
    if [[ ! -f $CONFIG_FILE ]]; then
        # You want to use an existing config file, but it does not exist
        echo "Error: $CONFIG_FILE does not exist, exiting."
        exit
    else
        # You want to use an existing file, and it actually exists
        echo "Reading configuration..."
        source $CONFIG_FILE
        echo "Installing cloudio.sh ..."

        _install_cloudio

    fi
fi
