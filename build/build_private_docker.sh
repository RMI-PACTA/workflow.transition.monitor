#! /bin/sh

#requires being logged in to az

pacta_data_share_url="https://pactadatadev.file.core.windows.net/workflow-data-preparation-outputs"
pacta_data_share_path="2023Q4_20240218T231047Z"

templates_remote="git@github.com:RMI-PACTA/templates.transition.monitor.git"
templates_branch="main"

dir_temp="$(mktemp -d)"
echo "$dir_temp"

git clone -b "$templates_branch" "$templates_remote" --depth 1 "$dir_temp/templates.transition.monitor"|| exit 2

# exclude sqlite files from download
az storage copy -s "$pacta_data_share_url"/"$pacta_data_share_path"  -d "$dir_temp/pacta-data" --recursive --exclude-pattern "*.sqlite"

docker build -f Dockerfile.private -t rmi_pacta_private:latest "$dir_temp"
