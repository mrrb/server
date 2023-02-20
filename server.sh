#!/bin/bash

## Get location
_SCRIPT=$(realpath -s "$0")
_SCRIPTPATH=$(dirname "$_SCRIPT")

## Environment functions
function gen_server_default_env () {
  "$_SCRIPTPATH/env.py" $(find $_SCRIPTPATH -type f ! -path "refs/*" -name 'docker-compose.*.yml') > "$_SCRIPTPATH.env.default"
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

## Load env file(s)
_env_default_found=false
if [ -f '.env.default' ]; then
    source .env.default
    _env_default_found=true
fi

_env_found=false
if [ -f '.env' ]; then
    source .env
    _env_found=true
fi
