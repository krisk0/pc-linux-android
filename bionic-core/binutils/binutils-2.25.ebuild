# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit befriend-gcc
# This .ebuild respects CC and CXX settings, if bionic-core/gcc is not installed
HOMEPAGE=https://android.googlesource.com/toolchain/binutils
DESCRIPTION="Binary code creation/manipulation utilities"
LICENSE="|| ( GPL-3 LGPL-3 )"
SRC_URI=https://github.com/crystax/android-toolchain-binutils
# name crystax-ndk-10.2.1.zip is shared by gcc and binutils, so we rename:
#  -ndk-  ->  -binutiuls-
SRC_URI="$SRC_URI/archive/crystax-ndk-10.2.1.zip -> crystax-${PN}-10.2.1.zip"
KEYWORDS=amd64
IUSE="+stage0"
RESTRICT=mirror
use stage0 && SLOT=0 || SLOT=1

DEPEND="
 stage0? ( || ( >=sys-devel/gcc-4.9 >=cross-x86_64-pc-linux-uclibc/gcc-4.9 ) )
 !stage0?
  (
   || ( >=sys-devel/gcc-4.9[cxx] >=cross-x86_64-pc-linux-uclibc/gcc-4.9[cxx] )
   bionic-core/gcc-specs bionic-core/bionic
  )
 "
# Concerning choice of GCC, see comment in jemalloc-*.ebuild.

k=krisk0
# Will use $p as fake prefix
p=/tmp/n0.sUch.fIle.$k

src_unpack()
 {
  default
  d=`find . -type d -name $P`
  [ -z $d ] && die "no $P inside .zip"
  mv $d . || die "mv $P failed"
  ls | grep -v $P | xargs rm -rf
 }

src_prepare()
 {
  # ld stage0 should have no mind of his own and only be able to find libraries
  #  by paths set on command-line; it also must accept any sysroot from command-
  #  line and not panic when it is fake. Turning on sysroot at configure
  #  stage does not disable panic. It means we have to patch ldmain.c
  local t=TARGET_SYSTEM_ROOT
  sed -e "s+#ifndef $t+&_${k}_was_here+" -e "s:$t \"\":$t \"$p\":" \
   -i ld/ldmain.c || die "patching ldmain.c failed"
  # If you know how to create ld with properties described above without
  #  patching a C file, feel free to submit your patch to this ebuild at
  #  https://github.com/krisk0/pc-linux-android/issues
 }

maybe-hypnotize-gcc()
 {
  # on stage0 use glibc- or uclibc- targeting compiler
  use stage0 && { find_gcc 490 ; return; }
  # if a good compiler is installed, use it
  local p=$(best_version bionic-core/gcc)
  [ -z $p ] || { gcc-in-package $p; return; }
  # no suitable compiler found, will hypnotize regular gcc
  hypnotize-gcc $(find_gcc 490)
 }

src_configure()
 {
  ( rm -rf $k ; mkdir $k ) || die "mkdir $k failed" ; cd $k
  unset suffix
  local h=x86_64-linux-gnu
  local i
  local j
  use stage0 &&
   {
    # cross-compilation
    suffix=-stage0
    h="--target=${h/gnu/android} --host=$h --build=$h"
    # create gold linker
    local gold='--enable-gold --enable-gold=default'
    local prefix=$p
   } ||
   {
    # native compilation
    h=${h/gnu/android}
    h="--target=$h --host=$h --build=$h"
    # compile error with hypnotized g++, disabling gold fixes it
    local gold='--disable-gold'
    local prefix="$EPREFIX/usr/x86_64-linux-android/libexec/${P}-stage1"
   }
  # Tried to replace includes:
  #  export CFLAGS="$CFLAGS -nostdinc -isystem /usr/x86_64-linux-android/include"
  # This fails with message:
  #  configure: error: Building with plugin support requires a host that
  #   supports dlopen.
  # Therefore build with standard headers and libraries on stage0

  CC=$(maybe-hypnotize-gcc)
  einfo "CC=$CC"
  # if C compiler is hypnotized then must set LD_LIBRARY_PATH to walk-around
  #  portage bug
  local q=${CC/ized.gcc/ized-gcc}
  [ "$q" == "$CC" ] ||
   {
    export LD_LIBRARY_PATH=$q/lib
    # ... and must provide header sys/procfs.h. The file describes ELF format
    #  for GDB and should be safe to include
    i=include/sys
    j=procfs.h
    ( cd "$q"; mkdir -p $i; ln -s "$EPREFIX/usr/$i/$j" $i || die "$j resists;" )
    i="$q/include"
    sed -i "$CC" -e "s>-DGCC_IS_HYPNOTIZED>-isystem '$i' &>"
    # ... and don't forget to hypnotize g++
    local cxx_exe="$CXX"
    [ -x "$cxx" ] ||
     {
      # no g++ selected by user, must auto-select it
      i=$(tail -1 "$CC"|sed 's> .*>>') ; i=${i#\'}; i=${i%\'};
      [ -x $i ] || die "sanity check on gcc executable failed"
      j=${i%cc}'++'
      [ -x "$j" ] || die "no such file $j, don't know how to define CXX"
      cxx_exe="$j"
     }
    local cxx=${CC#cc}++
    sed -e "s>$i>$cxx_exe>" < "$CC" > "$cxx" || die "failed to cook g++ script"
    chmod +x "$cxx"
    h="$h CXX='$cxx'"
    # ... and cxx compiler needs to find his cstddef and probably other files
    local w=cstddef
    local cxx_p=$(equery b "$j")
    i=$(equery f $cxx_p|fgrep $w|head -1)
    [ -f "$i" ] || die "failed to find $w include"
    i=$(dirname "$i")
    local u=${w}-and-friends
    ( cd "$q/include"; ln -s "$i" $u || die "failed to link g++ includes" )
    sed -i "$cxx" -e "s>-DGCC_IS_HYPNOTIZED>-isystem '$q/include/$u' &>"
    # ... and bits/*.h
    w=bits/c++config.h
    i=$(equery f $cxx_p|fgrep $w|grep -v /32/bits|head -1)
    [ -f "$i" ] || die "failed to find $w include"
    i=$(dirname "$i")
    u='more-friends-20151120'
    cd "$q/include"; mkdir -p $u; cd $u; cp -r "$i" . ||
     die "failed to cp bits/ includes"
    sed -i "$cxx" -e "s>-DGCC_IS_HYPNOTIZED>-isystem '$q/include/$u' &>"
    # patch GLIBC-specific bits/os_defines.h
    sed -i bits/os_defines.h -e 's:__GLIBC_PREREQ(2,15):0:g' ||
     die "patching GLIBC artefact failed"
    cd $S/$k
   }
  ../configure \
   CC="$CC" \
   --prefix=$prefix \
   $h \
   --enable-initfini-array --disable-nls \
   --with-bugurl=https://github.com/$k/pc-linux-android \
   --disable-bootstrap --enable-plugins \
   --enable-libgomp --disable-libcilkrts --disable-libsanitizer \
   $gold   \
   --without-cloog --enable-eh-frame-hdr-for-static \
   --program-suffix="$suffix" \
   --disable-shared --disable-nls ||
    die "configure failed, cwd=`pwd`"
 }

src_compile()
 {
  cd $k || die "cwd=`pwd`, cd $k failed"
  use stage0 &&
   {
    emake all-gas all-ld all-binutils
    return
   }
  emake
 }

src_install()
 {
  cd $k || die "cwd=`pwd`, cd $k failed"
  use stage0 &&
   {
    mkdir -p $k && cd $k && rm -f * || die "cwd=`pwd`, mkdir+cd $k failed"
    local f
    for f in ar objcopy readelf ; do
     mv ../binutils/$f ./${f}$suffix || die "$f resists"
    done
    mv ../ld/ld-new ./ld$suffix || die "ld resists"
    mv ../gas/as-new ./as$suffix || die "as resists"
    into /usr/x86_64-linux-android
    dobin * || die "dobin failed"
   } ||
   {
    # if make install misbehaves, abort
    unset LD_LIBRARY_PATH
    emake DESTDIR="$ED" install
    # add some symlinks
    local t="$ED/$EPREFIX/usr/x86_64-linux-android/bin"
    mkdir -p $t && cd $t || die "lost in time"
    local s=$(find .. -wholename *libexec/$PN*/bin -type d|grep -v x86_64)
    [ -d $s ] || die "s=$s cwd=`pwd`; s is not directory"
    local suffix=-stage1
    # bin/ path is too long, set some short-cuts
    for t in as ld ar nm objdump objcopy readelf ranlib; do
     local q=$(find $s -type f -name $t)
     [ -z "$q" ] && die "failed to find $t, cwd=`pwd`, s=$s"
     ln -s "$q" $t$suffix || die "failed to sym-link $t$suffix -> $q"
    done
    # remove documentation
    cd $ED/$EPREFIX/usr/*linux*/libexec/$PN* || die "lost in space"
    rm -rf share
    # copy gold linker from stage0
    s="$EPREFIX/usr/x86_64-linux-android/bin/ld-stage"
    local gold_ld="${s}1"
    [ -x $gold_ld ] || gold_ld="${s}0"
    [ -x $gold_ld ] || die "gold ld stolen"
    gold_ld=$(realpath "$gold_ld")
    cd "$ED/$EPREFIX/usr/x86_64-linux-android/"
    s=0
    for t in $(find . -type f -wholename '*/bin/ld') ; do
     einfo "Replacing executable $t"
     s=$((s+1))
     cp "$gold_ld" $t
    done
    [ $s == 0 ] && die "failed to find fresh ld"
    # delete ld.bfd
    einfo "replaced ld count: $s"
    find . -type f -wholename '*/bin/ld.bfd' -delete || die "find malfunctions"
   }
  # save some bytes in /var/db/pkg/...
  unset k p suffix
 }
