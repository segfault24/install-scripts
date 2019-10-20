#!/bin/sh
PATH=/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export PATH

cd $(dirname $0)
mapcrafter -b -c mapper.conf -j 1
mapcrafter_markers -c mapper.conf
