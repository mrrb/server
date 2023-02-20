# server

Base server configuration for all the VPSs/servers

## Get all the enviroment variables

```
./env.py $(find . -type f ! -path "./refs/*" -name 'docker-compose.*.yml') > .env.default
```

## Configuration

List of files or folders to configure the system

* __**.env**__. Custom environment file. [.env.default](.env.default) contains the default one.
* __**homepage/config**__. Homepage dashboard configuration files [(./homepage/config)](homepage/config).
* __**traefik/dynamic**__. Traefik dynamic configuration files [(./traefik/dynamic)](traefik/dynamic).
* __**nginx/conf**__. Nginx config files [(./nginx/conf)](nginx/conf).
