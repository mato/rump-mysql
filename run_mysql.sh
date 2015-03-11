#!/bin/sh
set -x
rumprun xen -M 128 -i \
    -b images/stubetc.iso,/etc \
    -b images/data.ffs,/data \
    -n inet,static,10.9.1.200/22 \
    -- \
    build/mysql/build-cross/sql/mysqld \
        --defaults-file=/data/my.cnf --basedir=/data --user=daemon
