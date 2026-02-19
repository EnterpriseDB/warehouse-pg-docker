# WarehousePG Training

The `WarehousePG7-from-RPMs-single-node-not-installed` lab is prepared to install your own *WarehousePG*.

## How to build

Change into the directory:

```
cd WarehousePG7-from-RPMs-single-node-not-installed
```

Build the lab:

```
make build
```

Start the Docker Compose container:

```
make run
```

Observe the Docker logfile:

```
make logs
```

Exit the log with: `Ctrl+c`.

## How to use

Enter the Docker container:

```
make access
```

This drops into a shell in the container. The shell history is primed with common commands. Type `history` to see the list.

The container has a pre-filled in init file, and a hostfile, ready to go:

```
ls

cmd.sh  hostfile_whpginitsystem  warehousepg_init.sh  whpginitsystem_singlenode
```

Edit `whpginitsystem_singlenode` as you need.

The RPM packages are available in `/root/rpm-downloads` (for the `root` user).

## Install the WarehousePG software

Become `root` first: `sudo /bin/bash --login`. Create a repository from the `/root/rpm-downloads` directory:

```
createrepo /root/rpm-downloads
```

```
cat <<EOF > /etc/yum.repos.d/local-rpms.repo
[local-rpms]
name=Local RPMs
baseurl=file:///root/rpm-downloads
enabled=1
gpgcheck=0
EOF
```

```
dnf install warehouse-pg-7 warehouse-pg-clients --enablerepo=local-rpms
```

```
dnf config-manager --disable local-rpms
```

```
ls -ld /usr/local/greenplum*
```

The software is now installed. Create the data directories:

```
mkdir -p /whpgdata/coordinator /whpgdata/segments/whpgdata1 /whpgdata/segments/whpgdata2
chown -R gpadmin:gpadmin /whpgdata
```

And start sshd (required):

```
rm -f /run/nologin
mkdir -p /run/sshd
ssh-keygen -A -v
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
/usr/sbin/sshd -o "ListenAddress=0.0.0.0"
```

Exit the root shell (with `Ctrl+d`), you are back on the `gpadmin` shell.

## Configure the WarehousePG database

First generate a ssh key:


```
ssh-keygen -q -t rsa -b 2048 -f /home/gpadmin/.ssh/id_rsa -N ""
cat /home/gpadmin/.ssh/id_rsa.pub >> /home/gpadmin/.ssh/authorized_keys
chmod 0700 /home/gpadmin
chmod 0600 /home/gpadmin/.ssh/authorized_keys
chmod 0644 /home/gpadmin/.ssh/id_rsa.pub
chmod 0600 /home/gpadmin/.ssh/id_rsa
ssh-keyscan 127.0.0.1 >> /home/gpadmin/.ssh/known_hosts
ssh-keyscan `hostname` >> /home/gpadmin/.ssh/known_hosts
ssh 127.0.0.1 hostname
```

The above steps ensure that password-less login is possible.


Now source the `greenplum_path.sh` file:

```
source /usr/local/greenplum-db/greenplum_path.sh
```

Use the current hostname:

```
hostname > /home/gpadmin/hostfile_whpginitsystem

cat /home/gpadmin/whpginitsystem_singlenode
```

And finally run `gpinitsystem`:

```
gpinitsystem -c /home/gpadmin/whpginitsystem_singlenode -m 100
```

Start the database:

```
echo $COORDINATOR_DATA_DIRECTORY
gpstate -a

gpstop -a -M fast

gpstart -a

gpstop -r -M fast -a
```

Connect to the database:

```
psql whpgtest
```

You can modify any step, and especially the file `whpginitsystem_singlenode` and try out different options.

## Stop the container

Type in:

```
make clean
```

This stops the container, and removes all data. You can start over fresh.
