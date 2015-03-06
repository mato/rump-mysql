#!/bin/sh
#
# Start mysqld for bootstrapping.
#
rumprun xen -M 128 -i \
    -b images/stubetc.iso,/etc \
    -b images/share.iso,/share \
    -- \
    build/mysql/build-cross/sql/mysqld -b / -h / -u daemon \
    --default-storage-engine=myisam \
    --default-tmp-storage-engine=myisam \
    --bootstrap

