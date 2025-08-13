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
                       xerces-c-devel && \
        dnf install -y postfix \
                       bind-utils \
                       telnet


RUN --mount=type=secret,id=repo_token \
   sh -c 'TOKEN=$(cat /run/secrets/repo_token) && echo "Token is: $TOKEN"'



#Sets-up the Cloudsmith dev repo
RUN --mount=type=secret,id=repo_token bash -c 'curl -1Lf https://downloads.enterprisedb.com/$(cat /run/secrets/repo_token)/gpsupp/setup.rpm.sh | sudo bash'

# ------------------------
# Install WHPG and PXF
# ------------------------
RUN dnf -y install warehouse-pg-6 edb-whpg6-pxf


COPY gpinitsystem_singlenode /tmp/
COPY init_system.sh /tmp/



#COPY ./os_pxf_rpm/pxf-gp6-6.10.1-SNAPSHOT.el8.x86_64.rpm /tmp/
#RUN dnf -y install /tmp/pxf-gp6-6.10.1-SNAPSHOT.el8.x86_64.rpm

RUN     echo "mdw" > /tmp/gpdb-hosts && \
        echo "/usr/local/lib" >> /etc/ld.so.conf && \
        echo "/usr/local/lib64" >> /etc/ld.so.conf && \
        ldconfig && \
        chmod 777 /tmp/gpinitsystem_singlenode && \
        chmod 777 /tmp/init_system.sh && \
        hostname > ~/orig_hostname && \
        /usr/sbin/groupadd gpadmin && \
        /usr/sbin/useradd  gpadmin -g gpadmin -G wheel && \
        /usr/sbin/groupadd hadoop && \
        /usr/sbin/useradd  hadoop -g hadoop -G wheel && \
        /usr/sbin/groupadd supergroup && \
        /usr/sbin/usermod -aG supergroup gpadmin && \
        setcap cap_net_raw+ep /usr/bin/ping && \
        echo "changeme@123"|passwd --stdin gpadmin && \
        echo "changeme@123"|passwd --stdin hadoop && \
        echo "gpadmin        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers && \
        echo "hadoop        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers && \
        echo "root           ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers && \
        echo "export MASTER_DATA_DIRECTORY=/data/master/gpseg-1" >> /home/gpadmin/.bashrc && \
        echo "source /usr/local/greenplum-db/greenplum_path.sh"                >> /home/gpadmin/.bashrc && \
        chown -R gpadmin:gpadmin /usr/local/edb-whpg6-pxf && \
        echo "export PXF_BASE=/home/gpadmin/pxf-base" >> /home/gpadmin/.bashrc && \
        echo "export PXF_HOME=/usr/local/edb-whpg6-pxf" >> /home/gpadmin/.bashrc && \
        echo "export PATH=/usr/local/edb-whpg6-pxf/bin:$PATH" >> /home/gpadmin/.bashrc && \
        sudo chown -R gpadmin:gpadmin /usr/local/greenplum-db-6.27.1/ && \
        mkdir -p /data/master /data/primary /data/mirror && \
        chown -R gpadmin:gpadmin /data && \
        ssh-keygen -A && \
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config


RUN sudo dnf -y install java-1.8.0-openjdk-devel && \
    echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk/jre/" >> /home/gpadmin/.bashrc

# ------------------------
# Install Hadoop 3.3.6
# ------------------------

COPY ./config/hadoop/core-site.xml /tmp
COPY ./config/hive/hive-site.xml /tmp

ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

RUN echo "export HADOOP_HOME=/opt/hadoop" >> home/hadoop/.bashrc && \
    echo "PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH" >> home/hadoop/.bashrc

RUN wget https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} $HADOOP_HOME && \
    rm -f hadoop-${HADOOP_VERSION}.tar.gz && \
    chown -R hadoop:hadoop /opt/hadoop/ && \
    cp /tmp/core-site.xml /opt/hadoop/etc/hadoop && \
    chown hadoop:hadoop /opt/hadoop/etc/hadoop/core-site.xml

# Set JAVA_HOME in Hadoop env
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

USER hadoop

RUN mkdir -p /home/hadoop/.ssh && \
    chmod 700 /home/hadoop/.ssh && \
    ssh-keygen -t rsa -b 4096 -C hadoop -f /home/hadoop/.ssh/id_rsa -P "" > /dev/null 2>&1 && \
    cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys && \
    chmod 600 /home/hadoop/.ssh/authorized_keys

RUN $HADOOP_HOME/bin/hdfs namenode -format -nonInteractive


# ------------------------
# Setup Hive
# ------------------------

USER root

ENV HIVE_VERSION=3.1.3
ENV HIVE_HOME=/opt/hive
ENV PATH=$HIVE_HOME/bin:$PATH

RUN wget https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz && \
    tar -xzf apache-hive-${HIVE_VERSION}-bin.tar.gz -C /opt && \
    sudo mv /opt/apache-hive-${HIVE_VERSION}-bin $HIVE_HOME && \
    chown -R hadoop:hadoop /opt/hive

RUN echo "export HIVE_HOME=/opt/hive" >> home/hadoop/.bashrc && \
    echo "export PATH=$HIVE_HOME/bin:$PATH" >> home/hadoop/.bashrc


RUN cp ./tmp/hive-site.xml $HIVE_HOME/conf/


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