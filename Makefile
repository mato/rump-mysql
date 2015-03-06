#
# Cross-build script for MySQL on rumprun-xen
#
all: mysql images

.PHONY: mysql
mysql: build/mysql_cross_build_stamp

#
# 1. Extract mysql distribution tarball
#
build/mysql_extract_stamp: dist/mysql-5.6.23.tar.gz
	mkdir -p build/mysql
	tar -C build/mysql --strip=1 -xzf $<
	touch $@

#
# 2. Patches:
#
# CMakeLists.txt - there is no way to disable MySQL use of libreadline and we
# don't need it as we are only building the server.
#
# my_global.h - broken logic tries to define __func__ even though this is
# already provided.
#
build/mysql_patch_stamp: CMakeLists.txt.patch build/mysql_extract_stamp
	( cd build/mysql; patch -p0 < ../../CMakeLists.txt.patch )
	( cd build/mysql; patch -p0 < ../../my_global.h.patch )
	touch $@

#
# 3. Build native binaries used by cross-build.
#
NATIVE_DIR=$(abspath build/mysql/build-native)
build/mysql_native_stamp: build/mysql_patch_stamp
	mkdir $(NATIVE_DIR) || true
	cd $(NATIVE_DIR) i&& cmake \
	    -DWITH_SSL=system \
	    -DWITH_ZLIB=system \
	    -DDISABLE_SHARED=ON \
	    -DFEATURE_SET=small \
	    ..
	$(MAKE) -C $(NATIVE_DIR)/sql gen_lex_hash
	$(MAKE) -C $(NATIVE_DIR)/scripts comp_sql
	$(MAKE) -C $(NATIVE_DIR)/extra comp_err
	$(MAKE) -C $(NATIVE_DIR)/storage/perfschema gen_pfs_lex_token
	mkdir $(NATIVE_DIR)/bin || true
	cp $(NATIVE_DIR)/sql/gen_lex_hash \
	    $(NATIVE_DIR)/scripts/comp_sql \
	    $(NATIVE_DIR)/extra/comp_err \
	    $(NATIVE_DIR)/storage/perfschema/gen_pfs_lex_token \
	    $(NATIVE_DIR)/bin/
	touch $@

#
# 4. Cross-build mysqld (CMake step)
#
CROSS_DIR=$(abspath build/mysql/build-cross)
# TODO: Detect where app-tools are installed.
RUMP_ROOT=/home/mato/projects/rumpkernel/rumprun/rump
build/mysql_cross_cmake_stamp: build/mysql_native_stamp
	mkdir $(CROSS_DIR) || true
	cd $(CROSS_DIR) && cmake \
	    -C $(PWD)/CachePreseed.cmake \
	    -DRUMP_ROOT=$(RUMP_ROOT) \
	    -DCMAKE_TOOLCHAIN_FILE=$(PWD)/Toolchain.cmake \
	    -DSTACK_DIRECTION=-1 \
	    -DDISABLE_SHARED=ON \
	    -DWITH_ZLIB=system \
	    -DWITH_SSL=system \
	    -DFEATURE_SET=small \
	    ..
	touch $@

#
# 5. Cross-build mysqld (build step)
#
build/mysql_cross_build_stamp: build/mysql_cross_cmake_stamp
	export PATH=$(NATIVE_DIR)/bin:$$PATH; \
	$(MAKE) -C $(CROSS_DIR) mysqld
	touch $@

#
# Disk images
#
.PHONY: images
images: mysql
	genisoimage -l -r -o images/stubetc.iso images/stubetc
	mkdir -p images/share || true
	cp -f build/mysql/build-cross/sql/share/english/errmsg.sys images/share/errmsg.sys
	genisoimage -l -r -o images/share.iso images/share

.PHONY: clean
clean:
	rm -rf build
