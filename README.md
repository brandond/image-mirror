A relatively simple script to mirror images from one Docker registry to another.
* Uses `skopeo inspect` to retrieve image metadata, and `skopeo copy` to push images between registries without pulling locally.
* Uses `docker buildx imagetools create` to create manifest lists from copied images. 

Additional Features
---
* Defaults to pushing to whatever org is specified in the image list. Can override the destination org by running the script with the override org as the first argument.
* If run with Dapper, will login to `$DOCKER_REGISTRY` (default: docker.io) using `$DOCKER_USERNAME` and `$DOCKER PASSWORD`.

Usage
---
If you have `skopeo` and `docker buildx` available locally, you can just run `image-mirror.sh [<override-org>]`.

If you want to run in Docker, Dockerfile.dapper will handle creating an appropriate image to host the script. 
You can run `dapper [<override-org>]`, or if you don't have dapper `make .dapper; ./.dapper [<override-org>]`.
