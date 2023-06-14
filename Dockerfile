ARG R_VERS
FROM --platform=linux/amd64 rocker/r-ver:${R_VERS:-latest}

# set apt-get to noninteractive mode
ARG DEBIAN_FRONTEND noninteractive
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
ARG CTAN_REPO
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
ARG PACTA_DATA
ARG PACTA_DATA_DIR
COPY $PACTA_DATA $PACTA_DATA_DIR

# copy in report templates
ARG TEMPLATES
ARG TEMPLATES_DIR
COPY $TEMPLATES $TEMPLATES_DIR

# copy in scripts from this repo
ARG WORKFLOW_DIR
COPY workflow.transition.monitor $WORKFLOW_DIR

# install R package dependencies
ARG CRAN_REPO
RUN echo "options(repos = c(CRAN = '$CRAN_REPO'))" >> "${R_HOME}/etc/Rprofile.site"
ARG PACTA_PKGS
RUN Rscript -e "install.packages('pak')"
RUN Rscript -e "pak::pak(c('renv', 'yaml'))"
RUN Rscript -e "\
    pacta_pkgs <- strsplit('$PACTA_PKGS', '[[:space:]]+')[[1]][-1]; \
    workflow_pkgs <- sort(unique(renv::dependencies('$WORKFLOW_DIR')[['Package']])); \
    workflow_pkgs <- grep('^pacta[.]', workflow_pkgs, value = TRUE, invert = TRUE); \
    pak::pak(c(pacta_pkgs, workflow_pkgs)); \
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
