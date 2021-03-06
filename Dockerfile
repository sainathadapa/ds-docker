FROM ubuntu:18.04

RUN apt-get update \
  && apt-get install -y locales apt-utils \
  && locale-gen en_US.UTF-8

ENV R_VERSION=3.4.4 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    TERM=xterm \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y \
     apt-transport-https ca-certificates software-properties-common \
  ## && add-apt-repository -y ppa:opencpu/imagemagick \
  ## && apt-get update \
  ## && apt-get install -y \
     curl htop sqlite3 awscli \
     default-jre default-jdk \
     postgresql-client libpq-dev \
     ## Python
     python3-pip virtualenv \
     ## R
     libcurl4-openssl-dev \
     libssl-dev \
     libxml2-dev \
     libmagick++-dev \
     r-base r-base-dev \
     r-cran-rjava 

# Configuring java
RUN R CMD javareconf -e

# Installing R packages
RUN mkdir -p /usr/local/lib/R/etc \
  ## Add a default CRAN mirror
  && echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site \
  ## Add a library directory (for user-installed packages)
  && mkdir -p /usr/local/lib/R/site-library \
  && chown root:staff /usr/local/lib/R/site-library \
  && chmod g+wx /usr/local/lib/R/site-library \
  ## Fix library path
  && echo "R_LIBS_USER='/usr/local/lib/R/site-library'" >> /usr/local/lib/R/etc/Renviron \
  && echo "R_LIBS=\${R_LIBS-'/usr/local/lib/R/site-library:/usr/local/lib/R/library:/usr/lib/R/library'}" >> /usr/local/lib/R/etc/Renviron \
  ## Install bunch of packages
  && Rscript -e "options(warn=2); install.packages(c('devtools', 'caTools', 'bitops', 'prettydoc'))" \
  && Rscript -e "options(warn=2); install.packages(c('data.table', 'tidyverse', 'caret'))" \
  && Rscript -e "options(warn=2); install.packages(c('rsample', 'pdp', 'lime', 'drat', 'gbm', 'vtreat'))" \
  && Rscript -e "options(warn=2); install.packages(c('randomForest', 'ranger'))" \
  && Rscript -e "options(warn=2); drat:::addRepo('dmlc'); install.packages('xgboost', repos='http://dmlc.ml/drat/', type = 'source')"

# Rstudio
ENV RSTUDIO_VERSION=${RSTUDIO_VERSION:-1.1.447}
ENV PATH=/usr/lib/rstudio-server/bin:$PATH

## Download and install RStudio server & dependencies
## Attempts to get detect latest version, otherwise falls back to version given in $VER
## Symlink pandoc, pandoc-citeproc so they are available system-wide
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    file \
    git \
    libapparmor1 \
    libcurl4-openssl-dev \
    libedit2 \
    libssl-dev \
    lsb-release \
    psmisc \
    python-setuptools \
    sudo \
    wget \
    multiarch-support \
  && wget -O libssl1.0.0.deb http://ftp.debian.org/debian/pool/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u8_amd64.deb \
  && dpkg -i libssl1.0.0.deb \
  && rm libssl1.0.0.deb \
  && RSTUDIO_LATEST=$(wget --no-check-certificate -qO- https://s3.amazonaws.com/rstudio-server/current.ver) \
  && [ -z "$RSTUDIO_VERSION" ] && RSTUDIO_VERSION=$RSTUDIO_LATEST || true \
  && wget -q http://download2.rstudio.org/rstudio-server-${RSTUDIO_VERSION}-amd64.deb \
  && dpkg -i rstudio-server-${RSTUDIO_VERSION}-amd64.deb \
  && rm rstudio-server-*-amd64.deb \
  ## Symlink pandoc & standard pandoc templates for use system-wide
  && ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc /usr/local/bin \
  && ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc-citeproc /usr/local/bin \
  && git clone https://github.com/jgm/pandoc-templates \
  && mkdir -p /opt/pandoc/templates \
  && cp -r pandoc-templates*/* /opt/pandoc/templates && rm -rf pandoc-templates* \
  && mkdir /root/.pandoc && ln -s /opt/pandoc/templates /root/.pandoc/templates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/ \
  ## RStudio wants an /etc/R, will populate from $R_HOME/etc
  && mkdir -p /etc/R \
  ## Write config files in $R_HOME/etc
  && echo '\n\
    \n# Configure httr to perform out-of-band authentication if HTTR_LOCALHOST \
    \n# is not set since a redirect to localhost may not work depending upon \
    \n# where this Docker container is running. \
    \nif(is.na(Sys.getenv("HTTR_LOCALHOST", unset=NA))) { \
    \n  options(httr_oob_default = TRUE) \
    \n}' >> /usr/local/lib/R/etc/Rprofile.site \
  && echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron \
  ## Need to configure non-root user for RStudio
  && useradd rstudio \
  && echo "rstudio:rstudio" | chpasswd \
	&& mkdir /home/rstudio \
	&& chown rstudio:rstudio /home/rstudio \
	&& addgroup rstudio staff \
  ## Prevent rstudio from deciding to use /usr/bin/R if a user apt-get installs a package
  ## &&  echo 'rsession-which-r=/usr/local/bin/R' >> /etc/rstudio/rserver.conf \
  ## use more robust file locking to avoid errors when using shared volumes:
  && echo 'lock-type=advisory' >> /etc/rstudio/file-locks \
  ## configure git not to request password each time
  && git config --system credential.helper 'cache --timeout=3600' \
  && git config --system push.default simple \
  ## Set up S6 init system
  && wget -P /tmp/ https://github.com/just-containers/s6-overlay/releases/download/v1.11.0.1/s6-overlay-amd64.tar.gz \
  && tar xzf /tmp/s6-overlay-amd64.tar.gz -C / \
  && mkdir -p /etc/services.d/rstudio \
  && echo '#!/usr/bin/with-contenv bash \
          \n exec /usr/lib/rstudio-server/bin/rserver --server-daemonize 0' \
          > /etc/services.d/rstudio/run \
  && echo '#!/bin/bash \
          \n rstudio-server stop' \
          > /etc/services.d/rstudio/finish

COPY userconf.sh /etc/cont-init.d/userconf
COPY pam-helper.sh /usr/lib/rstudio-server/bin/pam-helper
EXPOSE 8787
COPY user-settings /home/rstudio/.rstudio/monitored/user-settings/
# No chown will cause "RStudio Initalization Error"
# "Error occurred during the transmission"; RStudio will not load.
RUN chown -R rstudio:rstudio /home/rstudio/.rstudio

RUN mkdir -p pycode
WORKDIR "/pycode"
RUN pip3 install pipenv
RUN pipenv install pandas scikit-learn jupyter ipython matplotlib seaborn scipy statsmodels jupyterthemes jupyter_contrib_nbextensions
RUN pipenv run jupyter contrib nbextension install --user
RUN pipenv run jt -t grade3 -T
EXPOSE 8888

# fish shell
RUN apt-add-repository -y ppa:fish-shell/release-2 \
  && apt-get update \
  && apt-get install -y fish
ENV SHELL=/usr/bin/fish

CMD ["/init"]

