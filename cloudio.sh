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

### CONFIGURATION ###

# Absolute paths
LOCAL_DIR=~/cloud
CONFIG=~/.cloudio
REMOTE_DIR=/home/myremote/cloud

# Set KEYPAIR="" if you are not using a keypair
KEYPAIR=~/secret.pem

REMOTE_USER=myremote
REMOTE_HOST=myremotehost
NOTIFICATIONS=true

### END CONFIGURATION ###

VERSION=0.2.1

if [[ ! -d $CONFIG ]]; then
    mkdir $CONFIG
fi

touch $CONFIG/local_current \
      $CONFIG/local_next \
      $CONFIG/remote_next \
      $CONFIG/remote_current

function _notify {
    if [[ $NOTIFICATIONS == true ]]; then
        if hash notify-send 2>/dev/null; then
            notify-send  "cloudio.sh:" "$@"
        fi
    fi
}

function _getNext {
    case $1 in
        "local")
            ls -la $LOCAL_DIR>$CONFIG/local_next
            ;;
        "remote")
            rsync --list-only --dry-run \
                -e ssh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/ \
                $LOCAL_DIR/>$CONFIG/remote_next
            ;;
    esac
}

_notify "Starting..."

# Adding keypair if needed and checking if interactive shell
if [[ $KEYPAIR ]]; then
    ssh-add $KEYPAIR
else
    if [[ ! -t 0 ]]; then
        _notify "Warning: you are running cloudio.sh in a non \
interactive shell, if you need to type your password, \
you won't be able to."
    fi
fi

# Looking for remote changes
_getNext "remote"

if [[ $(diff $CONFIG/remote_next $CONFIG/remote_current) != "" ]]; then
    # There are some remote changes
    REMOTE_CHANGES=true
else
    # No remote changes
    REMOTE_CHANGES=false
fi

# Looking for changes
_getNext "local"

if [[ $(diff $CONFIG/local_next $CONFIG/local_current) != "" ]]; then
    # There are some local changes
    LOCAL_CHANGES=true
else
    # No local changes
    LOCAL_CHANGES=false
fi

# Performing!

if [[ $REMOTE_CHANGES == false && $LOCAL_CHANGES == true ]]; then
    _notify "Pushing local changes to cloud..."
    rsync -rtu --delete $LOCAL_DIR/ \
        -e ssh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/

    _getNext "remote"

elif [[ $REMOTE_CHANGES == true && $LOCAL_CHANGES == false ]]; then
    _notify "Pulling changes from cloud..."
    rsync -rvau --delete -e ssh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/ \
        $LOCAL_DIR/

    _getNext "local"

elif [[ $REMOTE_CHANGES == true && $LOCAL_CHANGES == true ]]; then

    # Creating temporary directory
    LOCAL_TMP="/tmp/$(tr -dc "[:alpha:]" < /dev/urandom | head -c 4)"
    mkdir $LOCAL_TMP

    # Moving local files (which contain changes)
    shopt -s dotglob
    mv $LOCAL_DIR/* $LOCAL_TMP

    # Pulling changes from remote
    _notify "Pulling changes from cloud..."
    rsync -rvau --delete -e ssh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/ \
        $LOCAL_DIR/

    # Moving back local files, skipping those which are newer from remo
    mv -u $LOCAL_TMP/* $LOCAL_DIR
    shopt -u dotglob

    _notify "Pushing local changes to cloud..."
    # Pushing the new local to remote
    rsync -rtu --delete $LOCAL_DIR/ \
        -e ssh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/

    #removing temporary dir
    rm -r $LOCAL_TMP

    # Updating cloudio data
    _getNext "local"
    _getNext "remote"
fi

cp $CONFIG/remote_next  $CONFIG/remote_current
cp $CONFIG/local_next   $CONFIG/local_current
_notify "Finished :-)"
