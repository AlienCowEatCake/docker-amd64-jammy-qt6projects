# docker-amd64-jammy-qt6projects
Dockerfile for Ubuntu 22.04 build environment for Qt 6.x projects

## Build

```bash
docker build --platform linux/amd64 -t aliencoweatcake/amd64-jammy-qt6projects:qt6.9.2 .
docker build --platform linux/arm64 -t aliencoweatcake/arm64-jammy-qt6projects:qt6.9.2 .
```

## Docker Hub

* https://hub.docker.com/r/aliencoweatcake/amd64-jammy-qt6projects
* https://hub.docker.com/r/aliencoweatcake/arm64-jammy-qt6projects
