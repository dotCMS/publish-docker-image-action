#!/bin/bash

###############################
# Script: publishDockerImage.sh
# Builds and publishes, with 'docker buildx' (when requested) commands, the multi-arch docker DotCMS images
#
# $1: dot_cicd_branch: pipeline branch
# $2: build_id: branch or commit
# $3: tags: Docker tags to use when building and pushing
# $4: multi_arch: multi-arch flag
# $5: github_user_token: github user token
# $6: docker_hub_username: docker hub username
# $7: docker_hub_token: docker hub token
# $8: dry_run: dry-run flag

echo "===========================
publish-docker-image-action
===========================
dot_cicd_branch: ${INPUT_DOT_CICD_BRANCH}
build_id: ${INPUT_BUILD_ID}
tags: ${INPUT_TAGS}
multi_arch: ${INPUT_MULTI_ARCH}
github_user_token: ${INPUT_GITHUB_USER_TOKEN}
docker_hub_username: ${INPUT_DOCKER_HUB_USERNAME}
docker_hub_token: ${INPUT_DOCKER_HUB_TOKEN}
dry_run: ${INPUT_DRY_RUN}
"

# Fetches githubCommon.sh script with required variables and functions
curl -fsSL \
  https://raw.githubusercontent.com/dotCMS/dot-cicd/${INPUT_DOT_CICD_BRANCH}/pipeline/github/githubCommon.sh \
  --output /srv/githubCommon.sh

# Call man logic
. /srv/publishDockerImage.sh

result=$?
echo "OJO:>> Result: ${result}"
[[ ${result} != 0 ]] && exit 1
