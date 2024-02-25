#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CURRENT_DIR=$(pwd)

cd $SCRIPT_DIR

DEP=$(realpath dep_root)
REQURIEMTS_BUILD=$(realpath resources)
INSTALLED_REPOS=/usr/local/lib/

MBEDTLS_VERSION="3.5.2"
LIBUSB_VERSION="1.0.26"
READLINE_VERSION="8.2"
SLANG_VERSION="2.3.3"
NEWT_VERSION="0.52.23"
GPM_VERSION="1.20.7"
POPT_VERSION="1.19"

mkdir -p $DEP/lib/
mkdir -p $REQURIEMTS_BUILD

# sudo apt-get remove -y libssl-dev libreadline-dev
sudo apt-get install -y pkg-config autoconf automake autopoint mandoc
sudo python3 -m pip install jsonschema jinja2
sudo apt install -y build-essential pkg-config checkinstall git autoconf automake libtool-bin libreadline-dev libusb-1.0-0-dev gtk-doc-tools libkmod-dev libssl-dev 


function do_link_deb_lib()
{
    CURRENT_ARCHIVE=$1
    rm $DEP/lib/$(basename $CURRENT_ARCHIVE)
    ln -s $CURRENT_ARCHIVE  $DEP/lib/$(basename $CURRENT_ARCHIVE)
}

function build_library_git()
{
    export mbedtls_INCLUDES=$(realpath "mbedtls-${MBEDTLS_VERSION}")
    CURRENT_REPO=$1
    filename=$(basename -- "$CURRENT_REPO")
    REPO_NAME="${filename%.*}"
    git clone $CURRENT_REPO
    cd $REPO_NAME
    ./autogen.sh --with-mbedtls --enable-debug
    make
    cp -r include/ $DEP/
    find . -name "*.a" -exec cp {}  $DEP/lib/ \;
    # sudo make install
    unset mbedtls_INCLUDES

    cd ..
    # sudo make install
}

function build_library_folder()
{
    export mbedtls_INCLUDES=$(realpath "mbedtls-${MBEDTLS_VERSION}")
    CURRENT_REPO=$1
    cd $REPO_NAME
    ./autogen.sh --with-mbedtls --enable-debug
    make
    cp -r include/ $DEP/
    find . -name "*.a" -exec cp {}  $DEP/lib/ \;
    # sudo make install
    unset mbedtls_INCLUDES
}

function copy_compiled_things()
{
    cp -r include/ $DEP/
    find . -name "*.a" -exec cp {}  $DEP/lib/ \;
}


function download_dep()
{
    wget "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v${MBEDTLS_VERSION}.tar.gz"
    wget "https://github.com/libusb/libusb/releases/download/v${LIBUSB_VERSION}/libusb-${LIBUSB_VERSION}.tar.bz2"
    wget "https://mirror-hk.koddos.net/gnu/readline/readline-${READLINE_VERSION}.tar.gz"
    wget "https://www.jedsoft.org/releases/slang/slang-${SLANG_VERSION}.tar.bz2 "
    wget "https://releases.pagure.org/newt/newt-${NEWT_VERSION}.tar.gz"
    wget "https://github.com/telmich/gpm/archive/refs/tags/${GPM_VERSION}.tar.gz"
    wget "https://github.com/rpm-software-management/popt/archive/refs/tags/popt-${POPT_VERSION}-release.tar.gz"
}

function extract_dep()
{
    tar -xf v${MBEDTLS_VERSION}.tar.gz
    tar -xjf libusb-${LIBUSB_VERSION}.tar.bz2
    tar -xf readline-${READLINE_VERSION}.tar.gz
    tar -xjf slang-${SLANG_VERSION}.tar.bz2
    tar -xf newt-${NEWT_VERSION}.tar.gz
    tar -xf ${GPM_VERSION}.tar.gz
    tar -xf popt-${POPT_VERSION}-release.tar.gz
}



function build_dep()
    {
    # Build Mbed TLS
    cd mbedtls-${MBEDTLS_VERSION}
    cat ../../patches/mbedtls/0001-Allow-empty-x509-cert-issuer.patch | patch -sN -d . -p1
    python3 -m pip install --user -r scripts/basic.requirements.txt
    make 
    copy_compiled_things
    cd ..

    # Build libusb
    cd libusb-${LIBUSB_VERSION}
    ./configure ${CONFIGURE_ARGS} --disable-udev
    make -j$(nproc)
    copy_compiled_things
    # make -j$(nproc) install DESTDIR=${DESTDIR}
    cd ..

    # Build readline
    cd readline-${READLINE_VERSION}
    ./configure ${CONFIGURE_ARGS}
    make -j$(nproc)
    copy_compiled_things
    # make -j$(nproc) install DESTDIR=${DESTDIR}
    cd ..


    # Build S-Lang
    cd slang-${SLANG_VERSION}
    ./configure \
    ${CONFIGURE_ARGS} \
    --without-x \
    --without-pcre \
    --without-onig \
    --without-z \
    --without-png \
    --without-iconv
    gmake -j$(sysctl -n hw.ncpu) static
    # gmake -j$(sysctl -n hw.ncpu) install-static DESTDIR=${DESTDIR}
    copy_compiled_things
    cd ..

    # Build GPM
    cd gpm-${GPM_VERSION}
    cat ../patches/gpm/*.patch | patch -sN -d . -p1
    ./autogen.sh
    ./configure \
    ${CONFIGURE_ARGS}
    gmake -j$(sysctl -n hw.ncpu)
    # gmake -j$(sysctl -n hw.ncpu) install DESTDIR=${DESTDIR}
    copy_compiled_things
    cd ..

    # Build popt
    cd popt-popt-${POPT_VERSION}-release
    autoreconf -fiv
    ./configure \
    ${CONFIGURE_ARGS} \
    --without-libiconv-prefix \
    --without-libintl-prefix \
    --disable-nls \
    --disable-werror
    gmake -j$(sysctl -n hw.ncpu)
    # gmake -j$(sysctl -n hw.ncpu) install DESTDIR=${DESTDIR}
    copy_compiled_things
    cd ..

    # Build newt
    cd newt-${NEWT_VERSION}
    ./configure \
    ${CONFIGURE_ARGS} \
    --with-readline=gnu \
    --without-python \
    --without-tcl \
    --disable-nls \
    --with-gpm-support
    gmake -j$(sysctl -n hw.ncpu) libnewt.a
    # mkdir -p ${DESTDIR}/usr/local/{lib/pkgconfig,include}
    # install -m644 libnewt.pc ${DESTDIR}/usr/local/lib/pkgconfig
    # install -m644 libnewt.a ${DESTDIR}/usr/local/lib
    # install -m644 newt.h ${DESTDIR}/usr/local/include
    copy_compiled_things
    cd ..
}

pushd $REQURIEMTS_BUILD

export PKG_CONFIG_PATH="$DEP/pkgconfig/"
export CFLAGS="-g -fdata-sections -ffunction-sections -I${DEP}/include/ -L${DEP}/lib/"
export CXXFLAGS="-g -fdata-sections -ffunction-sections -I${DEP}/include/ -L${DEP}/lib/"
export LDFLAGS="-g -Wl,--gc-sections -fdata-sections -ffunction-sections -I${DEP}/include/ -L${DEP}/lib/"
export CONFIGURE_ARGS="--disable-shared --enable-static"

build_dep 

# Build libplist
build_library_git https://github.com/libimobiledevice/libplist.git

# Build libimobiledevice-glue
build_library_git https://github.com/libimobiledevice/libimobiledevice-glue.git

# Build libirecovery (sorta)
build_library_git https://github.com/libimobiledevice/libirecovery.git

# Build libusbmuxd
build_library_git https://github.com/libimobiledevice/libusbmuxd.git

# Build libimobiledevice
build_library_git https://github.com/libimobiledevice/libimobiledevice.git

# Build usbmuxd
build_library_git https://github.com/libimobiledevice/usbmuxd.git

cd ..

# Build palera1n
# cp -a ${DESTDIR}/${PREFIX}/{include,lib} dep_root
# find dep_root -name '*.so' -delete
# find dep_root -name '*.la' -delete
make -j$(nproc) DEV_BUILD=1 TUI=1 ROOTFUL=1

popd
