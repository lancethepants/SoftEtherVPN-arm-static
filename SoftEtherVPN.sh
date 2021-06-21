#!/bin/bash

set -e
set -x

BASE=`pwd`
DEST=$BASE/out
SRC=$DEST/src

WGET="wget --prefer-family=IPv4"
LDFLAGS="-L$DEST/lib"
CPPFLAGS="-I$DEST/include"
CFLAGS="-O3 -march=armv7-a -mtune=cortex-a9"
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=$DEST --host=arm-linux"
MAKE="make -j`nproc`"

mkdir -p $SRC

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir $SRC/zlib && cd $SRC/zlib
$WGET https://zlib.net/zlib-1.2.11.tar.gz
tar zxvf zlib-1.2.11.tar.gz
cd zlib-1.2.11

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
CROSS_PREFIX=arm-linux- \
./configure \
--prefix=$DEST \
--static

$MAKE
make install

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET https://www.openssl.org/source/openssl-1.1.1k.tar.gz
tar zxvf openssl-1.1.1k.tar.gz
cd openssl-1.1.1k

./Configure no-shared linux-armv4 -march=armv7-a -mtune=cortex-a9 \
--prefix=$DEST zlib \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=arm-linux-gcc
make CC=arm-linux-gcc install INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

########### #################################################################
# NCURSES # #################################################################
########### #################################################################

mkdir $SRC/ncurses && cd $SRC/ncurses
$WGET http://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz
tar zxvf ncurses-6.2.tar.gz
cp -r ncurses-6.2 ncurses-6.2-native

cd ncurses-6.2-native

./configure \
--prefix=$SRC/ncurses/ncurses-6.2-native/install \
--without-cxx \
--without-cxx-binding \
--without-ada \
--without-debug \
--without-manpages \
--without-profile \
--without-tests \
--without-curses-h
$MAKE
make install

cd ../ncurses-6.2

PATH=$SRC/ncurses/ncurses-6.2-native/install/bin:$PATH \
LDFLAGS=$LDFLAGS \
CPPFLAGS="-P $CPPFLAGS" \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-widec \
--enable-overwrite \
--with-normal \
--with-shared \
--enable-rpath \
--disable-stripping \
--with-fallbacks=xterm

$MAKE
make install

ln -s libncursesw.a $DEST/lib/libncurses.a

############### #############################################################
# LIBREADLINE # #############################################################
############### #############################################################

mkdir $SRC/libreadline && cd $SRC/libreadline
$WGET http://ftp.gnu.org/gnu/readline/readline-8.1.tar.gz
tar zxvf readline-8.1.tar.gz
cd readline-8.1

patch < $BASE/patches/readline.patch

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--disable-shared \
bash_cv_wcwidth_broken=no \
bash_cv_func_sigsetjmp=yes

$MAKE
make install

############# ###############################################################
# SOFTETHER # ###############################################################
############# ###############################################################

mkdir $SRC/softether && cd $SRC/softether
wget https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.36-9754-beta/softether-src-v4.36-9754-beta.tar.gz
tar zxvf softether-src-v4.36-9754-beta.tar.gz
mv v4.36-9754 SoftEtherVPN
cp -r SoftEtherVPN SoftEtherVPN_host

cd SoftEtherVPN_host

if [ "`uname -m`" == "x86_64" ];then
	cp ./src/makefiles/linux_64bit.mak ./Makefile
else
	cp ./src/makefiles/linux_32bit.mak ./Makefile
fi

$MAKE

cd ../SoftEtherVPN

patch -p1 < $BASE/patches/softethervpn.patch

cp ./src/makefiles/linux_32bit.mak ./Makefile

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-s -static $LDFLAGS" \
$MAKE \
|| true

cp ../SoftEtherVPN_host/tmp/hamcorebuilder ./tmp/

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-s -static $LDFLAGS" \
$MAKE

cp $SRC/softether/SoftEtherVPN/bin/vpnserver/hamcore.se2 $BASE
cp $SRC/softether/SoftEtherVPN/bin/*/vpn* $BASE
