#! /bin/bash

# Examples:
# # The tag is mandatory
# ./build_with_tag.sh -t 0.1.1

usage() {
    echo "Usage: $0  -t <docker image tag>" 1>&2
    echo "Optional flags:" 1>&2
    # d for data path
    echo "[-d <path to data>] (path string pointing to alternative data quarters)" 1>&2
    # x for architecture?
    echo "[-x <platform string>] (platform string to define the target Docker image platform)" 1>&2
    # s for save
    echo "[-s] (export the created Docker image to a tar.gz file)" 1>&2
    exit 1;
}

while getopts t:d:x:s flag
do
    case "${flag}" in
        t) tag=${OPTARG};;
        d) datapath=${OPTARG};;
        x) platform=${OPTARG};;
        s) save=1;;
    esac
done

if [ -z "${tag}" ]; then
    usage
fi

if [ -z "${platform}" ]; then
    platform="linux/x86_64"
fi

if [ -z "${repos}" ]; then
    repos="\
        pacta.portfolio.analysis \
        pacta.interactive.report \
        pacta.executive.summary \
        workflow.transition.monitor \
        "
fi

red () {
    printf "\033[31m${1}\033[0m\n"
}

yellow () {
    printf "\033[33m${1}\033[0m\n"
}

green () {
    printf "\033[32m${1}\033[0m\n"
}

dir_start="$(pwd)"
dir_temp="$(mktemp -d)"
cleanup () {
    rm -rf $dir_temp
    cd $dir_start
}
trap cleanup EXIT

url="git@github.com:RMI-PACTA/"


# test that SSH authentication to GitHub is possible
ssh -T git@github.com &>/dev/null
if [ $? -ne 1 ]
then
    red "You must have SSH authentication to GitHub setup properly to use this tool." && exit 1
else
    green "SSH authentication to GitHub has been verified\n"
fi


# test that docker is running
if (! docker images > /dev/null 2>&1 ); then
    red "The docker daemon does not appear to be running." && exit 1
fi


# test that no existing rmi_pacta docker image using the same tag is loaded
existing_img_tags="$(docker images rmi_pacta --format '{{.Tag}}')"
for i in $existing_img_tags
do
    if [ "$i" == "$tag" ]; then
        red "Tag $i is already in use. Please choose a different tag" && exit 1
    fi
done


# check that the specified tag is not already used in any of the repos
remotes="$(echo $repos | tr ' ' ',')"
remotes=$(eval "echo $url{$remotes}.git")
tags=""
for i in $remotes
do
    tags_i="$(git ls-remote --tags --ref $i | cut -d / -f 3)"
    tags="$tags $tags_i"
done

tags="$(echo $tags | tr ' ' '\n' | sort -V | uniq)"
for i in $tags
do
    if [ "$i" == "$tag" ]; then
        red "Tag '$tag' is taken. Choose a new tag different from these ones:"
        red "$(echo $tags | tr ' ' '\n' | sort -V | uniq)" && exit 1
    fi
done
if [ -z "$tags" ]; then
    yellow "These remotes returned no tag:"
    yellow "$(echo $remotes | tr ' ' '\n')"
    yellow "Are your SSH keys unset?"
fi

if [ "$dir_start" == "." ]; then
    dir_start="$(pwd)"
fi

wd="$(basename $dir_start)"
if [ ! "$wd" == "transitionmonitor_docker" ]; then
    red "Your current working directory is not 'transitionmonitor_docker': $dir_start" && exit 1
fi


# clone repos into temp directory
cd $dir_temp

for repo in $repos
do
    remote="${url}${repo}.git"
    git clone -b main "$remote" --depth 1 || exit 2
    green "$repo successfully cloned\n"
done
green "repos successfully cloned into temp directory\n"


# grab hash of the HEAD for each repo
head_hashes=""
for repo in $repos
do
    head_hash=$(git -C "$repo" rev-parse --verify --short HEAD || exit 2)
    head_hashes="$repo:$head_hash,$head_hashes"
    green "$(basename $repo) short hash of head is $head_hash"
done
green "HEAD hash successfully captures for each repo\n"


# set git tag in each repo and log
for repo in $repos
do
    git -C "$repo" tag -a "$tag" -m "Release pacta $tag" HEAD || exit 2
    green "$(basename $repo) tagged with $tag"
done
green "repos successfully tagged with $tag\n"


# Copy Dockerfile alongside pacta siblings and build the image
cp "${dir_start}/Dockerfile" "$dir_temp"

# Maybe copy in custom data path
# FIXME: this should be handled better
if [ -n "${datapath}" ]; then
    mkdir "${dir_temp}/pacta-data"
    cp -r "${datapath}" "${dir_temp}/pacta-data"
fi

# build the docker image
green "Building rmi_pacta Docker image...\n"

docker build \
    --build-arg image_tag=$tag \
    --build-arg head_hashes=$head_hashes \
    --platform $platform \
    --tag rmi_pacta:$tag \
    --tag rmi_pacta:latest \
    .

if [ $? -ne 0 ]
then
    red "The Docker image build failed!" && exit 1
else
    green "The Docker image build is complete!"
fi

cd $dir_start

image_tar_gz="rmi_pacta_v${tag}.tar.gz"
if [ -n "${save}" ]
then
    green "\nSaving docker image to ${image_tar_gz}..."
    docker save rmi_pacta:${tag} | gzip -q > "$image_tar_gz"
    green "\nimage saved as $image_tar_gz"
else
    echo -e "\nTo export the image as a tar.gz file:"
    yellow "docker save rmi_pacta:${tag} | gzip -q > '$image_tar_gz'"
fi

echo -e "\nTo load the image from the ${image_tar_gz} file:"
yellow "docker load --input ${image_tar_gz}"

echo -e "\nTo test which operating system the loaded image was built for:"
yellow "docker run --rm rmi_pacta:${tag} cat /etc/os-release"

echo -e "\nTo test which architecture the loaded image was built for:"
yellow "docker run --rm rmi_pacta:${tag} dpkg --print-architecture"

echo -e "\nTo see the build version of the loaded image was built for:"
yellow "docker run --rm -ti rmi_pacta:${tag} bash -c 'echo \$build_version'"

echo -e "\nTo see the R version installed on the loaded image:"
yellow "docker run --rm rmi_pacta:${tag} Rscript -e R.version\$version.string"

echo -e "\nTo test the new image with our test scripts (from the root directory of the test files) e.g.:"
yellow "./run-like-constructiva-flags.sh -t ${tag} -p Test_PA2021NO"
echo -e "\nor to run all the tests at once (from the root directory of the test files):"
yellow "./run-all-tests.sh"

echo -e "\nTo push the git tags from within the docker image:"
yellow "docker run --rm -ti -v \"\$HOME/.ssh\":/root/.ssh rmi_pacta:${tag} bash"
echo -e "\nthen inside the container (for each of the 5 PACTA repos:"
yellow "cd /bound && git push origin ${tag}"

exit 0
