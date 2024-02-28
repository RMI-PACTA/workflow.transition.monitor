#! /bin/sh

# This script uses hardcoded parameters to define the versions for pacta data
# and templates.transition.monitor. make changes to this script and commit
# prior to running, so that the SHA tag that is pushed to registry is capable
# of tracking the inputs.
if [ -z "$(git status --porcelain)" ]; then 
  echo "Git status is clean. Proceeding."
else 
  echo "Commit changes to this script prior to running."
  exit 1
fi

pacta_data_share_url="https://pactadatadev.file.core.windows.net/workflow-data-preparation-outputs"
pacta_data_share_path="2023Q4_20240218T231047Z"
holdings_date="2023Q4"

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

# check if az cli is installed
az_cmd="$(command -v az)"
if [ -z "${az_cmd}" ]; then
  echo "Azure CLI not found. Please install it and try again."
  exit 1
fi

# check if logged in to az
az_account="$(az account show -o json)"
if [ -z "${az_account}" ]; then
  echo "Please login to Azure using 'az login' and try again."
  exit 1
fi

az acr login --name transitionmonitordockerregistry

git clone -b "$templates_branch" "$templates_remote" --depth 1 "$dir_temp/templates.transition.monitor"|| exit 2

# exclude sqlite files from download
az storage copy -s "$pacta_data_share_url"/"$pacta_data_share_path/*"  -d "$dir_temp/pacta-data/$holdings_date" --recursive --exclude-pattern "*.sqlite"

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
