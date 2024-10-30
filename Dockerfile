# using rocker r-vers as a base with R 4.3.1
# https://hub.docker.com/r/rocker/r-ver
# https://rocker-project.org/images/versioned/r-ver.html
#
# sets CRAN repo to use Posit Package Manager to freeze R package versions to
# those available on 2024-03-05
# https://packagemanager.posit.co/client/#/repos/2/overview
# https://packagemanager.posit.co/cran/__linux__/jammy/2024-03-05
#
# sets CTAN repo to freeze TeX package dependencies to those available on
# 2021-12-31
# https://www.texlive.info/tlnet-archive/2021/12/31/tlnet/

ARG PLATFORM="linux/amd64"
ARG R_VERS="4.3.1"
FROM --platform=$PLATFORM rocker/r-ver:$R_VERS as base

LABEL org.opencontainers.image.source=https://github.com/RMI-PACTA/workflow.transition.monitor
LABEL org.opencontainers.image.description="Docker image to drive the Transition Monitor backend"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.title=""
LABEL org.opencontainers.image.revision=""
LABEL org.opencontainers.image.version=""
LABEL org.opencontainers.image.vendor=""
LABEL org.opencontainers.image.base.name=""
LABEL org.opencontainers.image.ref.name=""
LABEL org.opencontainers.image.authors=""

ARG CRAN_REPO="https://packagemanager.posit.co/cran/__linux__/jammy/2024-03-05"
RUN echo "options(repos = c(CRAN = '$CRAN_REPO'))" >> "${R_HOME}/etc/Rprofile.site"

# set apt-get to noninteractive mode
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NOWARNINGS="yes"

# install system dependencies
ARG SYS_DEPS="\
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    openssh-client \
    wget \
    "
RUN apt-get update \
    && apt-get install -y --no-install-recommends $SYS_DEPS \
    && chmod -R a+rwX /root \
    && rm -rf /var/lib/apt/lists/*

# install TeX system and fonts
ARG TEX_APT="\
    lmodern \
    texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-lang-german \
    texlive-xetex \
    xz-utils \
    "
RUN apt-get update \
    && apt-get install -y --no-install-recommends $TEX_APT \
    && tlmgr init-usertree \
    && rm -rf /var/lib/apt/lists/*

# install tex package dependencies
ARG CTAN_REPO="https://www.texlive.info/tlnet-archive/2021/12/31/tlnet/"
ARG TEX_DEPS="\
    geometry \
    hyperref \
    l3packages \
    mdframed \
    needspace \
    polyglossia \
    tools \
    xcolor \
    zref \
    "
RUN tlmgr --repository $CTAN_REPO install $TEX_DEPS

# install packages for dependency resolution and installation
RUN Rscript -e "install.packages('pak', repos = 'https://r-lib.github.io/p/pak/stable/')"

# copy in PACTA data
ARG PACTA_DATA_SRC="pacta-data"
ARG PACTA_DATA_DIR="/pacta-data"
COPY $PACTA_DATA_SRC $PACTA_DATA_DIR

# copy in report templates
ARG TEMPLATES_SRC="templates.transition.monitor"
ARG TEMPLATES_DIR="/templates.transition.monitor"
COPY $TEMPLATES_SRC $TEMPLATES_DIR

# Copy DESCRIPTION and install dependencies
ARG WORKFLOW_DIR="/bound"
COPY workflow.transition.monitor/DESCRIPTION ${WORKFLOW_DIR}/DESCRIPTION

# set permissions for PACTA repos that need local content
RUN chmod -R a+rwX $WORKFLOW_DIR && \
    chmod -R a+rwX $PACTA_DATA_DIR && \
    chmod -R a+rwX $TEMPLATES_DIR

RUN Rscript -e "pak::local_install_deps(root = '$WORKFLOW_DIR')"

FROM base AS install-pacta

# copy in everything from this repo
COPY workflow.transition.monitor $WORKFLOW_DIR

# install dependencies in the install-pacta layer (not cached) again, to pick
# up any recent changes in the GH packages
RUN Rscript -e "pak::local_install_deps(root = '$WORKFLOW_DIR')"

# set the build_version environment variable
ARG image_tag
ENV build_version=$image_tag
ARG head_hashes
ENV head_hashes=$head_hashes
