# server

Configuration for VPS1

## Get all the enviroment variables

```
source server.sh && gen_server_default_env
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

* __**.env**__. Custom environment file. [.env.default](.env.default) contains the default one.
* __**homepage/config**__. Homepage dashboard configuration files [(./homepage/config)](homepage/config).
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
* [YOURLS](yourls)
  * [go.mrrb.eu](https://go.mrrb.eu) 

## First start steps

0. Prerequisites
   * Docker should be installed and running on the host machine.
   * Root permissions required.
1. Go to `/srv/` directory.
2. Download repo (`sudo git clone https://github.com/mrrb/server.git`), add `--recursive` to download reference repos. CD into it `cd /srv/server/`.
3. Checkout to VPS1 branch `sudo git checkout vps1`.
4. Create the `.shadow` file `touch .shadow` and add into it all the required users.
   * Gen hased user:password strings with `htpasswd -nb USER PASSWORD`.
   * It should include the user `homepage` to integrate traefik into homepage.
5. Edit the environment file (`.env`) as requiered.
   * `HOMEPAGE_TRAEFIK_PASSWORD` and `HOMEPAGE_TRAEFIK_USERNAME` should match the password and user generated previously.
   * Set `YOURLS_USER` and `YOURLS_PASS`.
   * `HOMEPAGE_PORTAINER_KEY` can be ignored for the moment.
6. Gen homepage config files `sudo sh -c 'source /srv/server/server.sh && gen_homepage_config'`.
7. Copy the SystemD service `sudo cp server.service /usr/lib/systemd/system/server.service` and enable it `sudo systemctl enable --now server.service`.
8. Check that everything works.
9.  Go to the portainer page and set it up.
    * Gen a KEY and save it into the environment file (`HOMEPAGE_PORTAINER_KEY`).
10. Enjoy 😉.
