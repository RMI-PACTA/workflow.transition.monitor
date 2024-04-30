<!-- badges: start -->
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![.github/workflows/build-Docker-image-triggers.yml](https://github.com/RMI-PACTA/workflow.transition.monitor/actions/workflows/build-Docker-image-triggers.yml/badge.svg)](https://github.com/RMI-PACTA/workflow.transition.monitor/actions/workflows/build-Docker-image-triggers.yml)
<!-- badges: end -->

# Description

The Dockerfile in this repository creates an image containing a freshly cloned copy of workflow.transition.monitor and templates.transition.monitor. It also installs the relevant public PACTA R packages from their respective GitHub repos. It also adds the relevant quarter PACTA data directory under `/pacta-data`.

The tree of the docker container looks like this:

``` {.bash}
/bound  # contents of workflow.transition.monitor
/bound/bin  # contains the shell scripts that run the process
/pacta-data
/pacta-data/2021Q4  # or whichever quarter is relevant for that build
/templates.transition.monitor
```

# Notes

Note that workflow.transition.monitor and friends are not mounted but copied into the
container, so they will be frozen in the state they are when you build
the image.

# Usage

You must have SSH authentication to your GitHub account setup to use this tool.

Before running the script, you will need to choose the tag that you
want to use for the release. You should use [semantic
versioning](https://semver.org).

All build scripts are located in the `build` directory. Run the `build_with_tag.sh` script from the `build/` directory, specifying a tag to assign to it.

``` {.bash}
./build_with_tag.sh -t 0.1.14
```

NOTE: Currently the docker image WILL NOT BUILD without specifying a path to a data folder to copy in. The local data folder to be copied in should have the proper name for the quarter of data it is associated with, e.g. `2021Q4`, because the same name will be copied in to the Docker image. This is done via the `-d` argument:

``` {.bash}
./build_with_tag.sh -t 0.1.14 -d /home/azureuser/2021Q4
```

The default target platform architecture is "linux/x86_64", and that is **required** for the TM website, however, you may use the `-x` option to set an alternate target platform architecture explicitly. For example, you may desire to build for "linux/arm64" in order to do local testing on an M1 mac, which will run much faster than running tests through a "linux/x86_64" image through emulation. Example:

``` {.bash}
./build_with_tag.sh -t 0.1.14 -x "linux/arm64"
```

Additionally, by default `./build_with_tag.sh` will *not* export the built image to a `*.tar.gz` file. Saving/exporting the docker image is a time consuming process, so it may make more sense to build the image (which will then automatically be loaded into your local loaded docker images), then do some testing, and only if you're sure it's working properly then export it to a `*.tar.gz` file with (replace `<tag>` with the appropriate version number) `docker save rmi_pacta:<tag> | gzip -q > '$image_tar_gz'`. However, if you know you want to export the built docker image, you can do it all at once by adding the `-s` option like so:

``` {.bash}
./build_with_tag.sh -t 0.1.14 -s
```

The script will:

- clone the repos locally, only copying the current version of the files
- build a `rmi_pacta:<tag>` and `rmi_pacta:latest` docker image (where `<tag>` is the tag you provided, e.g. `0.1.14`). The image builds from the Dockerfile in this directory, which will

  - use [`rocker/r-ver:<version>`](https://hub.docker.com/r/rocker/r-ver/tags) as the base (where <version> is the R version specified in the Dockerfile)
  - install system dependencies
  - install latex and dependencies
  - install dependent TeX packages
  - install dependent R packages and system dependencies
  - copy in the freshly cloned repos
  - install the appropriate PACTA R packages in the Docker image's R environment from their respective GitHub repos
  - make some necessary permissions changes
  - set the `build_version` environment variable with the specified tag

If the build is successful, the new rmi_pacta docker image will already be 
loaded in your local docker images.

#  Testing

There are two scripts in the `tests` directory to facilitate testing of the docker 
image: `run-like-constructiva-flags.sh` and `run-all-tests.sh`

# Releasing

To release a new version of the software, use the `tag-and-push.sh` script in the `build` directory.

# For the web

That shared docker image can be loaded into the new machine with, for example:

``` {.bash}
docker load --input rmi_pacta_v0.1.14.tar.gz
```

The docker image can then be used as intended with a script such as...

``` {.bash}
portfolio_name="TestPortfolio"
userFolder="$(pwd)"/working_dir/TestPortfolio
resultsFolder="$(pwd)"/user_results/4

docker run -ti \
  --rm \
  --pull=never \
  --network none \
  --user 1000:1000 \
  --memory=8g \
  --memory-swappiness=0 \
  --mount type=bind,source=${userFolder},target=/bound/working_dir \
  --mount type=bind,readonly,source=${resultsFolder},target=/user_results \
  rmi_pacta:latest \
  /bound/bin/run-r-scripts "$portfolio_name"
```

where you set `userFolder` to the path to the directory that contains
the user specific portfolio info on the server (typical PACTA output directory 
structure), and you set `resultsFolder` to the path to the directory that 
contains the survey (and other) results that are relevant to the specific user 
on the server. Those directories will then be mounted inside of the docker
container in the appropriate locations.

# Using Docker images pushed to GHCR automatically by GH Actions

``` {.bash}
tag_name=PR199
repos_directory=~/github/rmi-pacta/
data_folder=~/github/rmi-pacta/pacta-data


# if you have local clones of workflow.transition.monitor and 
# templates.transition.monitor in the specified repos_directory above, you 
# probably do not need to edit any options below unless you want to further
# customize things
image_name=ghcr.io/rmi-pacta/workflow.transition.monitor:$tag_name
portfolio_name="1234"
user_folder=${repos_directory}workflow.transition.monitor/working_dir
templates_folder=${repos_directory}templates.transition.monitor


docker run -ti --rm --network none \
  --pull=always \
  --mount type=bind,source=${user_folder},target=/bound/working_dir \
  --mount type=bind,readonly,source=${data_folder},target=/pacta-data \
  --mount type=bind,readonly,source=${templates_folder},target=/templates.transition.monitor \
  $image_name \
  /bound/bin/run-r-scripts "$portfolio_name"
```

