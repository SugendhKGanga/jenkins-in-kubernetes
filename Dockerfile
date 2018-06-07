FROM jenkins/jenkins:lts

# Running as root to have an easy support for Docker
USER root

# A default admin user
ENV ADMIN_USER=admin \
    ADMIN_PASSWORD=password

# Jenkins init scripts
COPY security.groovy /usr/share/jenkins/ref/init.groovy.d/

# Install plugins at Docker image build time
COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/install-plugins.sh $(cat /usr/share/jenkins/plugins.txt) && \
    mkdir -p /usr/share/jenkins/ref/ && \
    echo lts > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state && \
    echo lts > /usr/share/jenkins/ref/jenkins.install.InstallUtil.lastExecVersion

# Install Docker
RUN apt-get -qq update && \
    apt-get -qq -y install curl && \
    curl -sSL https://get.docker.com/ | sh

# Install kubectl and helm
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
	
 #Install .net sdk

# Install .NET CLI dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libc6 \
        libcurl3 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu57 \
        liblttng-ust0 \
        libssl1.0.2 \
        libstdc++6 \
        libunwind8 \
        libuuid1 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Install .NET Core SDK
ENV DOTNET_SDK_VERSION 2.1.200
ENV DOTNET_SDK_DOWNLOAD_URL https://dotnetcli.blob.core.windows.net/dotnet/Sdk/$DOTNET_SDK_VERSION/dotnet-sdk-$DOTNET_SDK_VERSION-linux-x64.tar.gz
ENV DOTNET_SDK_DOWNLOAD_SHA c1b07ce8849619ca505aafd2983bcdd7141536ccae243d4249b0c9665daf107e03a696ad5f1d95560142cd841a0888bbf5f1a8ff77d3bdc3696b5873481f0998

RUN curl -SL $DOTNET_SDK_DOWNLOAD_URL --output dotnet.tar.gz \
    && echo "$DOTNET_SDK_DOWNLOAD_SHA dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -zxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# Enable detection of running in a container
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps perfomance
    NUGET_XMLDOC_MODE=skip

# Trigger the population of the local package cache
RUN mkdir warmup \
    && cd warmup \
    && dotnet new \
    && cd .. \
    && rm -rf warmup \
    && rm -rf /tmp/NuGetScratch

# Workaround for https://github.com/Microsoft/DockerTools/issues/87. This instructs NuGet to use 4.5 behavior in which
# all errors when attempting to restore a project are ignored and treated as warnings instead. This allows the VS
# tooling to use -nowarn:MSB3202 to ignore issues with the .dcproj project
ENV RestoreUseSkipNonexistentTargets false
