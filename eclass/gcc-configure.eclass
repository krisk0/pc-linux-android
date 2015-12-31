# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

# Code that helps to unpack or configure gcc lives here

inherit base befriend-gcc

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
  rm -rf libjava
  cd gcc/config
  find . -maxdepth 1 -type d|grep -v i386|xargs rm -rf
  triple=x86_64-linux-android
 }

gcc-configure-options()
 {
  triple=x86_64-linux-android
  root="$EPREFIX/usr/$triple"
  o="--enable-plugins --enable-languages=c,c++"
  o="$o --enable-libgomp --enable-initfini-array --disable-nls"
  o="$o --disable-libcilkrts --disable-libsanitizer --enable-gold"
  o="$o --prefix=$EPREFIX/usr"
  o="$o --with-native-system-header-dir=$root/include"
  o="$o --with-gnu-as --with-as=$(find_tool as)"
  o="$o --with-gnu-ld --with-ld=$(find_tool ld)"
  o="$o --with-bugurl=https://github.com/$k/pc-linux-android"
  o="$o --program-prefix=${triple}-stage0-"
  o="$o --with-gmp-lib=$root/lib64 --with-gmp-include=$root/include"
  echo "$o"
 }

lto_capable_tools()
# sym-link lto-capable nm ar ranlib to $1
 {
  local n=`find_lto_capable_nm`
  (
   cd $1
   rm -f nm ar ranlib
   ln -s $n nm
   local i
   n=${n%nm}
   for i in ar ranlib ; do
    ln -s ${n}$i $i
   done
  )
 }

native-gcc-configure-options()
 {
  triple=x86_64-linux-android
  local h=$triple
  local s=-L/system/lib64
  o="--target=$h --host=$h --build=$h --prefix=$EPREFIX/usr"
  o="$o --enable-plugins --enable-languages=c,c++"
  o="$o --enable-libgomp --enable-initfini-array --disable-nls"
  o="$o --disable-libcilkrts --disable-libsanitizer --enable-gold"
  o="$o --disable-libssp"
  o="$o --with-bugurl=https://github.com/$k/pc-linux-android"
  o="$o --with-gnu-as --with-gnu-ld"
  o="$o --with-boot-ldflags=-static-libgcc"
  #o="$o --with-stage1-libs=$s --with-boot-libs=$s"
  # cook tools
  build_time_tools="$WORKDIR/bin/"
  mkdir -p $build_time_tools
  o="$o --with-build-time-tools=$build_time_tools"
  local ld=`equery f 0gcc|egrep gcc-ld$|fgrep /bin/|head -1`
  cp -L `find_tool as` $build_time_tools/as
  cp -L `which strip` $ld $build_time_tools || die "tools resist cp"
  local i
  # GCC wants ar, ranlib, nm with lto plugin support. Take the 3 tools
  #  from sys-devel/gcc
  lto_capable_tools $build_time_tools
  (
   cd $build_time_tools
   for i in `ls|fgrep -- -` ; do
    mv $i ${i##*-} || die "renaming bin/$i failed"
   done
  )
  local root=$EPREFIX/usr/$h
  local l64=$root/lib64
  local x
  for x in gmp isl mpfr mpc ; do
   o="$o --with-${x}-lib=$l64 --with-${x}-include=$root/include"
  done
  o="$o --disable-libstdcxx"
  #o="$o --with-host-libstdcxx=-lgnustl_shared"
  rm -rf "$gcc_srcdir/libssp"
  echo "$o"
 }
