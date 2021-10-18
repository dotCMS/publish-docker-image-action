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
  for tag in ${INPUT_TAGS//\`}; do
    decorated="${decorated} -t ${image_name}:${tag//}"
  done
  [[ "${is_release}" == 'true' ]] && decorated="${decorated} -t ${image_name}:latest"
  echo ${decorated}
}

echo 'Running dockerd magic to have a DIND image'
dockerd-entrypoint.sh &
sleep 20

if [[ ${INPUT_BUILD_IS} =~ ^v[0-9]{2}.[0-9]{2}(.[0-9]{1,2})?$ ]]; then
  is_release=true
else
  is_release=false
fi

# Creates and sets source folder
src_folder=/build/src
core_folder=${src_folder}/core
mkdir -p ${src_folder}

# Configs git with default user
gitConfig ${GITHUB_USER}
# Clones core
gitClone $(resolveRepoUrl ${CORE_GITHUB_REPO} ${INPUT_GITHUB_USER_TOKEN} ${GITHUB_USER}) ${INPUT_BUILD_ID} ${core_folder}

# Print docker version
echo "Docker version" && docker --version

# Docker login
echo "Executing: echo ${INPUT_DOCKER_HUB_TOKEN} | docker login --username ${INPUT_DOCKER_HUB_USERNAME} --password-stdin"
echo ${INPUT_DOCKER_HUB_TOKEN} \
  | docker login --username ${INPUT_DOCKER_HUB_USERNAME} --password-stdin

# Git clones docker repo with provided branch
core_docker_path=${core_folder}/docker/dotcms
# Resolve which docker path to use (core or docker repo folder)
resolved_docker_path=$(dockerPathWithFallback ${core_docker_path} docker)
# Git clones docker repo with provided branch if
if [[ "${resolved_docker_path}" == 'docker' ]]; then
  docker_folder=${src_folder}/docker
  fetchDocker ${docker_folder} master
  pushd ${docker_folder}/images/dotcms
else
  pushd ${core_docker_path}
fi

docker_image_name=dotcms
[[ "${INPUT_DRY_RUN}" == 'true' ]] && docker_image_name="${docker_image_name}-cicd-test"
docker_image_full_name="dotcms/${docker_image_name}"

# Resolve decorated tags
tag_params=$(decorateTags "${tags}" "${docker_image_full_name}" ${is_release})

# Evaluate multi-arch flag
if [[ "${INPUT_MULTI_ARCH}" == 'true' ]]; then
  # Install Docker's buildx feature
  export DOCKER_BUILDKIT=1
  docker build --platform=local -o . git://github.com/docker/buildx
  mkdir -p ~/.docker/cli-plugins
  mv buildx ~/.docker/cli-plugins/docker-buildx

  # Prepare for building
  uname -sm
  docker run --rm --privileged linuxkit/binfmt:v0.8
  ls -1 /proc/sys/fs/binfmt_misc/qemu-*

  # Create multi-arch
  echo 'Creating multi-arch Docker images'
  echo 'Executing: docker buildx create --use --name multiarch'
  docker buildx create --use --name multiarch
  docker buildx inspect --bootstrap

  # Build docker build command
  docker_build_cmd="docker buildx build
    --platform linux/amd64,linux/arm64
    --pull
    --push
    --no-cache
    --build-arg BUILD_FROM=COMMIT
    --build-arg BUILD_ID=${INPUT_BUILD_ID}
    ${tag_params}
    ."
  # Actual multi-arch build
  time executeCmd "${docker_build_cmd}"
else
  docker_build_cmd="docker build
    --build-arg BUILD_FROM=COMMIT
    --build-arg BUILD_ID=${INPUT_BUILD_ID}
    ${tag_params}
    ."
  # Actual build
  time executeCmd "${docker_build_cmd}"

  # Actual push
  time executeCmd "docker push ${tags}"
fi


