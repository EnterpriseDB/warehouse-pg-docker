#!/bin/bash

netstat -pan 2> /dev/null | grep postgres | grep 0.0.0.0:60 | awk '{print $4;}' | cut -f2 -d: | sort | xargs
