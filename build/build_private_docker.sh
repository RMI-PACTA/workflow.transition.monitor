#! /bin/sh

#requires being logged in to az
az acr login --name transitionmonitordockerregistry

pacta_data_share_url="https://pactadatadev.file.core.windows.net/workflow-data-preparation-outputs"
pacta_data_share_path="2023Q4_20240218T231047Z"

templates_remote="git@github.com:RMI-PACTA/templates.transition.monitor.git"
templates_branch="main"

registry="transitionmonitordockerregistry.azurecr.io"
remote_image="rmi_pacta_2023q4_pa2024ch"
remote_tag="$(git rev-parse HEAD)"

dir_temp="$(mktemp -d)"
echo "$dir_temp"

docker_image="rmi_pacta_private"
tag="latest"
local_tag="$docker_image":"$tag"

git clone -b "$templates_branch" "$templates_remote" --depth 1 "$dir_temp/templates.transition.monitor"|| exit 2

# exclude sqlite files from download
az storage copy -s "$pacta_data_share_url"/"$pacta_data_share_path"  -d "$dir_temp/pacta-data" --recursive --exclude-pattern "*.sqlite"

docker build -f Dockerfile.private -t "$local_tag" "$dir_temp"

new_tag="$registry"/"$remote_image":"$remote_tag"

echo "Tagging $local_tag as $new_tag"
docker tag "$local_tag" "$new_tag"

docker push "$new_tag"

remote_tag="latest"
new_tag="$registry"/"$remote_image":"$remote_tag"
echo "Tagging $local_tag as $new_tag"
docker tag "$local_tag" "$new_tag"
docker push "$new_tag"

echo "Docker images uploaded to $registry"
