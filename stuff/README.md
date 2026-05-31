# Random

## Files

* [docker-daemon.json](docker-daemon.json). Reference Docker daemon
  configuration. Caps container log files at 10 MB × 3 to keep `json-file`
  logs from filling the disk. Copy/edit `/etc/docker/daemon.json` on the host
  and `sudo systemctl restart docker` to apply.
