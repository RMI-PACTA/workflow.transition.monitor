# using rocker r-vers as a base with R 4.1.2
# (which sets an env var for the CRAN repo to a RSPM mirror
#  pegged to a specific date relevant to the R version)
# https://hub.docker.com/r/rocker/r-ver
# https://rocker-project.org/images/versioned/r-ver.html

FROM rocker/r-ver:4.1.2

# install system dependencies
ARG SYS_DEPS="\
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    openssh-client \
    wget \
    nano `# only for utility, not needed for PACTA` \
    "
RUN apt-get update \
    && apt-get install -y --no-install-recommends $SYS_DEPS \
    && chmod -R a+rwX /root \
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
