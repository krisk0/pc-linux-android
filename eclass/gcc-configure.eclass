# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

# Code that helps to unpack or configure gcc lives here

inherit base

gcc-unpack()
 {
  base_src_unpack
  mv gcc-* gCc || die "failed to rename gcc-... directory"
  rm -rf gCc/gmp || die "failed to remove gmp"
  local x
  for x in `ls|grep -v gCc` ; do
   mv $x gCc/${x%-*} || die "moving $x directory failed"
  done
  k=krisk0
  mkdir -p $k || die "separate directory: failed to create"
  S="$WORKDIR/$k"
  gcc_srcdir="$WORKDIR/gCc"
  cd gCc
  rm -rf libjava gcc/config/{s390,aarch64,arm,avr,sh,mips,sparc,rs6000}
  # Lots of unneeded stuff remains
 }

gcc-configure-options()
 {
  triple=x86_64-linux-android
  [ -x bin/${triple}-ranlib ] ||
   {
    mkdir -p bin
    for t in as ld ar ranlib ; do
     cp $(find_tool $t) bin/${triple}-$t ||
      die "problem with tool $t"
    done
   }
  root="$EPREFIX/usr/$triple"
  o="--enable-plugins --enable-languages=c,c++"
  o="$o --enable-libgomp --enable-initfini-array --disable-nls"
  o="$o --disable-libcilkrts --disable-libsanitizer --enable-gold"
  o="$o --prefix=$root"
  o="$o --with-native-system-header-dir=$root/include"
  o="$o --with-gnu-as --with-as=$(find_tool as)"
  o="$o --with-gnu-ld --with-ld=$(find_tool ld)"
  o="$o --with-bugurl=https://github.com/$k/pc-linux-android"
  o="$o --program-prefix=${triple}-stage0-"
  o="$o --with-gmp-lib=$root/lib64 --with-gmp-include=$root/include"
  echo "$o"
 }

native-gcc-configure-options()
 {
  root=$EPREFIX/usr
  h=x86_64-linux-gnu
  o="--target=$h --host=$h --build=$h"
  o="$o --disable-plugins --enable-languages=c,c++"
  o="$o --enable-libgomp --enable-initfini-array --disable-nls"
  o="$o --disable-libcilkrts --disable-libsanitizer --enable-gold"
  o="$o --with-bugurl=https://github.com/$k/pc-linux-android"
  o="$o --with-gmp-lib=$root/lib64 --with-gmp-include=$root/include"
  o="$o --with-mpfr-lib=$root/lib64 --with-mpfr-include=$root/include"
  o="$o --with-mpc-lib=$root/lib64 --with-mpc-include=$root/include"
  echo "$o"
 }
