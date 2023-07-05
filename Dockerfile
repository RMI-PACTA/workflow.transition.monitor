# using rocker r-vers as a base with R 4.2.3
# https://hub.docker.com/r/rocker/r-ver
# https://rocker-project.org/images/versioned/r-ver.html
#
# sets CRAN repo to use Posit Package Manager to freeze R package versions to
# those available on 2023-03-31
# https://packagemanager.posit.co/client/#/repos/2/overview
# https://packagemanager.posit.co/cran/__linux__/jammy/2023-03-31+MbiAEzHt
#
# sets CTAN repo to freeze TeX package dependencies to those available on
# 2021-12-31
# https://www.texlive.info/tlnet-archive/2021/12/31/tlnet/

ARG PLATFORM="linux/amd64"
ARG R_VERS="4.2.3"
FROM --platform=$PLATFORM rocker/r-ver:$R_VERS

ARG CRAN_REPO="https://packagemanager.posit.co/cran/__linux__/jammy/2023-03-31+MbiAEzHt"
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

# install system dependencies for R packages
ARG R_PKG_SYS_DEPS="\
    libfontconfig1-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libgit2-dev \
    libharfbuzz-dev \
    libicu-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libxml2-dev \
    libxt6 \
    make \
    pandoc \
    perl \
    zlib1g-dev \
    "
RUN apt-get update \
    && apt-get install -y --no-install-recommends $R_PKG_SYS_DEPS \
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
ARG PACTA_DATA="pacta-data"
ARG PACTA_DATA_DIR="/pacta-data"
COPY $PACTA_DATA $PACTA_DATA_DIR

# copy in report templates
ARG TEMPLATES="templates.transition.monitor"
ARG TEMPLATES_DIR="/templates.transition.monitor"
COPY $TEMPLATES $TEMPLATES_DIR

# install packages for dependency resolution and installation
RUN Rscript -e "install.packages('pak')"
RUN Rscript -e "pak::pkg_install(c('renv', 'yaml'))"

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
      paste0('$allocate_url', '$audit_tag'), \
      paste0('$import_url', '$import_tag'), \
      paste0('$report_url', '$report_tag'), \
      paste0('$utils_url', '$utils_tag') \
    ); \
  workflow_pkgs <- renv::dependencies('$WORKFLOW_DIR')[['Package']]; \
  workflow_pkgs <- grep('^pacta[.]', workflow_pkgs, value = TRUE, invert = TRUE); \
  pak::pak(c(gh_pkgs, workflow_pkgs)); \
  "

# set permissions for PACTA repos that need local content
RUN chmod -R a+rwX /bound && \
    chmod -R a+rwX /pacta-data && \
    chmod -R a+rwX /templates.transition.monitor

# set the build_version environment variable
ARG image_tag
ENV build_version=$image_tag
ARG head_hashes
ENV head_hashes=$head_hashes

RUN exit 0
