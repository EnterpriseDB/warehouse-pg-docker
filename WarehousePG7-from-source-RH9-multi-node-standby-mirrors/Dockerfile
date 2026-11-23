# syntax=docker/dockerfile:1

ARG GLOB_MAINTAINER="andreas.scherbaum@enterprisedb.com"
ARG GLOB_DESCRIPTION="Dockerfile to run WarehousePG 7.x from source-built RPMs"
ARG GLOB_IMAGE_TITLE="WarehousePG"
ARG GLOB_IMAGE_DESCRIPTION="WarehousePG Database image"
ARG GLOB_IMAGE_VERSION="0.1.1"
ARG GLOB_IMAGE_AUTHORS="andreas.scherbaum@enterprisedb.com"
ARG GLOB_WHPG_BUILD_DIR=/opt/warehousepg-build
ARG GLOB_WHPG_INSTALL_DIR=/usr/local/greenplum-db
ARG GLOB_WHPG_REPO_URL=https://github.com/warehouse-pg/warehouse-pg.git
ARG GLOB_WHPG_REPO_TAG=main
ARG GLOB_LOCAL_RPM_NAME=warehouse-pg-7
ARG GLOB_LOCAL_RPM_VERSION=7.0.0
ARG GLOB_LOCAL_RPM_RELEASE=0.1
ARG GLOB_COORDINATOR_DATA_DIRECTORY=/whpgdata/coordinator/whpgmne-1


FROM rockylinux:9 AS rpm-build-stage
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
ARG GLOB_WHPG_INSTALL_DIR
ARG GLOB_LOCAL_RPM_NAME
ARG GLOB_LOCAL_RPM_VERSION
ARG GLOB_LOCAL_RPM_RELEASE
ARG GLOB_COORDINATOR_DATA_DIRECTORY

LABEL maintainer=$GLOB_MAINTAINER
LABEL description=$GLOB_DESCRIPTION
LABEL org.opencontainers.image.title=$GLOB_IMAGE_TITLE
LABEL org.opencontainers.image.description=$GLOB_IMAGE_DESCRIPTION
LABEL org.opencontainers.image.version=$GLOB_BUILD_VERSION
LABEL org.opencontainers.image.authors=$GLOB_IMAGE_AUTHORS

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV WHPG_REPO_URL=$GLOB_WHPG_REPO_URL
ENV WHPG_REPO_TAG=$GLOB_WHPG_REPO_TAG
ENV WHPG_BUILD_DIR=$GLOB_WHPG_BUILD_DIR
ENV WHPG_INSTALL_DIR=$GLOB_WHPG_INSTALL_DIR
ENV LOCAL_RPM_NAME=$GLOB_LOCAL_RPM_NAME
ENV LOCAL_RPM_VERSION=$GLOB_LOCAL_RPM_VERSION
ENV LOCAL_RPM_RELEASE=$GLOB_LOCAL_RPM_RELEASE
ENV OS_NAME=$GLOB_OS_NAME
ENV OS_VERSION=$GLOB_OS_VERSION
ENV BUILD_VERSION=$GLOB_BUILD_VERSION
ENV COORDINATOR_DATA_DIRECTORY=$GLOB_COORDINATOR_DATA_DIRECTORY

RUN dnf update -y
RUN dnf groupinstall -y "Development Tools"
RUN dnf install -y epel-release
RUN dnf update -y

COPY rpm-packages-build-step.txt /root/rpm-packages-build-step.txt
RUN dnf install -y $(cat /root/rpm-packages-build-step.txt)
RUN dnf install -y --enablerepo=crb libyaml libyaml-devel libuv-devel perl-IPC-Run
RUN dnf clean all

RUN mkdir -p ${WHPG_BUILD_DIR} /opt/warehousepg-root /root/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} /whpg-rpms

WORKDIR ${WHPG_BUILD_DIR}
RUN git clone --branch ${WHPG_REPO_TAG} ${WHPG_REPO_URL} .
RUN git checkout ${WHPG_REPO_TAG}

RUN ./configure --enable-debug --with-perl --with-python --with-libxml --with-openssl --prefix=${WHPG_INSTALL_DIR} --enable-orca --enable-pxf && \
    make -j$(nproc) && \
    make install DESTDIR=/opt/warehousepg-root

RUN mkdir -p /tmp/${LOCAL_RPM_NAME}/usr/local && \
    cp -a /opt/warehousepg-root/usr/local/greenplum-db /tmp/${LOCAL_RPM_NAME}/usr/local/greenplum-db && \
    tar -C /tmp/${LOCAL_RPM_NAME} -czf /root/rpmbuild/SOURCES/${LOCAL_RPM_NAME}.tar.gz .

RUN cat <<EOF > /root/rpmbuild/SPECS/${LOCAL_RPM_NAME}.spec
%global debug_package %{nil}
%global _build_id_links none

Name:           ${LOCAL_RPM_NAME}
Version:        ${LOCAL_RPM_VERSION}
Release:        ${LOCAL_RPM_RELEASE}%{?dist}
Summary:        WarehousePG 7 built from source for Docker labs
License:        Apache-2.0
BuildArch:      x86_64
Source0:        %{name}.tar.gz
AutoReqProv:    yes

%description
Local WarehousePG RPM built from source for the multi-node Docker lab.

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
tar -xzf %{_sourcedir}/%{name}.tar.gz -C %{buildroot}

%files
%defattr(-,root,root,-)
/usr/local/greenplum-db

%changelog
* Fri Apr 18 2026 GitHub Copilot <copilot@github.com> - ${LOCAL_RPM_VERSION}-${LOCAL_RPM_RELEASE}
- Build WarehousePG from source and package it as a local RPM for Docker labs
EOF

RUN rpmbuild -bb /root/rpmbuild/SPECS/${LOCAL_RPM_NAME}.spec && \
    cp /root/rpmbuild/RPMS/x86_64/${LOCAL_RPM_NAME}-*.rpm /whpg-rpms/ && \
    createrepo_c /whpg-rpms


FROM rockylinux:9 AS image-stage
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
ARG GLOB_WHPG_INSTALL_DIR
ARG GLOB_LOCAL_RPM_NAME
ARG GLOB_COORDINATOR_DATA_DIRECTORY

LABEL maintainer=$GLOB_MAINTAINER
LABEL description=$GLOB_DESCRIPTION
LABEL org.opencontainers.image.title=$GLOB_IMAGE_TITLE
LABEL org.opencontainers.image.description=$GLOB_IMAGE_DESCRIPTION
LABEL org.opencontainers.image.version=$GLOB_BUILD_VERSION
LABEL org.opencontainers.image.authors=$GLOB_IMAGE_AUTHORS

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV WHPGHOME=$GLOB_WHPG_INSTALL_DIR
ENV LOCAL_RPM_NAME=$GLOB_LOCAL_RPM_NAME
ENV OS_NAME=$GLOB_OS_NAME
ENV OS_VERSION=$GLOB_OS_VERSION
ENV BUILD_VERSION=$GLOB_BUILD_VERSION
ENV COORDINATOR_DATA_DIRECTORY=$GLOB_COORDINATOR_DATA_DIRECTORY
ENV PATH=$WHPGHOME/bin:$PATH

RUN dnf update -y
RUN dnf install -y epel-release
RUN dnf update -y

COPY rpm-packages-image-step.txt /root/rpm-packages-image-step.txt
RUN dnf install -y $(cat /root/rpm-packages-image-step.txt)
RUN dnf install -y --enablerepo=crb libyaml libyaml-devel libuv-devel perl-IPC-Run

COPY --from=rpm-build-stage /whpg-rpms /root/rpm-downloads
RUN cat <<EOF > /etc/yum.repos.d/local-rpms.repo
[local-rpms]
name=Local RPMs
baseurl=file:///root/rpm-downloads
enabled=1
gpgcheck=0
EOF
RUN dnf install -y ${LOCAL_RPM_NAME} && \
    rm -f /etc/yum.repos.d/local-rpms.repo && \
    dnf clean all

RUN groupadd gpadmin
RUN useradd -m -d /home/gpadmin -s /bin/bash -c "WarehousePG Database" -g gpadmin gpadmin
RUN echo "gpadmin ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo
RUN echo "gpadmin:whpg5432" | chpasswd
RUN echo "root:whpg5432" | chpasswd

EXPOSE 22/tcp
EXPOSE 5432/tcp
EXPOSE 6000-6010/tcp
EXPOSE 7000-7010/tcp
EXPOSE 8000-8010/tcp
EXPOSE 9000-9010/tcp
EXPOSE 30000-30010/tcp

USER gpadmin

RUN sudo bash -c ". ${WHPGHOME}/greenplum_path.sh && pip3 install psycopg2 psutil"

RUN sudo mkdir -p /whpgdata/coordinator /whpgdata/segments /whpgdata/segments/whpgdata1 /whpgdata/segments/whpgdata2 /whpgdata/mirrors /whpgdata/mirrors/whpgdata1 /whpgdata/mirrors/whpgdata2 && \
    sudo chown -R gpadmin:gpadmin /whpgdata

COPY --chown=gpadmin:gpadmin hostfile_whpginitsystem7 /home/gpadmin/hostfile_whpginitsystem
COPY --chown=gpadmin:gpadmin hostfile_segments_whpginitsystem7 /home/gpadmin/hostfile_segments_whpginitsystem
COPY --chown=gpadmin:gpadmin hostfile_ssh_whpginitsystem7 /home/gpadmin/hostfile_ssh_whpginitsystem
COPY --chown=gpadmin:gpadmin whpginitsystem_multinode7 /home/gpadmin/whpginitsystem_multinode
COPY --chown=gpadmin:gpadmin --chmod=0750 warehousepg_init7.sh /home/gpadmin/warehousepg_init.sh
COPY --chown=gpadmin:gpadmin --chmod=0755 list-seg-ports.sh /home/gpadmin/list-seg-ports.sh
COPY --chown=gpadmin:gpadmin --chmod=0750 cmd.sh /home/gpadmin/cmd.sh
WORKDIR /home/gpadmin

CMD ["/home/gpadmin/cmd.sh"]
