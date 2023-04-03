# server

Configuration for VPS1

## Gen the default enviroment file

`.env.default` file.

```
source server.sh && gen_server_default_env
```

## Gen the enviroment file

`.env` file.

```
source server.sh && gen_server_env
```

## Gen the homepage configuration

```
source server.sh && gen_homepage_config
```

## Gen the server SystemD service, timers and mounts

```
source server.sh && gen_server_services
```

## Install all the SystemD files

```
source server.sh && server_install_services
```

## Create the initial config files

```
source server.sh && server_init_config
```

## Init the server

* [server_init_config](#create-the-initial-config-files)
* [gen_server_env](#gen-the-enviroment-file)
* [gen_homepage_config](#gen-the-homepage-configuration)
* [gen_server_services](#gen-the-server-systemd-service-timers-and-mounts)
* [server_install_services]()
<!-- * [server_install_services](#install-all-the-systemd-files) -->

```
source server.sh && server_init
```

## Start server

```
source server.sh && server_up
```

## Stop server

```
source server.sh && server_down
```

## Configuration

List of files or folders to configure the system

* __**.env**__. Environment file.
  * [.env](). Environment used by the server.
  * [.env.default](.env.default). Default environment.
  * [env.json](env.json). JSON with the default variables, used to generate the `.env` file(s) with `gen_server_env` or `gen_server_default_env`
  * [env.extra.json](). Untracked JSON with extra variables. Useful for a custom configuration on the server.
* __**homepage/config**__. Homepage dashboard configuration files [(./homepage/config)](homepage/config).
* __**.shadow**__. File where the hashed passwords are stored.
* __**traefik/dynamic**__. Traefik dynamic configuration files [(./traefik/dynamic)](traefik/dynamic).
* __**nginx/conf**__. Nginx config files [(./nginx/conf)](nginx/conf).

## Services hosted on VPS1

* [Traefik](traefik)
  * [traefik.vps1.infra.mrrb.xyz](https://traefik.vps1.infra.mrrb.xyz)
* [Portainer](portainer)
  * [portainer.vps1.infra.mrrb.xyz](https://portainer.vps1.infra.mrrb.xyz)
  * [edge.vps1.infra.mrrb.xyz](https://edge.vps1.infra.mrrb.xyz)
* [Whoami](whoami)
  * [whoami.vps1.infra.mrrb.xyz](https://whoami.vps1.infra.mrrb.xyz)
* [WatchTower](watchtower)
* [Homepage](homepage)
  * [dashboard.vps1.infra.mrrb.xyz](https://dashboard.vps1.infra.mrrb.xyz)
* [Nginx](nginx)
  * [vps1.infra.mrrb.xyz](https://vps1.infra.mrrb.xyz)
* [Nginx (mrrb.eu)](nginx_mrrb_eu)
  * [mrrb.eu](https://mrrb.eu) 
* [simply-shorten](simply-shorten)
  * [go.mrrb.eu](https://go.mrrb.eu) 
* [Firefly III](fireflyiii)
  * [finance.mrrb.eu](https://finance.mrrb.eu) 
* [Kanboard](kanboard)
  * [kanban.mrrb.eu](https://kanban.mrrb.eu) 
<!-- * [Authentik](authentik)
  * [auth.mrrb.eu](https://auth.mrrb.eu)  -->

## First start steps

If using Hetzner storage, the required box structure must be already created. Check [storage/README.md](storage/README.md) for more info.

1. Prerequisites
    * Docker should be installed and running on the host machine.
    * `sshfs` and `gocryptfs` should be installed on the machine.
    * Root permissions required.
2. Go to `/srv/` directory.
3. Download repo (`sudo git clone https://github.com/mrrb/server.git`). CD into it `cd /srv/server/`.
4. JIC `sudo git submodule update --init --recursive` and `cd refs/server-private && sudo git lfs install && sudo git lfs fetch && sudo git lfs checkout && cd ../..`.
5. Checkout to VPS1 branch `sudo git checkout vps1`.
6. Create the `.shadow` file `sudo touch .shadow` (or `sudo sh -c 'source /srv/server/server.sh && server_init_config'`) and add into it all the required users.
    * Gen hased user:password strings with `htpasswd -nb USER PASSWORD`.
    * It should include the user `homepage` to integrate traefik into homepage.
7. Create the custom environment JSON file `sudo touch env.extra.json` (or `sudo sh -c 'source /srv/server/server.sh && server_init_config'`) and add the following fields.
    * `HOMEPAGE_TRAEFIK_PASSWORD` and `HOMEPAGE_TRAEFIK_USERNAME` should match the password and user generated previously.
    * `HOMEPAGE_PORTAINER_KEY` can be defined but ignored for the moment.
    * Set `SIMPLYSHORTEN_USER` and `SIMPLYSHORTEN_PASS`.
    <!-- * Set `AUTHENTIK_POSTGRES_PASSWORD`. -->
    * Set API keys `FIREFLYIII_APP_KEY` and `FIREFLYIII_STATIC_CRON_TOKEN` (32 long strings).
    * Set mail vars `MAIL_ENCRYPTION`, `MAIL_FROM`, `MAIL_HOST`, `MAIL_PASSWORD`, `MAIL_PORT` and `MAIL_USERNAME`.
    * Set `STORAGE_SSH_HOST`, `STORAGE_SSH_USER_OTHER` and `STORAGE_SSH_USER_VAULT`.
8. Create a new SSH key pair for the storage box.
    * `sudo ssh-keygen -t ed25519 -C "VPS1-HetznerStorageBox" -f /srv/server/storage/.ssh/id_ed25519 -q -N ""`.
    * Convert public key to RFC4716 format: `sudo sh -c 'ssh-keygen -e -f /srv/server/storage/.ssh/id_ed25519.pub > /srv/server/storage/.ssh/id_ed25519_rfc.pub'`
9.  Add generated public key (`/srv/server/storage/.ssh/id_ed25519_rfc.pub`) to the Hetzner storage box `.ssh/authorized_keys` for the *vault* and *other* subaccounts, optionally, disable the *External reachability* function for the primary account. Check [storage/README.md](storage/README.md) for more info.
10. Init server files `sudo sh -c 'source /srv/server/server.sh && server_init'`. This will generate the environment file, fill some config files and generate and install all the services, timers and mounts.
11. Enable the required server service(s), timer(s) and mount(s).
    * `sudo systemctl enable server.service`.
    * `sudo systemctl enable server_sshfs_mount_other.service`.
    * `sudo systemctl enable server_sshfs_mount_vault.service`.
12. Reboot system and check that everything works.
13. Go to the portainer page and set it up.
    * Gen a KEY and save it into the `env.extra.json` file (`HOMEPAGE_PORTAINER_KEY`).
14.   Regenerate the environment file `sudo sh -c 'source /srv/server/server.sh && gen_server_env'`.
15.   Restart service `sudo systemctl restart server.service`.
16.   Enjoy 😉.
