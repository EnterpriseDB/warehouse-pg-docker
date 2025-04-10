FROM rockylinux/rockylinux:8


ENV container=docker

RUN dnf update -y && \
    dnf install -y systemd \
                   systemd-libs && \
    dnf clean all

RUN     echo root:admin@123 | chpasswd && \
        dnf makecache && \
        dnf install -y yum-utils \
                       epel-release \
                       git && \
        dnf makecache && \
        yum-config-manager --disable epel && \
        dnf install -y --enablerepo=epel \
                       the_silver_searcher \
                       bat \
                       htop && \
        dnf install -y bison \
                       cmake3 \
                       ed \
                       flex \
                       gcc \
                       gcc-c++ \
                       glibc-langpack-en \
                       go \
                       initscripts \
                       iproute \
                       less \
                       m4 \
                       net-tools \
                       openssh-clients \
                       openssh-server \
                       passwd \
                       perl \
                       rsync \
                       sudo \
                       tar \
                       unzip \
                       util-linux-ng \
                       wget \
                       sshpass \
                       which && \
        dnf install -y apr-devel \
                       bzip2-devel \
                       krb5-devel \
                       libcurl-devel \
                       libevent-devel \
                       libxml2-devel \
                       libzstd-devel \
                       openldap-devel \
                       openssl-devel \
                       pam-devel \
                       perl-ExtUtils-Embed \
                       perl-Test-Simple \
                       perl-core \
                       readline-devel \
                       zlib-devel && \
        dnf install -y --enablerepo=epel \
                       xerces-c-devel


#Sets-up the Cloudsmith dev repo
RUN --mount=type=secret,id=EDB_REPO_TOKEN curl -1Lf https://downloads.enterprisedb.com/$(cat /run/secrets/EDB_REPO_TOKEN)/gpsupp/setup.rpm.sh | sudo bash

# Installs the WarehousePG Binary
RUN dnf -y install warehouse-pg-6

COPY gpinitsystem_singlenode /tmp/
COPY init_system.sh /tmp/


RUN     echo "mdw" > /tmp/gpdb-hosts && \
        echo "/usr/local/lib" >> /etc/ld.so.conf && \
        echo "/usr/local/lib64" >> /etc/ld.so.conf && \
        ldconfig && \
        chmod 777 /tmp/gpinitsystem_singlenode && \
        chmod 777 /tmp/init_system.sh && \
        hostname > ~/orig_hostname && \
        /usr/sbin/groupadd gpadmin && \
        /usr/sbin/useradd  gpadmin -g gpadmin -G wheel && \
        setcap cap_net_raw+ep /usr/bin/ping && \
        echo "changeme@123"|passwd --stdin gpadmin && \
        echo "gpadmin        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers && \
        echo "root           ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers && \
        echo "export MASTER_DATA_DIRECTORY=/data/master/gpseg-1" >> /home/gpadmin/.bashrc && \
        echo "source /usr/local/greenplum-db/greenplum_path.sh"                >> /home/gpadmin/.bashrc && \
        mkdir -p /data/master /data/primary /data/mirror && \
        chown -R gpadmin:gpadmin /data && \
        ssh-keygen -A && \
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config


# ----------------------------------------------------------------------
# Set the Default User and Command
# ----------------------------------------------------------------------
# The default user is set to 'gpadmin', and the container starts by
# running the init_system.sh script.
# ----------------------------------------------------------------------
USER gpadmin
ENV USER=gpadmin
WORKDIR /home/gpadmin

EXPOSE 5432 22


#VOLUME [ "/sys/fs/cgroup" ]
CMD ["bash","-c","/tmp/init_system.sh"]