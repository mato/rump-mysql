#!/bin/sh
set -x
rumprun xen -M 128 -i \
    -b images/stubetc.iso,/etc \
    -b images/data.ffs,/data \
    -n inet,static,10.9.1.200/22 \
    -- \
    build/mysql/build-cross/sql/mysqld -b /data -h mysql -u daemon \
    --default-storage-engine=myisam \
    --default-tmp-storage-engine=myisam

