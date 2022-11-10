# using rocker r-vers as a base with R 4.1.2
# (which sets an env var for the CRAN repo to a RSPM mirror
#  pegged to a specific date relevant to the R version)
# https://hub.docker.com/r/rocker/r-ver
# https://rocker-project.org/images/versioned/r-ver.html

FROM rocker/r-ver:4.1.2

# install system dependencies
# nano only for utility, not needed for PACTA
ARG SYS_DEPS="\
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    openssh-client \
    wget \
    nano \
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
    "
RUN apt-get update \
    && apt-get install -y --no-install-recommends $TEX_APT \
    && tlmgr init-usertree \
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

# install headless Chrome for R-pkg {chromote}
RUN [ $(which google-chrome) ] || apt-get update \
    && apt-get install -y --no-install-recommends gnupg curl \
    && curl -fsSL -o /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && DEBIAN_FRONTEND='noninteractive' apt-get install -y --no-install-recommends /tmp/google-chrome.deb \
    && rm -f /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# install R package dependencies
ARG PKG_DEPS="\
    bookdown \
    cli \
    config \
    countrycode \
    devtools \
    dplyr \
    fs \
    ggplot2 \
    glue \
    here \
    jsonlite \
    knitr \
    readr \
    rmarkdown \
    scales \
    stringr \
    tibble \
    tidyr \
    writexl \
    "
RUN Rscript -e "\
    install.packages('remotes'); \
    pkg_deps <- strsplit(trimws(gsub('[\\\]+', '', '$PKG_DEPS')), '[[:space:]]+')[[1]]; \
    remotes::install_cran(pkg_deps); \
    "

# copy in PACTA repos
COPY pacta-data /pacta-data
COPY pacta.executive.summary /pacta.executive.summary
COPY pacta.interactive.report /pacta.interactive.report
COPY pacta.portfolio.analysis /pacta.portfolio.analysis
COPY workflow.transition.monitor /bound

# install PACTA R packages
RUN Rscript -e "devtools::install(pkg = '/pacta.executive.summary')"
RUN Rscript -e "devtools::install(pkg = '/pacta.portfolio.analysis')"

# set permissions for PACTA repos
RUN chmod -R a+rwX /bound \
    && chmod -R a+rwX /pacta.interactive.report \
    && chmod -R a+rwX /pacta-data

# set the build_version environment variable
ARG image_tag
ENV build_version=$image_tag

RUN exit 0
