 #!/bin/bash

set -e
set -x

mkdir ~/softether && cd ~/softether

BASE=`pwd`
SRC=$BASE/src
WGET="wget --prefer-family=IPv4"
RPATH=/opt/lib
DEST=$BASE/opt
LDFLAGS="-L$DEST/lib"
CPPFLAGS="-I$DEST/include"
CFLAGS="-march=armv7-a -mtune=cortex-a9"
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=/opt --host=arm-linux"
MAKE="make -j`nproc`"
mkdir $SRC

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir $SRC/zlib && cd $SRC/zlib
$WGET http://zlib.net/zlib-1.2.8.tar.gz
tar zxvf zlib-1.2.8.tar.gz
cd zlib-1.2.8

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
CROSS_PREFIX=arm-linux- \
./configure \
--prefix=/opt \
--static

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET https://www.openssl.org/source/openssl-1.0.2d.tar.gz
tar zxvf openssl-1.0.2d.tar.gz
cd openssl-1.0.2d

./Configure linux-armv4 -march=armv7-a -mtune=cortex-a9 \
--prefix=/opts zlib \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=arm-linux-gcc
make CC=arm-linux-gcc install INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

########### #################################################################
# NCURSES # #################################################################
########### #################################################################

mkdir $SRC/curses && cd $SRC/curses
$WGET http://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz
tar zxvf ncurses-6.0.tar.gz
cd ncurses-6.0

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-widec \
--enable-overwrite \
--with-normal \
--with-shared \
--enable-rpath \
--with-fallbacks=xterm

$MAKE
make install DESTDIR=$BASE

############### #############################################################
# LIBREADLINE # #############################################################
############### #############################################################

mkdir $SRC/libreadline && cd $SRC/libreadline
$WGET ftp://ftp.cwru.edu/pub/bash/readline-6.3.tar.gz
tar zxvf readline-6.3.tar.gz
cd readline-6.3

$WGET https://raw.githubusercontent.com/lancethepants/tomatoware/master/patches/readline/readline.patch
patch < readline.patch

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--disable-shared \
bash_cv_wcwidth_broken=no \
bash_cv_func_sigsetjmp=yes

$MAKE
make install DESTDIR=$BASE

############ ################################################################
# LIBICONV # ################################################################
############ ################################################################

mkdir $SRC/libiconv && cd $SRC/libiconv
$WGET http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
tar zxvf libiconv-1.14.tar.gz
cd libiconv-1.14

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-static \
--disable-shared

$MAKE
make install DESTDIR=$BASE

############# ###############################################################
# SOFTETHER # ###############################################################
############# ###############################################################

mkdir $SRC/softether && cd $SRC/softether
git clone https://github.com/SoftEtherVPN/SoftEtherVPN.git
cp -r SoftEtherVPN SoftEtherVPN_host
cd SoftEtherVPN_host

if [ "`uname -m`" == "x86_64" ];then
	cp ./src/makefiles/linux_64bit.mak ./Makefile
else
	cp ./src/makefiles/linux_32bit.mak ./Makefile
fi

$MAKE

cd ../SoftEtherVPN

$WGET https://raw.githubusercontent.com/el1n/OpenWRT-package-softether/master/softethervpn/patches/100-fix-ccldflags-common.patch
$WGET https://raw.githubusercontent.com/el1n/OpenWRT-package-softether/4cb1cd9073a76edf34c512e587069626e02e2404/patches/120-fix-iconv-headers-common.patch
patch -p1 < 100-fix-ccldflags-common.patch
patch -p1 < 120-fix-iconv-headers-common.patch

cp ./src/makefiles/linux_32bit.mak ./Makefile
sed -i 's,#CC=gcc,CC=arm-linux-gcc,g' Makefile
sed -i 's,-lncurses -lz,-lncursesw -lz -liconv -ldl,g' Makefile
sed -i 's,ranlib,arm-linux-ranlib,g' Makefile

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-static $LDFLAGS" \
$MAKE \
|| true

cp ../SoftEtherVPN_host/tmp/hamcorebuilder ./tmp/

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-static $LDFLAGS" \
$MAKE
