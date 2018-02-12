# docker daemon 2375 proxy

```
docker run -d -p 2375:2375 -v /var/run/docker.sock:/var/run/docker.sock containerize/docker-proxy
```