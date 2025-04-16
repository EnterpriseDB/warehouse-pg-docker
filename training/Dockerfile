FROM rockylinux/rockylinux:8


ENV container=docker

RUN dnf update -y && \
    dnf install -y systemd \
                   systemd-libs && \
    dnf clean all

RUN     echo root:changeme@123 | chpasswd && \
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
#RUN dnf -y install warehouse-pg-6

COPY gpinitsystem_config /tmp/
COPY hostfile /tmp/
COPY init_system.sh /tmp/
COPY training.sh /tmp


RUN     echo "mdw" > /tmp/gpdb-hosts && \
        echo "/usr/local/lib" >> /etc/ld.so.conf && \
        echo "/usr/local/lib64" >> /etc/ld.so.conf && \
        ldconfig && \
        chmod 777 /tmp/gpinitsystem_config && \
        chmod 777 /tmp/hostfile && \
        chmod 777 /tmp/init_system.sh && \
        chmod +x /tmp/training.sh && \
        hostname > ~/orig_hostname && \
        setcap cap_net_raw+ep /usr/bin/ping && \
        ssh-keygen -A && \
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config


# ----------------------------------------------------------------------
# Set the Default User and Command
# ----------------------------------------------------------------------
# The default user is set to 'gpadmin', and the container starts by
# running the init_system.sh script.
# ----------------------------------------------------------------------
#USER gpadmin
#ENV USER=gpadmin
WORKDIR /tmp

EXPOSE 5555 22


#VOLUME [ "/sys/fs/cgroup" ]
CMD ["bash","-c","/tmp/init_system.sh"]