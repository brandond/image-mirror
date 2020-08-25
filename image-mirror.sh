#!/bin/bash

set -euo pipefail
export DOCKER_CLI_EXPERIMENTAL=enabled

DEST_ORG_OVERRIDE="${1:-}"
ARCH_LIST="amd64 arm64 arm"
MIRROR_LIST_URL="https://raw.githubusercontent.com/rancher/image-mirror/master/images-list"
IMAGE_LIST=$(curl -sL ${MIRROR_LIST_URL})

while IFS= read -r ENTRY; do
  read SOURCE_SPEC DEST_SPEC TAG <<< ${ENTRY}

  # ensure that source specifies an explicit registry and repository
  IFS=/ read -a SOURCE <<< "${SOURCE_SPEC}"
  if grep -vqE '[.:]|localhost' <<< ${SOURCE[0]}; then
    SOURCE=("docker.io" "${SOURCE[@]}")
  fi

  # recombine source spec
  printf -v SOURCE "/%s" "${SOURCE[@]}"; SOURCE=${SOURCE:1}

  # ensure that dest specifies an explicit registry and repository
  IFS=/ read -a DEST <<< "${DEST_SPEC}"
  if grep -vqE '[.:]|localhost' <<< ${DEST[0]}; then
    DEST=("docker.io" "${DEST[@]}")
  fi

  # override destination org/user if set
  if [ ! -z "${DEST_ORG_OVERRIDE}" ]; then
    DEST[1]="${DEST_ORG_OVERRIDE}"
  fi

  # recombine dest spec
  printf -v DEST "/%s" "${DEST[@]}"; DEST=${DEST:1}

  # Grab raw manifest or manifest list and extract schema info
  MANIFEST=$(skopeo inspect docker://${SOURCE}:${TAG} --raw)
  SCHEMAVERSION=$(jq -r '.schemaVersion' <<< ${MANIFEST})
  MEDIATYPE=$(jq -r '.mediaType' <<< ${MANIFEST})
  
  if [ "${SCHEMAVERSION}" == "2" ]; then

    # Handle manifest lists by copying all the architectures (and their variants) out to individual suffixed tags in the destination,
    # then recombining them into a single manifest list on the bare tags.
    if [ "${MEDIATYPE}" == "application/vnd.docker.distribution.manifest.list.v2+json" ]; then
      echo "${SOURCE}:${TAG} is manifest.list.v2"
      DOCKER_FLAGS=""
      for ARCH in ${ARCH_LIST}; do
        DIGEST_VARIANT_LIST=$(jq -r ".manifests | map(select(.platform.architecture == \"${ARCH}\")) | map(.digest + \" \" + .platform.variant)" <<< ${MANIFEST});
        while read DIGEST VARIANT; do 
          # Add skopeo flags for multi-variant architectures (arm, mostly)
          if [ -z "${VARIANT}" ] || [ "${VARIANT}" == "null" ]; then
            VARIANT=""
            SKOPEO_FLAGS=""
          else
            SKOPEO_FLAGS="--override-variant=${VARIANT}"
          fi

          if [ -z "${DIGEST}" ] || [ "${DIGEST}" == "null" ]; then
            echo -e "\t${ARCH} NOT FOUND"
          else
            echo -e "\tCopying ${SOURCE}@${DIGEST} => ${DEST}:${TAG}-${ARCH}${VARIANT}"
            skopeo copy --override-arch=${ARCH} ${SKOPEO_FLAGS} "docker://${SOURCE}@${DIGEST}" "docker://${DEST}:${TAG}-${ARCH}${VARIANT}"
            echo -e "\tAdding ${DEST}:${TAG}-${ARCH}${VARIANT} => ${DEST}:${TAG}"
            docker buildx imagetools create ${DOCKER_FLAGS} --tag "${DEST}:${TAG}" "${DEST}:${TAG}-${ARCH}${VARIANT}"
            DOCKER_FLAGS="--append"
          fi
        done <<< ${DIGEST_VARIANT_LIST}
      done

    # Standalone manifests don't include architecture info, we have to get that from the image config
    elif [ "${MEDIATYPE}" == "application/vnd.docker.distribution.manifest.v2+json" ]; then
      echo "${SOURCE}:${TAG} is manifest.v2"
      CONFIG=$(skopeo inspect docker://${SOURCE}:${TAG} --config --raw)
      ARCH=$(jq -r '.architecture' <<< ${CONFIG})
      DIGEST=$(jq -r '.config.digest' <<< ${MANIFEST})
      if grep -wqF ${ARCH} <<< ${ARCH_LIST}; then
        echo -e "\tCopying ${SOURCE}:${TAG} => ${DEST}:${TAG}-${ARCH}"
        skopeo copy --override-arch ${ARCH} docker://${SOURCE}:${TAG} docker://${DEST}:${TAG}-${ARCH}
        echo -e "\tAdding ${DEST}:${TAG}-${ARCH} => ${DEST}:${TAG}"
        docker buildx imagetools create --tag ${DEST}:${TAG} ${DEST}:${TAG}-${ARCH}
      fi
    else 
      echo "${SOURCE}:${TAG} has unknown mediaType ${MEDIATYPE}"
    fi

  # v1 manifests contain arch but no variant, but can be treated similar to manifest.v2
  elif [ "${SCHEMAVERSION}" == "1" ]; then
    echo "${SOURCE}:${TAG} is manifest.v1"
    ARCH=$(jq -r '.architecture' <<< ${MANIFEST})
    if grep -wqF ${ARCH} <<< ${ARCH_LIST}; then
      echo -e "\tCopying ${SOURCE}:${TAG} => ${DEST}:${TAG}-${ARCH}"
      skopeo copy --override-arch ${ARCH} docker://${SOURCE}:${TAG} docker://${DEST}:${TAG}-${ARCH}
      echo -e "\tAdding ${DEST}:${TAG}-${ARCH} => ${DEST}:${TAG}"
      docker buildx imagetools create --tag ${DEST}:${TAG} ${DEST}:${TAG}-${ARCH}
    fi
  else
    echo "${SOURCE}:${TAG} has unknown schemaVersion ${SCHEMAVERSION}"
  fi

done <<< ${IMAGE_LIST}
