#!/bin/bash

# source the environment passed on from CMD
. $1
cd /home/gpadmin

if [ ! -f '/whpgdata/coordinator/whpgseg-1/postgresql.conf' ];
then
    gpinitsystem -c /home/gpadmin/whpginitsystem_multinode
fi
