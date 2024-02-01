# using rocker r-vers as a base with R 4.3.1
# https://hub.docker.com/r/rocker/r-ver
# https://rocker-project.org/images/versioned/r-ver.html
#
# sets CRAN repo to use Posit Package Manager to freeze R package versions to
# those available on 2023-10-30
# https://packagemanager.posit.co/client/#/repos/2/overview
# https://packagemanager.posit.co/cran/__linux__/jammy/2023-10-30
#
# sets CTAN repo to freeze TeX package dependencies to those available on
# 2021-12-31
# https://www.texlive.info/tlnet-archive/2021/12/31/tlnet/

ARG PLATFORM="linux/amd64"
ARG R_VERS="4.3.1"
FROM --platform=$PLATFORM rocker/r-ver:$R_VERS

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

ARG CRAN_REPO="https://packagemanager.posit.co/cran/__linux__/jammy/2023-10-30"
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
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    lmodern \
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
    tools \
    xcolor \
    zref \
    "
RUN tlmgr --repository $CTAN_REPO install $TEX_DEPS

# copy in PACTA data
ARG PACTA_DATA_SRC="pacta-data"
ARG PACTA_DATA_DIR="/pacta-data"
COPY $PACTA_DATA_SRC $PACTA_DATA_DIR

# copy in report templates
ARG TEMPLATES_SRC="templates.transition.monitor"
ARG TEMPLATES_DIR="/templates.transition.monitor"
COPY $TEMPLATES_SRC $TEMPLATES_DIR

# install packages for dependency resolution and installation
RUN Rscript -e "install.packages('pak', repos = 'https://r-lib.github.io/p/pak/stable/')"

# copy in scripts from this repo
ARG WORKFLOW_DIR="/bound"
COPY workflow.transition.monitor $WORKFLOW_DIR

# PACTA R package tags
ARG summary_tag="/tree/main"
ARG allocate_tag="/tree/main"
ARG audit_tag="/tree/main"
ARG import_tag="/tree/main"
ARG report_tag="/tree/main"
ARG utils_tag="/tree/main"

ARG summary_url="https://github.com/rmi-pacta/pacta.executive.summary"
ARG allocate_url="https://github.com/rmi-pacta/pacta.portfolio.allocate"
ARG audit_url="https://github.com/rmi-pacta/pacta.portfolio.audit"
ARG import_url="https://github.com/rmi-pacta/pacta.portfolio.import"
ARG report_url="https://github.com/rmi-pacta/pacta.portfolio.report"
ARG utils_url="https://github.com/rmi-pacta/pacta.portfolio.utils"

# install R package dependencies
RUN Rscript -e "\
  gh_pkgs <- \
    c( \
      paste0('$summary_url', '$summary_tag'), \
      paste0('$allocate_url', '$allocate_tag'), \
      paste0('$audit_url', '$audit_tag'), \
      paste0('$import_url', '$import_tag'), \
      paste0('$report_url', '$report_tag'), \
      paste0('$utils_url', '$utils_tag') \
    ); \
  workflow_pkgs <- pak::local_deps(root = '$WORKFLOW_DIR')[['ref']]; \
  workflow_pkgs <- grep('^RMI-PACTA[/]|^local::.$', workflow_pkgs, value = TRUE, invert = TRUE); \
  pak::pak(c(gh_pkgs, workflow_pkgs)); \
  "

# set permissions for PACTA repos that need local content
RUN chmod -R a+rwX $WORKFLOW_DIR && \
    chmod -R a+rwX $PACTA_DATA_DIR && \
    chmod -R a+rwX $TEMPLATES_DIR

# set the build_version environment variable
ARG image_tag
ENV build_version=$image_tag
ARG head_hashes
ENV head_hashes=$head_hashes

RUN exit 0
