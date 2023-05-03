# using rocker r-vers as a base with R 4.2.3
# https://hub.docker.com/r/rocker/r-ver
# https://rocker-project.org/images/versioned/r-ver.html
#
# sets CRAN repo to use Posit Package Manager to freeze R package versions to
# those available on 2023-03-31
# https://packagemanager.rstudio.com/client/#/repos/2/overview
# https://packagemanager.rstudio.com/cran/__linux__/jammy/2023-03-31+MbiAEzHt
#
# sets CTAN repo to freeze TeX package dependencies to those available on
# 2021-12-31
# https://www.texlive.info/tlnet-archive/2021/12/31/tlnet/


FROM --platform=linux/amd64 rocker/r-ver:4.2.3
ARG CRAN_REPO="https://packagemanager.rstudio.com/cran/__linux__/jammy/2023-03-31+MbiAEzHt"
RUN echo "options(repos = c(CRAN = '$CRAN_REPO'))" >> "${R_HOME}/etc/Rprofile.site"

# install system dependencies
ARG SYS_DEPS="\
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    openssh-client \
    wget \
    "
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $SYS_DEPS \
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
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $R_PKG_SYS_DEPS \
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
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $TEX_APT \
    && tlmgr init-usertree \
    && rm -rf /var/lib/apt/lists/*

# install tex package dependencies
ARG CTAN_REPO=https://www.texlive.info/tlnet-archive/2021/12/31/tlnet/
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
COPY pacta-data /pacta-data

# install packages for dependency resolution and installation
RUN Rscript -e "install.packages('pak')"
RUN Rscript -e "pak::pkg_install(c('renv', 'yaml'))"

# copy in DESCRIPTION files from local PACTA package clones
COPY pacta.executive.summary/DESCRIPTION /pacta.executive.summary/DESCRIPTION
COPY pacta.interactive.report/DESCRIPTION /pacta.interactive.report/DESCRIPTION
COPY pacta.portfolio.analysis/DESCRIPTION /pacta.portfolio.analysis/DESCRIPTION
COPY pacta.portfolio.audit/DESCRIPTION /pacta.portfolio.audit/DESCRIPTION
COPY pacta.portfolio.import/DESCRIPTION /pacta.portfolio.import/DESCRIPTION
COPY pacta.portfolio.utils/DESCRIPTION /pacta.portfolio.utils/DESCRIPTION

# copy in scripts from this repo
COPY workflow.transition.monitor /bound

# install R package dependencies
RUN Rscript -e "\
  local_pkgs <- \
    c( \
      'pacta.executive.summary', \
      'pacta.interactive.report', \
      'pacta.portfolio.analysis', \
      'pacta.portfolio.audit', \
      'pacta.portfolio.import', \
      'pacta.portfolio.utils' \
    ); \
  workflow_pkgs <- renv::dependencies('/bound')[['Package']]; \
  workflow_pkgs <- setdiff(workflow_pkgs, local_pkgs); \
  pacta_deps <- lapply(local_pkgs, pak::local_deps); \
  pacta_deps <- do.call(rbind, pacta_deps); \
  pacta_deps <- pacta_deps[!pacta_deps[['type']] %in% c('local', 'installed'), ]; \
  pacta_deps <- pacta_deps[!pacta_deps[['package']] %in% local_pkgs, ]; \
  pacta_deps <- sort(unique(pacta_deps[, 'ref'])); \
  pak::pkg_install(c(workflow_pkgs, pacta_deps)); \
  "

# copy in local PACTA package clones
COPY pacta.executive.summary /pacta.executive.summary
COPY pacta.interactive.report /pacta.interactive.report
COPY pacta.portfolio.analysis /pacta.portfolio.analysis
COPY pacta.portfolio.audit /pacta.portfolio.audit
COPY pacta.portfolio.import /pacta.portfolio.import
COPY pacta.portfolio.utils /pacta.portfolio.utils

# install local R package clones
RUN Rscript -e "\
  local_pkgs <- \
    c( \
      'pacta.executive.summary', \
      'pacta.interactive.report', \
      'pacta.portfolio.analysis', \
      'pacta.portfolio.audit', \
      'pacta.portfolio.import', \
      'pacta.portfolio.utils' \
    ); \
  pak::pkg_install(paste0('local::./', local_pkgs)); \
  "

# set permissions for PACTA repos that need local content
RUN chmod -R a+rwX /bound && chmod -R a+rwX /pacta-data \
    && chmod -R a+rwX /pacta.interactive.report

# set the build_version environment variable
ARG image_tag
ENV build_version=$image_tag
ARG head_hashes
ENV head_hashes=$head_hashes

RUN exit 0
