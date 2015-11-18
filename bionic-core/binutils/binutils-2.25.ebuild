# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit toolchain-funcs befriend-gcc
HOMEPAGE=https://android.googlesource.com/toolchain/binutils
LICENSE="|| ( GPL-3 LGPL-3 )"
SRC_URI=https://github.com/crystax/android-toolchain-binutils
SRC_URI=$SRC_URI/archive/crystax-ndk-10.2.1.zip
KEYWORDS=amd64
IUSE="+stage0"
RESTRICT=mirror
use stage0 && SLOT=0 || SLOT=1
k=krisk0
p=/tmp/n0.sUch.fIle.$k
# compilation against /usr/x86_64-linux-android/include failed, so line below
#  is commented out
#DEPEND="bionic-core/bionic-headers"
DEPEND=" || ( >=sys-devel/gcc-4.9 >=cross-x86_64-pc-linux-uclibc/gcc-4.9 )"
# Concerning choice of GCC, see comment in jemalloc-*.ebuild

src_unpack()
 {
  default
  d=`find . -type d -name $P` || die "no $P inside .zip"
  mv $d . || die "mv $P failed"
  ls | grep -v $P | xargs rm -rf
 }

src_prepare()
 {
  # ld should have no mind of his own and only be able to find libraries by 
  #  paths set on command-line. This can be done two ways:
  #   a) disable sysroot feature;
  #   b) enable sysroot but make it fake (point to non-existing directory).
  # But gcc sends sysroot flag to ld, and ld refuses to work in case a). Thus
  #  option b) is the only choice

  # The patch below convinces ld to support sysroot, and not to panic when no
  #  valid sysroot exists

  #  sed -i ld/configure -e 's:use_sysroot=.*:use_sysroot=yes:g'
  # patching configure as above appear to have no effect, so we patch ldmain.c
  local t=TARGET_SYSTEM_ROOT
  sed -e "s+#ifndef $t+&_${k}_was_here+" -e "s:$t \"\":$t \"$p\":" \
   -i ld/ldmain.c || die "patching ldmain.c failed"
 }

src_configure()
 {
  ( rm -rf $k ; mkdir $k ) || die "mkdir $k failed" ; cd $k
  use stage0 || die "stage1 not implemented"
  suffix=-stage0
  local h=x86_64-linux-gnu
  # Tried to replace includes:
  #  export CFLAGS="$CFLAGS -nostdinc -isystem /usr/x86_64-linux-android/include"
  # This fails with message:
  #  configure: error: Building with plugin support requires a host that
  #   supports dlopen.
  # We therefore build with standard headers and libraries
  local gcc=`find_gcc 490`
  ../configure \
   CC="$gcc" \
   --prefix=$p \
   --target=${h/gnu/android} --host=$h --build=$h \
   --enable-initfini-array --disable-nls \
   --with-bugurl=https://github.com/$k/pc-linux-android \
   --disable-bootstrap --enable-plugins \
   --enable-libgomp --disable-libcilkrts --disable-libsanitizer \
   --enable-gold --without-cloog --enable-eh-frame-hdr-for-static \
   --program-suffix="$suffix" \
   --disable-shared --disable-nls --enable-gold=default ||
    die "configure failed, cwd=`pwd`"
 }

src_compile()
 {
  cd $k || die "cwd=`pwd`, cd $k failed"
  emake all-gas all-ld all-binutils || die "emake failed"
 }

src_install()
 {
  cd $k || die "cwd=`pwd`, cd $k failed"
  mkdir -p $k && cd $k && rm -f * || die "cwd=`pwd`, mkdir+cd $k failed"
  local f
  for f in ar objcopy readelf ; do
   mv ../binutils/$f ./${f}$suffix || die "$f resists"
  done
  mv ../ld/ld-new ./ld$suffix || die "ld resists"
  mv ../gas/as-new ./as$suffix || die "as resists"
  into /usr/x86_64-linux-android
  dobin * || die "dobin failed"
  # save some bytes in /var/db/pkg/...
  unset k p suffix
 }
