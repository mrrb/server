# server

Configuration for VPS1

## Get all the enviroment variables

```
./env.py $(find . -type f ! -path "./refs/*" -name 'docker-compose.*.yml') > .env.default
```

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
