# server

Base server configuration for all the VPSs/servers

## Get all the enviroment variables

```
grep '${' **/docker-compose.*.yml | grep -v 'refs' | sed "s/.*\${\(.*\)}.*/\1/g" | cut -d":" -f 1 | sort -u | sort | xargs -I % echo "%=" >> .env.default
```

##

