A relatively simple script to mirror images from one Docker registry to another.
* Uses `skopeo inspect` to retrieve image metadata, and `skopeo copy` to push images between registries without pulling locally.
* Uses `docker buildx imagetools create` to create manifest lists from copied images. 

Additional Features
===
* Defaults to pushing to whatever org is specified in the image list. Can override the destination org by passing desired org as first argument.
* If run with Dapper, will login to `$DOCKER_REGISTRY` (default: docker.io) using `$DOCKER_USERNAME` and `$DOCKER PASSWORD`.
