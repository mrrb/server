# server

Configuration for VPS1

## Gen the default enviroment file (`.env.default`)

```
source server.sh && gen_server_default_env
```

## Gen the enviroment file (`.env`)

```
source server.sh && gen_server_env
```

## Gen the homepage configuration

```
source server.sh && gen_homepage_config
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
  * [env.extra.json](). Untracked JSON with extra variables. Useful for a custom configuration on the server.* __**homepage/config**__. Homepage dashboard configuration files [(./homepage/config)](homepage/config).
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
* [Shlink](shlink)
  * [go.mrrb.eu](https://go.mrrb.eu) 

## First start steps

0. Prerequisites
   * Docker should be installed and running on the host machine.
   * Root permissions required.
1. Go to `/srv/` directory.
2. Download repo (`sudo git clone https://github.com/mrrb/server.git`). CD into it `cd /srv/server/`.
3. JIC `sudo git submodule update --init --recursive`.
4. Checkout to VPS1 branch `sudo git checkout vps1`.
5. Create the `.shadow` file `sudo touch .shadow` and add into it all the required users.
   * Gen hased user:password strings with `htpasswd -nb USER PASSWORD`.
   * It should include the user `homepage` to integrate traefik into homepage.
6. Create the custom environment JSON file `sudo touch env.extra.json` and add the following fields.
   * `HOMEPAGE_TRAEFIK_PASSWORD` and `HOMEPAGE_TRAEFIK_USERNAME` should match the password and user generated previously.
   * `HOMEPAGE_PORTAINER_KEY` can be defined but ignored for the moment.
   * Set `SHLINK_MARIADB_PASSWORD`.
   * Set `SHLINK_GEOLITE_LICENSE_KEY` (from [maxmind.com](https://maxmind.com)).
7. Gen the environtment file `sudo sh -c 'source /srv/server/server.sh && gen_server_env'`
8. Gen homepage config files `sudo sh -c 'source /srv/server/server.sh && gen_homepage_config'`.
9. Copy the SystemD service `sudo cp server.service /usr/lib/systemd/system/server.service` and enable it `sudo systemctl enable --now server.service`.
10. Check that everything works.
11. Go to the portainer page and set it up.
    * Gen a KEY and save it into the `env.extra.json` file (`HOMEPAGE_PORTAINER_KEY`).
    * Regenerate the environment file `sudo sh -c 'source /srv/server/server.sh && gen_server_env'`.
    * Restart service `sudo systemctl restart server.service`.
12. Enjoy 😉.
