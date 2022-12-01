usage() {
  # t for tag
  echo "Usage: $0  -t <docker tag>" 1>&2
  echo ""
  echo "Optional flags:" 1>&2
  # m for local image
  echo "[-m <local docker image>] (default rmi_pacta)" 1>&2
  # r for registry
  echo "[-r <container registry>] (default transitionmonitordockerregistry.azurecr.io)" 1>&2
  # i for image
  echo "[-i <remote image>] (default <same as image defined by -m>)" 1>&2
  # o for remote tag
  echo "[-o <remote tag>] (default <same a tag defined by -t>)" 1>&2
  # v for verbose
  echo "[-d] (dry-run, tag only, no push)" 1>&2
  echo "[-v] (verbose mode)" 1>&2
  exit 1;
}


while getopts m:t:r:o:i:dv flag
do
  case "${flag}" in
    t) tag=${OPTARG};;
    m) docker_image=${OPTARG};;
    r) registry=${OPTARG};;
    i) remote_image=${OPTARG};;
    o) remote_tag=${OPTARG};;
    d) dry_run=1;;
    v) verbose=1;;
    *) usage;;
  esac
done

if [ -z "${tag}" ]; then
  usage
fi

if [ -z "${docker_image}" ]; then
  docker_image="rmi_pacta"
fi

if [ -z "${registry}" ]; then
  registry="transitionmonitordockerregistry.azurecr.io"
fi

if [ -z "${remote_image}" ]; then
  remote_image="$docker_image"
fi

if [ -z "${remote_tag}" ]; then
  remote_tag="$tag"
fi



old_tag="$docker_image":"$tag"
new_tag="$registry"/"$remote_image":"$remote_tag"
if [ -n "${verbose}" ]; then
  echo ""
  echo "Current Image: $old_tag"
  echo "Tagging as $new_tag"
fi

docker tag "$old_tag" "$new_tag"

if [ -z "${dry_run}" ]; then
  if [ -n "${verbose}" ]; then
    az acr login --name $registry
    echo ""
    echo "Pushing $new_tag"
    echo ""
  fi
  docker push "$new_tag"
fi
