ARG FROM=debian:buster-slim
FROM ${FROM}

ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_VERSION="2.26.2"
ARG GH_RUNNER_VERSION="2.295.0"
ARG DOCKER_COMPOSE_VERSION="1.27.4"
ARG USER_HOME

ENV RUNNER_NAME=""
ENV RUNNER_WORK_DIRECTORY="_work"
ENV RUNNER_TOKEN=""
ENV RUNNER_REPOSITORY_URL=""
ENV RUNNER_LABELS=""
ENV RUNNER_ALLOW_RUNASROOT=true
ENV GITHUB_ACCESS_TOKEN=""
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache

# Labels.
LABEL maintainer="me@tcardonne.fr" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.name="tcardonne/github-runner" \
    org.label-schema.description="Dockerized GitHub Actions runner for yocto builds." \
    org.label-schema.url="https://github.com/tcardonne/docker-github-runner" \
    org.label-schema.vcs-url="https://github.com/tcardonne/docker-github-runner" \
    org.label-schema.vendor="Thomas Cardonne" \
    org.label-schema.docker.cmd="docker run -it tcardonne/github-runner:latest"

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y \
        curl \
        unzip \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        sudo \
        supervisor \
        jq \
        iputils-ping \
        build-essential \
        zlib1g-dev \
        chrpath cpio diffstat gawk wget locales python3-distutils rsync expect \
        gettext \
        liblttng-ust0 \
        libcurl4-openssl-dev \
        texinfo gcc-multilib socat cpio  xz-utils debianutils libsdl1.2-dev xterm autoconf libtool libglib2.0-dev \
        libarchive-dev sed cvs subversion coreutils texi2html docbook-utils python-pysqlite2 help2man make gcc g++ \
        desktop-file-utils libgl1-mesa-dev libglu1-mesa-dev mercurial automake groff curl lzop asciidoc u-boot-tools \
        dos2unix mtd-utils pv libncurses5 libncurses5-dev libncursesw5-dev libelf-dev zlib1g-dev bc rename \
        openssh-client && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean


COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod 644 /etc/supervisor/conf.d/supervisord.conf

# Install Docker CLI
RUN curl -fsSL https://get.docker.com -o- | sh && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Install Docker-Compose
RUN curl -L -o /usr/local/bin/docker-compose \
    "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" && \
    chmod +x /usr/local/bin/docker-compose

RUN cd /tmp && \
    curl -sL -o git.tgz \
    https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz && \
    tar zxf git.tgz  && \
    cd git-${GIT_VERSION}  && \
    ./configure --prefix=/usr  && \
    make && \
    make install && \
    rm -rf /tmp/*


RUN mkdir -p /home/runner ${AGENT_TOOLSDIRECTORY}

WORKDIR /home/runner

RUN GH_RUNNER_VERSION=${GH_RUNNER_VERSION:-$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | grep tag_name | sed -E 's/.*"v([^"]+)".*/\1/')} \
    && curl -L -O https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
    && tar -zxf actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
    && rm -f actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
    && ./bin/installdependencies.sh \
    && chown -R root: /home/runner \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean


# Setting locales
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LC_ALL en_US.UTF-8 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en     

# create non-root user for yocto-build
RUN useradd -u 1022 -g users -d /home/nonroot -s /bin/bash -p $(echo mypasswd | openssl passwd -1 -stdin) nonroot
RUN usermod -aG sudo nonroot
RUN chown nonroot /home/runner/
# RUN chown nonroot /home/nonroot/


# COPY id_rsa /home/nonroot/.ssh/id_rsa
COPY entrypoint.sh /home/runner/
RUN echo mypasswd | sudo -S chmod +x /home/runner/entrypoint.sh  
# RUN chmod +r /home/nonroot/.ssh/id_rsa

ENTRYPOINT ["/home/runner/entrypoint.sh"]
USER nonroot
WORKDIR /home/nonroot
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
