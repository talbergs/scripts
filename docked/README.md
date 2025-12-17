### Dockerized utilities.

> Should be portable.

```sh
SCRIPT_NAME=i18n-diff
docker build --tag $SCRIPT_NAME:latest --file ./$SCRIPT_NAME.sh.Dockerfile
docker run $SCRIPT_NAME:latest
```
