# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit toolchain-funcs
HOMEPAGE=https://android.googlesource.com/toolchain/binutils
LICENSE="|| ( GPL-3 LGPL-3 )"
SRC_URI=https://github.com/crystax/android-toolchain-binutils
SRC_URI=$SRC_URI/archive/crystax-ndk-10.2.1.zip
KEYWORDS=amd64
IUSE="+stage0"
RESTRICT=mirror
SLOT=0
k=krisk0
p=/tmp/n0.sUch.fIle.$k
# compilation against /usr/x86_64-linux-android/include failed, so line below
#  is commented out
#DEPEND="bionic-core/bionic-headers" 

src_unpack()
 {
  default
  d=`find . -type d -name $P` || die "no $P inside .zip"
  mv $d . || die "mv $P failed"
  ls | grep -v $P | xargs rm -rf
 }

src_prepare()
 {
  # ld should have no mind of his own and be only able to find libraries by paths
  #  set on command-line. This can be done two ways:
  #   a) disable sysroot feature;
  #   b) enable sysroot but make it fake (point to non-existing directory).
  # But gcc sends sysroot flag to ld, and ld refuses to work if it does not know
  #  about sysroot. So option b) is the only choice
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
  suffix=stage0
  local h=x86_64-linux-gnu
  einfo "CC: $(tc-getCC)"
  #export CFLAGS="$CFLAGS -nostdinc -isystem /usr/x86_64-linux-android/include"
  # Attempt to substitute includes fails: 
  #  configure: error: Building with plugin support requires a host that 
  #   supports dlopen.
  # We therefore build with standard headers and libraries
  ../configure \
   CC=$(tc-getCC) \
   --prefix=$p \
   --target=${h/gnu/android} --host=$h --build=$h \
   --enable-initfini-array --disable-nls \
   --with-bugurl=https://github.com/$k/pc-linux-android \
   --enable-languages=c,c++ --disable-bootstrap --enable-plugins \
   --enable-libgomp --disable-libcilkrts --disable-libsanitizer \
   --enable-gold --without-cloog --enable-eh-frame-hdr-for-static \
   --program-suffix=$suffix \
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
  mv binutils/ar ./ar-$suffix || die "ar resists"
  mv ld/ld-new ./ld-$suffix || die "ld resists"
  mv gas/as-new ./as-$suffix || die "as resists"
  into /usr/x86_64-linux-android
  dobin ??-$suffix || die "dobin failed"
  # save some bytes in /var/db/pkg/...
  unset k p suffix
 }
