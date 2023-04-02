#!/bin/bash

## Get location
_SCRIPT=$(realpath -s "$0")
_SCRIPTPATH=$(dirname "$_SCRIPT")

## Load env file(s)
set -a
_env_default_found=false
if [ -f "$_SCRIPTPATH/.env.default" ]; then
  source $_SCRIPTPATH/.env.default
  _env_default_found=true
fi

_env_found=false
if [ -f "$_SCRIPTPATH/.env" ]; then
  source $_SCRIPTPATH/.env
  _env_found=true
fi
set +a


## Environment functions
function _gen_server_env () {
  "$_SCRIPTPATH/env.py" $(find $_SCRIPTPATH -type f ! -path "*/refs/*" -name 'docker-compose.*.yml' -o -name '*.yaml.in') $(find $_SCRIPTPATH/systemd -type f -name '*.in') -s -v "$_SCRIPTPATH/env.json" -e "$_SCRIPTPATH/env.extra.json" -E "SERVER_PATH=$_SCRIPTPATH"
}

function gen_server_default_env () {
  _gen_server_env > "$_SCRIPTPATH/.env.default"
}

function gen_server_env () {
  _gen_server_env > "$_SCRIPTPATH/.env"
}

function gen_homepage_config () {
  for i in $(find $_SCRIPTPATH/homepage/config -type f ! -path "*/refs/*" -name '*.yaml.in')
  do
    envsubst < $i > ${i::-3}
    eval "echo \"$(cat ${i::-3})\"" > ${i::-3}
  done
}

function gen_server_services () {
  for i in $(find "$_SCRIPTPATH/systemd" -type f -name '*.in')
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
function _check_create () {
  if [ ! -e "$1" ] ; then
    touch "$1"
  fi
}

function _check_create_dir () {
  if [ ! -e "$1" ] ; then
    mkdir -p "$1"
  fi
}

function _srv_docker_compose () {
  _curr_pwd=$(pwd)
  cd $_SCRIPTPATH
	/usr/bin/docker-compose $(find -name 'docker-compose*.yml' -type f -printf '%p\t%d\n'  2>/dev/null | grep -v 'refs' | sort -n -k2 | cut -f 1 | awk '{print "-f "$0}') $@
  cd $_curr_pwd
}

function server_up () {
  _check_create $_SCRIPTPATH/.shadow
  _check_create $_SCRIPTPATH/traefik/acme.json
  _check_create $_SCRIPTPATH/simply-shorten/urls.sqlite
  _check_create $_SCRIPTPATH/fireflyiii/db.sqlite
  _srv_docker_compose up -d
}

function server_down () {
  _srv_docker_compose down
}

function server_install_services () {
  cp $(find "$_SCRIPTPATH/systemd" -type f -name '*.mount' -o -name '*.timer' -o -name '*.service') /usr/lib/systemd/system/
  systemctl daemon-reload
}

function server_init_config () {
  _check_create $_SCRIPTPATH/.shadow
  _check_create $_SCRIPTPATH/env.extra.json
}

function server_storage_dir () {
  declare -a _storage_dirs=("sshfs.vault" "sshfs.other" "gocryptfs.private" "gocryptfs.generic")
  for i in "${_storage_dirs[@]}"
  do
    _check_create_dir "$_SCRIPTPATH/storage/mount/$i"
  done
}

function server_init () {
  server_init_config

  gen_server_env
  gen_homepage_config
  gen_server_services

  server_install_services

  server_storage_dir
}
