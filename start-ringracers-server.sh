#!/bin/bash
echo "Running SRB2Kart as $UID : $PID ..."

echo "Mods directory: ${SRB2KART_MODS_DIRECTORY}"
MOD_LAYERS=$(ls -d ~/.ringracers/servermods/*/ | while read line; do echo "$(basename $line)"; done)
UNSORTED_MODS=$(ls ${SRB2KART_MODS_DIRECTORY} | egrep '\.pk3$|\.wad$|\.lua$' | shuf)


echo "Mods active:\
$MODS"

echo "Starting NGINX for FastDL"
envsubst < /etc/nginx/conf.d/direct-download.conf.template > /etc/nginx/conf.d/direct-download.conf
nginx


set -ex && ringracers $@ -port ${RINGRACERS_PORT_FWD} -room 33 ${EXTRA_RUN_ARGS} -file ${MODS} ${EXTRA_MOD_FILES}

