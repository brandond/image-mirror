#!/usr/bin/bash

set -euo pipefail

if [ ! -z "${DOCKER_USERNAME:-}" ] && [ ! -z "${DOCKER_PASSWORD:-}" ]; then
  echo "Logging in to ${DOCKER_REGISTRY:-docker.io} as ${DOCKER_USERNAME}"
  docker login ${DOCKER_REGISTRY:-docker.io} --username=${DOCKER_USERNAME} --password-stdin <<< ${DOCKER_PASSWORD}
fi

exec /image-mirror.sh $@
