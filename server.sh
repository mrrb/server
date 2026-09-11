#!/bin/bash

## Get location
# _SCRIPT=$(realpath -s "$0")
# _SCRIPTPATH=$(dirname "$_SCRIPT")


# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
_SCRIPTPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
_SERVICESPATH="$_SCRIPTPATH/services"

## Load env file(s)
function load_env () {
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
}
load_env


## Environment functions
function _gen_server_env () {
  "$_SCRIPTPATH/env.py" $(find $_SCRIPTPATH -type f ! -path "*/.*/*" ! -path "*/refs/*" ! -path "*/disable/*" -name 'docker-compose.*.yml' -o -name '*.yaml.in' -o -name '*.yml.in') $(find $_SCRIPTPATH/systemd -type f -name '*.in') -s -v "$_SCRIPTPATH/env.json" -e "$_SCRIPTPATH/env.extra.json" -E "SERVER_PATH=$_SCRIPTPATH"
}

function gen_server_default_env () {
  _gen_server_env > "$_SCRIPTPATH/.env.default"
}

function gen_server_env () {
  _gen_server_env > "$_SCRIPTPATH/.env"
}

# Expand ${VAR:-default} bash-style parameter defaults left over after envsubst,
# without eval'ing file content (envsubst alone doesn't support the ":-default" form).
function _expand_defaults () {
  local _content=$1
  local _var _default _val
  while [[ "$_content" =~ \$\{([A-Za-z_][A-Za-z0-9_]*):-([^}]*)\} ]]; do
    _var="${BASH_REMATCH[1]}"
    _default="${BASH_REMATCH[2]}"
    _val="${!_var:-$_default}"
    _content="${_content//${BASH_REMATCH[0]}/$_val}"
  done
  printf '%s' "$_content"
}

function _render_template () {
  local _in=$1 _out=$2
  envsubst < "$_in" > "$_out"
  _expand_defaults "$(cat "$_out")" > "$_out"
}

function gen_homepage_config () {
  for i in $(find $_SERVICESPATH/homepage/config -type f ! -path "*/refs/*" -name '*.yaml.in')
  do
    _render_template "$i" "${i::-3}"
  done
}

function gen_traefik_config () {
  for i in $(find $_SERVICESPATH/traefik/dynamic -type f ! -path "*/refs/*" -name '*.yml.in')
  do
    _render_template "$i" "${i::-3}"
  done
}

function gen_server_services () {
  for i in $(find "$_SCRIPTPATH/systemd" -type f -name '*.in')
  do
    _render_template "$i" "${i::-3}"
  done
}

function gen_searxng_config () {
  for i in $(find $_SERVICESPATH/searxng/config -type f ! -path "*/refs/*" -name '*.in')
  do
    _render_template "$i" "${i::-3}"
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

function store_gocrypt_password () {
  echo -n "$1 password: "
  read -s _password
  echo

  echo -n $_password > $_SCRIPTPATH/storage/.keys/$1.key

  chown -R ${STORAGE_UID:-0}:${STORAGE_GID:-0} $_SCRIPTPATH/storage/.keys/$1.key
  chmod 600 $_SCRIPTPATH/storage/.keys/$1.key
}

function server_authelia_user_add () {
  ## Add a user to the Authelia users database (users_database.yml)
  ##   Usage: server_authelia_user_add <username> [displayname] [groups,comma,separated]
  ##    - Prompts for the password (hidden). Existing users are refused (edit manually)
  ##    - The existing DB is backed up to config/.backup/ before any modification
  ##    - Authelia watches the file (watch: true), so the change applies without a restart

  # Vars
  local _username=$1 _displayname=$2 _groups=$3 _password _hash _users_file
  _users_file=$_SERVICESPATH/authelia/config/users_database.yml

  # Sanity checks
  if [ -z "$_username" ]; then
    >&2 echo "usage: server_authelia_user_add <username> [displayname] [groups,comma,separated]"
    return 1
  fi
  if [[ ! "$_username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    >&2 echo "error: username may only contain letters, digits, '_' and '-'"
    return 1
  fi

  # Ask for password
  echo -n "password for $_username: "
  read -s _password
  echo
  if [ -z "$_password" ]; then
    >&2 echo "error: empty password"
    return 1
  fi

  # Backup the existing database before touching it (git-ignored via **/.backup)
  if [ -f "$_users_file" ]; then
    local _backup_dir=$_SERVICESPATH/authelia/config/.backup
    _check_create_dir "$_backup_dir"

    cp -p "$_users_file" "$_backup_dir/users_database.yml.$(date +%Y%m%d-%H%M%S)"
    echo "backup: $_backup_dir/users_database.yml.$(date +%Y%m%d-%H%M%S)"
  fi

  # Gen password hash using authelia CLI (docker)
  if ! _raw=$(/usr/bin/docker run --rm authelia/authelia:${AUTHELIA_IMAGE_VERSION:-latest} \
      authelia crypto hash generate argon2 --password "$_password"); then
    >&2 echo "error: failed to generate password hash (docker/authelia CLI)"
    return 1
  fi

  # CLI prints "Digest: $argon2id$...". Keep only the hash itself
  _hash=$(printf '%s\n' "$_raw" | tail -n 1 | sed 's/^Digest: //')
  if [[ ! "$_hash" =~ ^\$argon2 ]]; then
    >&2 echo "error: unexpected hash output from authelia CLI: '$_hash'"
    return 1
  fi

  # Update users file (w/ python)
  python3 - "$_users_file" "$_username" "${_displayname:-$_username}" "$_groups" "$_hash" <<'PY'
import os
import sys

import yaml

users_file, username, displayname, groups_csv, password_hash = sys.argv[1:6]

if os.path.exists(users_file):
  try:
    data = yaml.safe_load(open(users_file)) or {}
  except yaml.YAMLError as exc:
    sys.exit(f"error: cannot parse {users_file}: {exc}")

  if not isinstance(data, dict) or not isinstance(data.get("users", {}), dict):
    sys.exit(f"error: unexpected structure in {users_file}")
else:
  data = {"users": {}}

users = data.setdefault("users", {})
if username in users:
  sys.exit(f"error: user '{username}' already exists in {users_file} (edit manually)")

entry = {"displayname": displayname, "password": password_hash}
groups = [g.strip() for g in groups_csv.split(",") if g.strip()] if groups_csv else []
if groups:
  entry["groups"] = groups

users[username] = entry

with open(users_file, "w") as fh:
  yaml.safe_dump(data, fh, sort_keys=False, default_flow_style=False)
os.chmod(users_file, 0o600)

yaml.safe_load(open(users_file))
print(f"user '{username}' written to {users_file} (groups: {groups or 'none'})")
PY
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

function _chown_storage () {
  _check_create_dir $1
  chown -R ${STORAGE_UID:-0}:${STORAGE_GID:-0} $1
}

function _srv_docker_compose () {
  _curr_pwd=$(pwd)
  cd $_SCRIPTPATH
	/usr/bin/docker compose -p ${SERVER_NAME:-server} $(find -name 'docker-compose*.yml' -not -path "*/.*/*" ! -path "*/refs/*" ! -path "*/disable/*" -type f -printf '%p\t%d\n'  2>/dev/null | sort -n -k2 | cut -f 1 | awk '{print "-f "$0}') $@
  cd $_curr_pwd
}


function server_build () {
  ## Build (or update) locally built images (e.g. nanobot, nanobot-sandbox)
  ##   Usage: server_build [SERVICE...]
  ##     - No args builds every service with a build section
  _srv_docker_compose build --pull "$@"
}

function server_compose () {
  ## Run one-off compose commands against the full stack
  _srv_docker_compose "$@"
}


## Permanent files/dirs and permissions functions
# function server_perma_filestash_init () {
#   _check_create_dir $_SERVICESPATH/filestash/data/
#   sed -i.bck  's/^.*state:/#&/' $_SERVICESPATH/filestash/docker-compose.filestash.yml
# }

# function server_perma_filestash () {
#   docker cp filestash:/app/data/state $_SERVICESPATH/filestash/data/

#   chown -R 1000:1000 $_SERVICESPATH/filestash/data/

#   sed -i.bck '/state/s/^.*#//g' $_SERVICESPATH/filestash/docker-compose.filestash.yml
# }

function server_chyrp_lite_chk_fix () {
  # Create data directory if not exists
  _check_create_dir $_SERVICESPATH/chyrp-lite/data/

  # Create db.sqlite file if not exists
  _check_create $_SERVICESPATH/chyrp-lite/data/db.sqlite

  # Set correct permissions for data directory
  chown -R 33:33 $_SERVICESPATH/chyrp-lite/data/
  chmod -R 755 $_SERVICESPATH/chyrp-lite/data/

  # Create uploads directory if not exists
  _check_create_dir $_SERVICESPATH/chyrp-lite/uploads/

  # Set correct permissions for uploads directory
  chown -R 33:33 $_SERVICESPATH/chyrp-lite/uploads/
  chmod -R 755 $_SERVICESPATH/chyrp-lite/uploads/
}

function server_vikunja_chk_fix () {
  # Set correct permissions for data directory
  chown -R 1000 $_SERVICESPATH/vikunja/data/
}

function server_nanobot_chk_fix () {
  # Create data/exchange directories if not exists
  _check_create_dir $_SERVICESPATH/agents/kai/data/
  _check_create_dir $_SERVICESPATH/agents/kai/exchange/

  # Containers run as non-root UID/GID 1000
  chown -R 1000:1000 $_SERVICESPATH/agents/kai/data/
  chown -R 1000:1000 $_SERVICESPATH/agents/kai/exchange/
}


## Server functions
function server_up () {
  # Create shadow file if not exists
  _check_create $_SCRIPTPATH/.shadow

  # Create required files if they don't exist
  _check_create $_SERVICESPATH/traefik/acme.json
  _check_create $_SERVICESPATH/simply-shorten/urls.sqlite
  _check_create $_SERVICESPATH/fireflyiii/db.sqlite

  # Set correct traefik acme.json permissions
  chmod 600 $_SERVICESPATH/traefik/acme.json

  # Check and set correct permissions for chyrp-lite
  server_chyrp_lite_chk_fix

  # Check and set correct permissions for vikunja
  server_vikunja_chk_fix

  # Check and set correct permissions for nanobot
  server_nanobot_chk_fix

  # Start services
  _srv_docker_compose up -d
}

function server_down () {
  _srv_docker_compose down --remove-orphans
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
  declare -a _storage_dirs=("sshfs/vault" "sshfs/other" "gocryptfs/generic" "gocryptfs/immich")
  for i in "${_storage_dirs[@]}"
  do
    _check_create_dir "$_SCRIPTPATH/storage/mount/$i"
  done
}

function server_set_storage_permissions () {
  # _chown_storage $_SERVICESPATH/pydio/data/ || true
  _chown_storage $_SERVICESPATH/syncthing/data/ || true

  _chown_storage ${STORAGE_SSH_MOUNT_VAULT:-${SERVER_PATH}/storage/mount/sshfs/vault} || true
  _chown_storage ${STORAGE_SSH_MOUNT_OTHER:-${SERVER_PATH}/storage/mount/sshfs/other} || true

  # _chown_storage ${STORAGE_SSH_MOUNT_VAULT:-${SERVER_PATH}/storage/mount/sshfs/vault}/gocryptfs/generic.crypt
  # _chown_storage ${STORAGE_SSH_MOUNT_VAULT:-${SERVER_PATH}/storage/mount/sshfs/vault}/gocryptfs/immich.crypt
  _chown_storage ${STORAGE_GOCRYPTFS_MOUNT_GENERIC:-${SERVER_PATH}/storage/mount/gocryptfs/generic} || true
  _chown_storage ${STORAGE_GOCRYPTFS_MOUNT_IMMICH:-${SERVER_PATH}/storage/mount/gocryptfs/immich} || true
}

function server_init () {
  server_init_config

  gen_server_env
  load_env

  gen_traefik_config
  gen_homepage_config
  gen_server_services
  gen_searxng_config

  server_install_services

  server_storage_dir
  server_set_storage_permissions
}
