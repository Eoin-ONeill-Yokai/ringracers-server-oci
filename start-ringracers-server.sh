#!/bin/bash
echo "Running \"Dr Robotnik's Ring Racers\" as $UID : $PID ..."

echo "Mods directory: ${RINGRACERS_MODS_DIRECTORY}"
MOD_LAYERS=$(ls -d ${RINGRACERS_MODS_DIRECTORY}/*/ | while read line; do echo "$(basename $line)"; done)
UNSORTED_MODS=$(ls ${RINGRACERS_MODS_DIRECTORY} | egrep '\.pk3$|\.wad$|\.lua$' | shuf)
[[ -z $UNSORTED_MODS ]] &&  MOD_LOAD_CMD="" || MOD_LOAD_CMD="-file ${UNSORTED_MODS}"

mkdir -p ${RINGRACERS_MODS_DIRECTORY}

echo "Mods active:\
$MODS"

echo "Starting NGINX for FastDL"
envsubst < /etc/nginx/http.d/direct-download.conf.template > /etc/nginx/http.d/direct-download.conf
nginx

# If there's no user password, we should just generate one for the user..
if [ -z $SERVER_PASSWORD ]; then
    echo "No server password (SERVER_PASSWORD) detected. Generating random password..."
    export SERVER_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo $SERVER_PASSWORD
fi

if [[ ! -f ${RINGRACERS_CONFIG_DIRECTORY}/ringserv.cfg ]]; then
    echo $SERVER_PASSWORD
    envsubst < /etc/ringracers/ringserv.cfg.template > ~/.ringracers/ringserv.cfg
fi

set -ex && ringracers $@ -port ${RINGRACERS_PORT_FWD} -room 33 ${EXTRA_RUN_ARGS} ${MOD_LOAD_CMD} ${EXTRA_MOD_FILES}
