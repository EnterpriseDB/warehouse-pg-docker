FROM ghcr.io/warehouse-pg/whpg7-rocky8-build:latest


RUN dnf install -y \
    gcc \
    postgresql-devel \
    python3-devel

RUN pip3 install psycopg2

COPY init_system.sh /tmp/

RUN chmod 777 /tmp/init_system.sh

RUN echo "source /usr/local/greenplum-db/greenplum_path.sh" >> /home/gpadmin/.bashrc && \
    echo "source /tmp/warehouse-pg/gpAux/gpdemo/gpdemo-env.sh" >> /home/gpadmin/.bashrc

    
RUN cd /tmp/ && git clone --branch main --single-branch --depth=1 https://github.com/warehouse-pg/warehouse-pg.git

RUN cd /tmp/warehouse-pg && \
       ./configure --prefix=/usr/local/greenplum-db \
                --enable-depend \
                --with-python \
                --enable-orca 

RUN cd /tmp/warehouse-pg && make -j8 && make install

# ----------------------------------------------------------------------
# Set the Default User and Command
# ----------------------------------------------------------------------
# The default user is set to 'gpadmin', and the container starts by
# running the init_system.sh script.
# ----------------------------------------------------------------------
USER gpadmin
ENV USER=gpadmin
WORKDIR /home/gpadmin

CMD ["bash","-c","/tmp/init_system.sh"]