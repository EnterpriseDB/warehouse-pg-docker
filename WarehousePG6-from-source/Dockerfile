# syntax=docker/dockerfile:1

# define arguments as global variables
# ENV settings are scoped locally per build stage, by design
ARG GLOB_MAINTAINER="andreas.scherbaum@enterprisedb.com"
ARG GLOB_DESCRIPTION="Dockerfile to run WarehousePG 6.x"
ARG GLOB_IMAGE_TITLE="WarehousePG"
ARG GLOB_IMAGE_DESCRIPTION="WarehousePG Database image"
ARG GLOB_IMAGE_VERSION="0.1.1"
ARG GLOB_IMAGE_AUTHORS="andreas.scherbaum@enterprisedb.com"
ARG GLOB_WHPG_BUILD_DIR=/opt/warehousepg-build
ARG GLOB_WHPG_INSTALL_DIR_PARENT=/usr/local
ARG GLOB_WHPG_INSTALL_DIR_NAME=greenplum-db
ARG GLOB_WHPG_INSTALL_DIR=$GLOB_WHPG_INSTALL_DIR_PARENT/$GLOB_WHPG_INSTALL_DIR_NAME
ARG GLOB_WHPGHOME=${GLOB_WHPG_INSTALL_DIR}
ARG GLOB_MASTER_DATA_DIRECTORY=/whpgdata/master/whpgsne-1
ARG GLOB_WHPG_REPO_URL=https://github.com/warehouse-pg/warehouse-pg.git
ARG GLOB_WHPG_REPO_TAG=WHPG_6X_STABLE


#######################################################################
# use CentOS Linux as base image
FROM centos:7 AS build-stage
ENV container=docker

ARG GLOB_MAINTAINER
ARG GLOB_DESCRIPTION
ARG GLOB_IMAGE_TITLE
ARG GLOB_IMAGE_DESCRIPTION
ARG GLOB_IMAGE_VERSION
ARG GLOB_IMAGE_AUTHORS
ARG GLOB_OS_NAME
ARG GLOB_OS_VERSION
ARG GLOB_BUILD_VERSION
ARG GLOB_WHPG_REPO_URL
ARG GLOB_WHPG_REPO_TAG
ARG GLOB_WHPG_BUILD_DIR
ARG GLOB_WHPG_INSTALL_DIR_PARENT
ARG GLOB_WHPG_INSTALL_DIR_NAME
ARG GLOB_WHPG_INSTALL_DIR
ARG GLOB_WHPGHOME
#ARG LD_LIBRARY_PATH
ARG GLOB_MASTER_DATA_DIRECTORY

# metadata
LABEL maintainer=$GLOB_MAINTAINER
LABEL description=$GLOB_DESCRIPTION
LABEL org.opencontainers.image.title=$GLOB_IMAGE_TITLE
LABEL org.opencontainers.image.description=$GLOB_IMAGE_DESCRIPTION
LABEL org.opencontainers.image.version=$GLOB_BUILD_VERSION
LABEL org.opencontainers.image.authors=$GLOB_IMAGE_AUTHORS


# set environment variables
# start with C locale here, change to US later
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
# configure environment for WarehousePG
ENV WHPG_REPO_URL=$GLOB_WHPG_REPO_URL
ENV WHPG_REPO_TAG=$GLOB_WHPG_REPO_TAG
ENV WHPG_BUILD_DIR=$GLOB_WHPG_BUILD_DIR
ENV WHPG_INSTALL_DIR_PARENT=$GLOB_WHPG_INSTALL_DIR_PARENT
ENV WHPG_INSTALL_DIR_NAME=$GLOB_WHPG_INSTALL_DIR_NAME
ENV WHPG_INSTALL_DIR=$GLOB_WHPG_INSTALL_DIR
ENV OS_NAME=$GLOB_OS_NAME
ENV OS_VERSION=$GLOB_OS_VERSION
ENV BUILD_VERSION=$GLOB_BUILD_VERSION
ENV WHPGHOME=$GLOB_WHPGHOME
#ENV LD_LIBRARY_PATH=$WHPGHOME/lib:$LD_LIBRARY_PATH
ENV MASTER_DATA_DIRECTORY=$GLOB_MASTER_DATA_DIRECTORY
ENV PATH=$WHPGHOME/bin:$PATH


RUN sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
RUN sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
RUN sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

# install required packages for building WarehousePG
#RUN localectl set-locale LANG=en_US.UTF-8
RUN yum update -y
RUN yum install -y centos-release-scl

RUN sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
RUN sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
RUN sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

RUN yum update -y
RUN yum install -y devtoolset-7
RUN yum groupinstall -y "Development Tools"
RUN yum install -y epel-release
RUN yum update -y

COPY rpm-packages-build-step.txt /root/rpm-packages-build-step.txt
RUN yum install -y $(cat /root/rpm-packages-build-step.txt)

RUN yum clean all

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8


# add gpadmin user for building the database
RUN groupadd gpadmin
RUN useradd -m -d /home/gpadmin -s /bin/bash -c "WarehousePG Database" -g gpadmin gpadmin
RUN echo "gpadmin ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo
RUN mkdir ${WHPG_BUILD_DIR} ${WHPG_INSTALL_DIR} && chown gpadmin:gpadmin ${WHPG_BUILD_DIR} ${WHPG_INSTALL_DIR}


# switch to gpadmin user, do not build as root
USER gpadmin


# clone WarehousePG repository
WORKDIR ${WHPG_BUILD_DIR}
RUN git clone --branch ${WHPG_REPO_TAG} ${WHPG_REPO_URL} .
RUN git checkout ${WHPG_REPO_TAG}

# build WarehousePG Database from source
#RUN ./configure --enable-debug --with-perl --with-python --with-libxml --with-openssl --prefix=${WHPG_INSTALL_DIR} --enable-orca --enable-pxf
RUN . /opt/rh/devtoolset-7/enable ; ./configure --enable-debug --with-perl --with-python --with-libxml --with-openssl --prefix=${WHPG_INSTALL_DIR} --enable-orca --enable-pxf --with-uuid=e2fs --enable-cassert --disable-gpperfmon --with-gssapi --with-pam --with-ldap && make -j$(nproc)


# this does NOT work in the build stage
#RUN make check

RUN sudo make install
#RUN sudo make distclean


RUN sudo bash -c "curl https://bootstrap.pypa.io/pip/2.7/get-pip.py | python"

RUN sudo bash -c ". ${WHPGHOME}/greenplum_path.sh && pip install psycopg2"
RUN sudo bash -c ". ${WHPGHOME}/greenplum_path.sh && pip install psutil"


#######################################################################
# database installed, but not started
# build a new image, without the sources
FROM centos:7 AS image-stage
ENV container=docker

ARG GLOB_MAINTAINER
ARG GLOB_DESCRIPTION
ARG GLOB_IMAGE_TITLE
ARG GLOB_IMAGE_DESCRIPTION
ARG GLOB_IMAGE_VERSION
ARG GLOB_IMAGE_AUTHORS
ARG GLOB_OS_NAME
ARG GLOB_OS_VERSION
ARG GLOB_BUILD_VERSION
ARG GLOB_WHPG_REPO_URL
ARG GLOB_WHPG_REPO_TAG
ARG GLOB_WHPG_BUILD_DIR
ARG GLOB_WHPG_INSTALL_DIR_PARENT
ARG GLOB_WHPG_INSTALL_DIR_NAME
ARG GLOB_WHPG_INSTALL_DIR
ARG GLOB_WHPGHOME
#ARG LD_LIBRARY_PATH
ARG GLOB_MASTER_DATA_DIRECTORY

# metadata
LABEL maintainer=$GLOB_MAINTAINER
LABEL description=$GLOB_DESCRIPTION
LABEL org.opencontainers.image.title=$GLOB_IMAGE_TITLE
LABEL org.opencontainers.image.description=$GLOB_IMAGE_DESCRIPTION
LABEL org.opencontainers.image.version=$GLOB_BUILD_VERSION
LABEL org.opencontainers.image.authors=$GLOB_IMAGE_AUTHORS

# set environment variables
# start with C locale here, change to US later
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
# configure environment for WarehousePG
ENV WHPG_REPO_URL=$GLOB_WHPG_REPO_URL
ENV WHPG_REPO_TAG=$GLOB_WHPG_REPO_TAG
ENV WHPG_BUILD_DIR=$GLOB_WHPG_BUILD_DIR
ENV WHPG_INSTALL_DIR_PARENT=$GLOB_WHPG_INSTALL_DIR_PARENT
ENV WHPG_INSTALL_DIR_NAME=$GLOB_WHPG_INSTALL_DIR_NAME
ENV WHPG_INSTALL_DIR=$GLOB_WHPG_INSTALL_DIR
ENV OS_NAME=$GLOB_OS_NAME
ENV OS_VERSION=$GLOB_OS_VERSION
ENV BUILD_VERSION=$GLOB_BUILD_VERSION
ENV WHPGHOME=$GLOB_WHPGHOME
#ENV LD_LIBRARY_PATH=$WHPGHOME/lib:$LD_LIBRARY_PATH
ENV MASTER_DATA_DIRECTORY=$GLOB_MASTER_DATA_DIRECTORY
ENV PATH=$WHPGHOME/bin:$PATH

RUN sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
RUN sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
RUN sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

# install required packages for running WarehousePG
#RUN localectl set-locale LANG=en_US.UTF-8
RUN yum update -y
RUN yum install -y epel-release
RUN yum update -y

COPY rpm-packages-image-step.txt /root/rpm-packages-image-step.txt
RUN yum install -y $(cat /root/rpm-packages-image-step.txt)

RUN yum clean all

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8


# add WarehousePG user for building and running the database
RUN groupadd gpadmin
RUN useradd -m -d /home/gpadmin -s /bin/bash -c "WarehousePG Database" -g gpadmin gpadmin
RUN echo "gpadmin ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo


# expose ports
EXPOSE 22/tcp
EXPOSE 5432/tcp
EXPOSE 6000-6010/tcp
EXPOSE 7000-7010/tcp
EXPOSE 8000-8010/tcp
EXPOSE 9000-9010/tcp
EXPOSE 30000-30010/tcp


# copy installation over from the build stage image
RUN rm -rf ${WHPG_INSTALL_DIR_PARENT}/*
COPY --from=build-stage ${WHPG_INSTALL_DIR_PARENT} ${WHPG_INSTALL_DIR_PARENT}


# switch to gpadmin user, do not build image as root
USER gpadmin

# Create data directories
RUN sudo mkdir -p /whpgdata/master /whpgdata/segments /whpgdata/segments/whpgdata1 /whpgdata/segments/whpgdata2 && \
    sudo chown -R gpadmin:gpadmin /whpgdata


COPY --chown=gpadmin:gpadmin hostfile_whpginitsystem6 /home/gpadmin/hostfile_whpginitsystem
COPY --chown=gpadmin:gpadmin whpginitsystem_singlenode6 /home/gpadmin/whpginitsystem_singlenode
# the chmod option needs buildx
COPY --chown=gpadmin:gpadmin --chmod=0750 warehousepg_init6.sh /home/gpadmin/warehousepg_init.sh
COPY --chown=gpadmin:gpadmin --chmod=0750 cmd.sh /home/gpadmin/cmd.sh
WORKDIR /home/gpadmin


#CMD ["bash"]
#CMD ["tail", "-f", "/dev/null"]
CMD ["/home/gpadmin/cmd.sh"]
