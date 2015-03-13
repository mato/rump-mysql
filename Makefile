#
# Cross-build script for MySQL on rumprun-xen
#
all: mysql images

mysql: build/mysql_cross_build_stamp

#
# 1. Extract mysql distribution tarball
#
BUILD_DIR=$(abspath build/mysql)
build/mysql_extract_stamp: dist/mysql-5.6.23.tar.gz
	mkdir -p $(BUILD_DIR)
	tar -C $(BUILD_DIR) --strip=1 -xzf $<
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
	( cd $(BUILD_DIR); patch -p0 < ../../CMakeLists.txt.patch )
	( cd $(BUILD_DIR); patch -p0 < ../../my_global.h.patch )
	touch $@

#
# 3. Build native binaries used by cross-build and bootstrap.
#
NATIVE_DIR=$(abspath $(BUILD_DIR)/build-native)
build/mysql_native_stamp: build/mysql_patch_stamp
	mkdir $(NATIVE_DIR) || true
	cd $(NATIVE_DIR) && cmake \
	    -DWITH_SSL=system \
	    -DWITH_ZLIB=system \
	    -DDISABLE_SHARED=ON \
	    -DFEATURE_SET=small \
	    -DWITHOUT_PERFSCHEMA_STORAGE_ENGINE=1 \
	    ..
	$(MAKE) -C $(NATIVE_DIR)/sql gen_lex_hash
	$(MAKE) -C $(NATIVE_DIR)/scripts
	$(MAKE) -C $(NATIVE_DIR)/extra
	$(MAKE) -C $(NATIVE_DIR) mysqld
	mkdir $(NATIVE_DIR)/bin || true
	cp $(NATIVE_DIR)/sql/gen_lex_hash \
	    $(NATIVE_DIR)/scripts/comp_sql \
	    $(NATIVE_DIR)/extra/comp_err \
	    $(NATIVE_DIR)/bin/
	touch $@

#
# 4. Cross-build mysqld (CMake step)
#
CROSS_DIR=$(abspath $(BUILD_DIR)/build-cross)
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
	    -DWITHOUT_PERFSCHEMA_STORAGE_ENGINE=1 \
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
# 6. Bootstrap MySQL server using the native mysqld.
#
DATA_DIR=$(abspath images/data)
images/data: build/mysql_native_stamp
	mkdir -p $(DATA_DIR) $(DATA_DIR)/share|| true
	cp -f my.cnf $(DATA_DIR)
	cp -rf $(NATIVE_DIR)/sql/share/english $(DATA_DIR)/share
	perl $(NATIVE_DIR)/scripts/mysql_install_db \
	    --defaults-file=$(DATA_DIR)/my.cnf \
	    --builddir=$(NATIVE_DIR) \
	    --srcdir=$(BUILD_DIR) \
	    --datadir=$(DATA_DIR)/mysql \
	    --lc-messages-dir=$(DATA_DIR)/share \
	    --cross-bootstrap
	cat mysql_rump_bootstrap.sql | \
	    $(NATIVE_DIR)/sql/mysqld \
	    --defaults-file=$(DATA_DIR)/my.cnf \
	    --basedir=$(DATA_DIR) \
	    --bootstrap
	touch $@

#
# Disk images
#
images: images/stubetc.iso images/data.ffs

images/stubetc.iso: images/stubetc
	./rumprun-makefs -t cd9660 images/stubetc.iso images/stubetc

images/data.ffs: images/data
	./rumprun-makefs -u 1 -g 1 images/data.ffs images/data

#
# Re-link mysqld, used during development
#
.PHONY: relink
relink:
	rm -f $(CROSS_DIR)/sql/mysqld
	rm -f build/mysql_cross_build_stamp
	$(MAKE) mysql

#
# Force re-build images from scratch, used during development
#
.PHONY: reimage
reimage: clean-images images

.PHONY: clean-images
clean-images:
	rm -rf images/data images/*.iso images/*.ffs

.PHONY: clean
clean: clean-images
	rm -rf build
