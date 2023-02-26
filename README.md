# server

Base server configuration for all the VPSs/servers

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

* __**.env**__. Environment file.
  * [.env](). Environment used by the server.
  * [.env.default](.env.default). Default environment.
  * [env.json](env.json). JSON with the default variables, used to generate the `.env` file(s) with `gen_server_env` or `gen_server_default_env`
  * [env.extra.json](). Untracked JSON with extra variables. Useful for a custom configuration on the server.* __**homepage/config**__. Homepage dashboard configuration files [(./homepage/config)](homepage/config).
* __**.shadow**__. File where the hashed passwords are stored.
* __**traefik/dynamic**__. Traefik dynamic configuration files [(./traefik/dynamic)](traefik/dynamic).
* __**nginx/conf**__. Nginx config files [(./nginx/conf)](nginx/conf).
