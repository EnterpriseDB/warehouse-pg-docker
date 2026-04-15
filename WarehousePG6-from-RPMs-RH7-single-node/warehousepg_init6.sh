#!/bin/bash

# source the environment passed on from CMD
. $1
cd /home/gpadmin

if [ ! -f '/whpgdata/master/whpgseg-1/postgresql.conf' ];
then
    gpinitsystem -c /home/gpadmin/whpginitsystem_singlenode
fi
