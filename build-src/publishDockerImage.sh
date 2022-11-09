#!/bin/bash

. /srv/githubCommon.sh

# Templates each tag with required Docker build tag parameter
#
# $1: tags_str: whitespace delimited list with tags
# $2: image_name: docker image name to use in parameter
# $3: is_release: is release flag
function decorateTags {
  local tags_str=${1}
  local image_name=${2}
  local is_release=${3}
  local decorated=''
  for tag in ${INPUT_TAGS}; do
    tag=${tag//\`}
    tag=${tag//,}
    decorated="${decorated} -t ${image_name}:${tag//}"
  done
  [[ "${is_release}" == 'true' ]] && decorated="${decorated}"
  echo ${decorated}
}

echo 'Running dockerd magic to have a DIND image'
dockerd-entrypoint.sh &
sleep 20

if [[ ${INPUT_BUILD_ID} =~ ^v[0-9]{2}.[0-9]{2}(.[0-9]{1,2})?$ ]]; then
  is_release=true
else
  is_release=false
fi

# Creates and sets source folder
src_folder=/build/src
core_folder=${src_folder}/core
mkdir -p ${src_folder}

# Configs git with default user
executeCmd "gitConfig ${GITHUB_USER}"
# Clones core
build_from=COMMIT
[[ "${is_release}" == 'true' ]] && export GIT_TAG=${INPUT_BUILD_ID} && build_from=TAG
gitCloneSubModules $(resolveRepoUrl ${CORE_GITHUB_REPO} ${INPUT_GITHUB_USER_TOKEN} ${GITHUB_USER}) ${INPUT_BUILD_ID} ${core_folder}
[[ "${is_release}" == 'true' ]] && export GIT_TAG=

# Print docker version
echo "Docker version" && docker --version

# Docker login
executeCmd "echo ${INPUT_DOCKER_HUB_TOKEN} | docker login --username ${INPUT_DOCKER_HUB_USERNAME} --password-stdin"

# Git clones docker repo with provided branch
core_docker_path=${core_folder}/docker/dotcms
# Git clones docker repo with provided branch if
pushd ${core_docker_path}

docker_image_name=dotcms
[[ "${INPUT_DRY_RUN}" == 'true' ]] && docker_image_name="${docker_image_name}-cicd-test"
docker_image_full_name="dotcms/${docker_image_name}"

# Resolve decorated tags
tag_params=$(decorateTags "${tags}" "${docker_image_full_name}" ${is_release})

# Evaluate multi-arch flag
if [[ "${INPUT_MULTI_ARCH}" == 'true' ]]; then
  # Install Docker's buildx feature
  export DOCKER_BUILDKIT=1
  executeCmd "docker build --platform=local -o . https://github.com/docker/buildx.git"
  executeCmd "mkdir -p ~/.docker/cli-plugins"
  executeCmd "mv buildx ~/.docker/cli-plugins/docker-buildx"

  # Prepare for building
  uname -sm
  executeCmd "docker run --rm --privileged linuxkit/binfmt:v0.8"
  executeCmd "ls -1 /proc/sys/fs/binfmt_misc/qemu-*"

  # Create multi-arch
  echo 'Creating multi-arch Docker images'
  executeCmd "docker buildx create --use --name multiarch"
  executeCmd "docker buildx inspect --bootstrap"

  # Build docker build command
  docker_build_cmd="docker buildx build
    --platform linux/amd64,linux/arm64
    --pull
    --push
    --no-cache
    --build-arg BUILD_FROM=${build_from}
    --build-arg BUILD_ID=${INPUT_BUILD_ID}
    ${tag_params}
    ."
  # Actual multi-arch build
  time executeCmd "${docker_build_cmd}"
  [[ ${cmdResult} != 0 ]] && exit 1
else
  docker_build_cmd="docker build
    --build-arg BUILD_FROM=${build_from}
    --build-arg BUILD_ID=${INPUT_BUILD_ID}
    ${tag_params}
    ."
  # Actual build
  time executeCmd "${docker_build_cmd}"
  [[ ${cmdResult} != 0 ]] && exit 1

  # Actual push
  time executeCmd "docker push ${tags}"
  [[ ${cmdResult} != 0 ]] && exit 1
fi
