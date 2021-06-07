# Publish Docker Image Action
Docker based action to run a Docker image build and eventually publish it.

## Usage
```yaml
- name: Publish docker image
  id: publish-docker-image
  uses: dotcms/publish-docker-image-action@main
  with:
    dot_cicd_branch: master
    build_id: 12345-some-branch
    tags: ${{ steps.discover-docker-tags.discovered_tags }} # Might be something like [ 21.06.2_lts_a2b3e56d 21.06.2_lts 21.06_lts 21.06 ]
    multi_arch: true # Default is true
    github_user_token: ${{ secrets.CICD_GITHUB_TOKEN }}
    docker_hub_username: ${{ secrets.DOCKER_USERNAME }}
    docker_hub_token: ${{ secrets.DOCKER_TOKEN }}
    dry_run: ${{ github.event.inputs.dry_run }} # Default false
```
