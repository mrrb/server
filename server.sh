#!/bin/bash

## Get location
_SCRIPT=$(realpath -s "$0")
_SCRIPTPATH=$(dirname "$_SCRIPT")

## Load env file(s)
set -a
_env_default_found=false
if [ -f '.env.default' ]; then
  source $_SCRIPTPATH/.env.default
  _env_default_found=true
fi

_env_found=false
if [ -f '.env' ]; then
  source $_SCRIPTPATH/.env
  _env_found=true
fi
set +a


## Environment functions
function gen_server_default_env () {
  "$_SCRIPTPATH/env.py" $(find $_SCRIPTPATH -type f ! -path "*/refs/*" -name 'docker-compose.*.yml') $(find $_SCRIPTPATH/homepage/config -type f ! -path "*/refs/*" -name '*.yaml.in') > "$_SCRIPTPATH/.env.default"
}

function gen_homepage_config () {
  for i in $(find $_SCRIPTPATH/homepage/config -type f ! -path "*/refs/*" -name '*.yaml.in')
  do
    envsubst < $i > ${i::-3}
    eval "echo \"$(cat ${i::-3})\"" > ${i::-3}
  done
}

## Crypt functions
function sha256_passwd () {
  if (( $# != 2 )); then
    >&2 echo "$(basename $0) <user> <password>"
  else
    echo -n $1':{SHA256}'
    echo $2 | sha256sum --zero | cut -d ' ' -f 1
  fi
}

## Control functions
function _srv_docker_compose () {
  _curr_pwd=$(pwd)
  cd $_SCRIPTPATH
	/usr/bin/docker-compose $(find -name 'docker-compose*.yml' -type f -printf '%p\t%d\n'  2>/dev/null | grep -v 'refs' | sort -n -k2 | cut -f 1 | awk '{print "-f "$0}') $@
  cd $_curr_pwd
}

function server_up () {
  _srv_docker_compose up -d
}

function server_down () {
  _srv_docker_compose down
}
