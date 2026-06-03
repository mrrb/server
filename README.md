# server

Configuration for VPS2 (linux/amd64)

Based on [tomMoulard / make-my-server](https://github.com/tomMoulard/make-my-server)

## Functions

* Gen the default enviroment file -> `source server.sh && gen_server_default_env`
* Gen the enviroment file -> `source server.sh && gen_server_env`
* Gen the homepage configuration -> `source server.sh && gen_homepage_config`
* Gen the server SystemD service, timers and mounts -> `source server.sh && gen_server_services`
* Install all the SystemD files -> `source server.sh && server_install_services`
* Create the initial config files -> `source server.sh && server_init_config`
* Init the server -> `source server.sh && server_init`
* Start server -> `source server.sh && server_up`
* Stop server -> `source server.sh && server_down`

## Configuration

List of files or folders to configure the system

* __**.env**__. Environment file.
  * [.env](). Environment used by the server.
  * [.env.default](.env.default). Default environment.
  * [env.json](env.json). JSON with the default variables, used to generate the `.env` file(s) with `gen_server_env` or `gen_server_default_env`
  * [env.extra.json](). Untracked JSON with extra variables. Useful for a custom configuration on the server.
* __**services/homepage/config**__. Homepage dashboard configuration files [(./homepage/config)](homepage/config).
* __**.shadow**__. File where the hashed passwords are stored.
* __**services/traefik/dynamic**__. Traefik dynamic configuration files [(./traefik/dynamic)](traefik/dynamic).
* __**stuff/docker-daemon.json**__. Reference Docker daemon config (log rotation caps, ip6tables for IPv6 container support). Copy/edit to `/etc/docker/daemon.json` on the host and `sudo systemctl restart docker` to apply. See [stuff/README.md](stuff/README.md).

## Hosted services

Check [services/README.md](services/README.md) for the complete list.

## First start steps

1. Prerequisites
    * Docker (with docker compose) should be installed and running on the host machine.
    * `git`, `git-lfs` and `sudo` should be installed on the machine.
    * Root permissions required.
    * Ports 80 and 443 accessible. UFW example, `sudo ufw allow "WWW full" && sudo ufw allow 443/udp && sudo ufw allow 51820/udp && sudo ufw enable && sudo ufw status`.
1. Apply Docker daemon config. Check [stuff/README.md](stuff/README.md).
    * Required for log rotation and IPv6 support (`ip6tables`) in containers.
1. Go to `/srv/` directory.
1. Download repo (`sudo git clone git@github.com:mrrb/server.git --recursive`). CD into it `cd /srv/server/`.
1. Checkout to VPS2 branch `sudo git checkout vps2`.
1. JIC `sudo git submodule update --init --recursive`.
1. Create the `.shadow` file `sudo touch .shadow` (or `sudo bash -c 'source /srv/server/server.sh && server_init_config'`) and add into it all the required users.
    * Gen hased user:password strings with `htpasswd -nb USER PASSWORD`.
    * It should include the user `admin`.
    * It should include the user `homepage` to integrate traefik into homepage.
1. Create the custom environment JSON file `sudo touch env.extra.json` (or `sudo bash -c 'source /srv/server/server.sh && server_init_config'`) and add the following fields.
    * `HOMEPAGE_TRAEFIK_PASSWORD` and `HOMEPAGE_TRAEFIK_USERNAME` should match the password and user generated previously.
    * `HOMEPAGE_PORTAINER_KEY` can be defined but ignored for the moment.
    * Set mail vars `MAIL_ENCRYPTION`, `MAIL_FROM`, `MAIL_HOST`, `MAIL_PASSWORD`, `MAIL_PORT` and `MAIL_USERNAME`.
    * Set, if needed, `PLATFORM_ARCH` (Ex. 'linux/amd64' or 'linux/arm64')
1. Init server files `sudo bash -c 'source /srv/server/server.sh && server_init'`. This will generate the environment file, fill some config files and generate and install all the services, timers and mounts.
   <!-- 1. Allow grpc port in firewall. UFW example, `sudo ufw allow 33060/tcp && sudo ufw enable && sudo ufw status` -->
1. Enable the required server service(s), timer(s) and mount(s).
    * `sudo systemctl enable server.service`.
1. Reboot system and check that everything works.
1. Go to the portainer page and set it up.
    * Gen a KEY and save it into the `env.extra.json` file (`HOMEPAGE_PORTAINER_KEY`).
1. Regenerate the environment file `sudo bash -c 'source /srv/server/server.sh && gen_server_env'`.
1. Restart service `sudo systemctl restart server.service`.
1. Enjoy :)
