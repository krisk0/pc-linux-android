# Copyright 1999-2015 Gentoo Foundation
# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

# With array bounds checking turned on, this package triggers warning
#  array subscript is above array bounds at src/prof.c:782:9:
# Looks like false alarm

EAPI=5
WANT_AUTOCONF=2.5   # configure inside jemalloc-3.6.0 was made with ver. 2.69
                    # Gentoo folks mapped 2.69 to 2.5, for unknown reason
inherit autotools-multilib toolchain-funcs

HOMEPAGE=https://android.googlesource.com/platform/external/jemalloc/
DESCRIPTION="Android dialect of jemalloc library, only needed to compile bionic"
LICENSE=BSD
SLOT=0
DEPEND=bionic-core/bionic-headers
KEYWORDS=amd64
IUSE=""
a=android
SRC_URI="https://github.com/${a}-ia/platform_external_$PN/"
SRC_URI="archive/${a}-5.1.0_r1-ia0.zip -> ${PN}-android-$PV.zip"
RESTRICT=mirror

MULTILIB_WRAPPED_HEADERS=( /usr/include/jemalloc/jemalloc.h )

src_unpack()
 {
  default
  mv platform_* $P
 }

src_prepare()
 {
  # Like jemalloc-3.6.0.ebuild, we disable install_doc_html target, because
  #  it fails. In fact, we go futher and disable all documentation
  sed -e 's: install_doc$::g' -i Makefile.in || die "install_doc target resisting"

  # Android'ish version of jemalloc should bundle je_mallinfo(), inject .c
  cp $a/src/je_mallinfo.c src/ || die "je_mallinfo.c resists"

  ln -s $EROOT/usr/x86_64-linux-android/include/malloc.h src/aosp_malloc.h
  sed -i Makefile.in \
   -e '/ifeq .$.enable_valgrind/i \ $(srcroot)src/je_mallinfo.c' \
   -e 's:$(srcroot)src/tsd.c:& \\:' || die "je_mallinfo.c injection failed"

  # configure script missing, must run autoconf
  eautoconf
 }

ask_gcc_for_include()
 {
  local cc1=$($(tc-getCC) -print-prog-name=cc1) || die "gcc refuses to cooperate"
  local d=$(echo|$cc1 -v 2>&1|grep usr/lib/gcc|
            egrep -v '^ignoring nonexistent directory'|
            fgrep -v include-fixed|head -1)
  # I thought $(smth) should give stripped string, but line above produces
  #  directory prefixed by space. Is that bug or feature?
  d=$(echo $d)
  [ -d "$d" ] || die "ask_gcc_for_include() failed"
  echo "$d"
 }

# String QA_CONF... below is supposed to silence a portage warning, but it does
#  not. Nevertheless let it be here
QA_CONFIGURE_OPTIONS="--enable-static --disable-static --enable-shared --disable-shared"
src_configure()
 {
  # valgrind.c not compiled when building android'ish jemalloc via mma
  myeconfargs=( --disable-valgrind )

  # Take flags from Android open-source; turn off _FORTIFY_SOURCE and array
  #  bounds warning; define __NO_STRING_INLINES; use ./ as system include
  # -D_FORTIFY_SOURCE=0 causes warning. Never mind, this is not bug but feature
  local f='-fno-exceptions -Wno-multichar -O2 -Wa,--noexecstack '
  f="$f -Werror=format-security -D_FORTIFY_SOURCE=0 -Wstrict-aliasing=2"
  f="$f -ffunction-sections -finline-functions -finline-limit=300"
  f="$f -fno-short-enums -fstrict-aliasing -funswitch-loops -funwind-tables"
  f="$f -fstack-protector -Werror=pointer-to-int-cast -Werror=int-to-pointer-cast"
  f="$f -march=x86-64 -DUSE_SSSE3 -mssse3 -DANDROID -fmessage-length=0"
  f="$f -W -Wall -Wno-unused -Winit-self -Wpointer-arith -Werror=return-type"
  f="$f -Werror=non-virtual-dtor -Werror=address -Werror=sequence-point"
  f="$f -fno-strict-aliasing -DNDEBUG -UDEBUG -std=gnu99"
  f="$f -Wno-array-bounds -D__NO_STRING_INLINES -isystem \"$S/src\""
  f="$f -Wno-unused-parameter -DANDROID_ALWAYS_PURGE"
  f="$f -DANDROID_MAX_ARENAS=2 -DANDROID_TCACHE_NSLOTS_SMALL_MAX=8"
  f="$f -DANDROID_TCACHE_NSLOTS_LARGE=16 -DANDROID_LG_TCACHE_MAXCLASS_DEFAULT=16"
  local I=`ask_gcc_for_include`
  einfo found gcc dir $I
  f="$f -nostdinc -isystem $EROOT/usr/x86_64-linux-android/include -isystem $I"
  export CFLAGS="$f"
  einfo "using flags $CFLAGS"
  autotools-multilib_src_configure
 }

src_install()
 {
  autotools-multilib_src_install

  # clean
  cd "$ED" || die "failed to chdir to $ED"
  rm -rf share include || die "rm point 0 failed"
  ( find . -type f -o -type l | fgrep -v libjemalloc_pic.a | xargs rm -f ) ||
   die "cleaning libXY failed"

  cd usr || die "cd point 0 failed"
  # install .h
  local TGT=x86_64-linux-$a
  mkdir -p $TGT/{lib{32,64},include/$PN} || die "mkdir failed"
  cp $S/include/$PN/$PN.h $TGT/include/$PN || die "cp $PN.h failed"

  local i
  local j
  local ar="$(tc-getAR)"
  local nm="$(tc-getNM)"
  for i in 32 64 ; do
   cd lib$i || die "cd lib$i failed"
   # repack .a
   "$ar" x libjemalloc_pic.a || die "unpack in lib$i failed"
   for j in *.o ; do
    local k=$("$nm" -C $j)
    [ -z "$k" ] && { einfo removing empty lib$i/$j; rm $j; }
    [ -f $j ] && mv $j ${j/.pic/}
   done
   "$ar" crsD libjemalloc.a *.o
   cd ..
   # move .a
   mv lib$i/libjemalloc.a $TGT/lib$i/ ||
    die "mv lib$i/libjemalloc.a $TGT/lib$i failed, cwd=`pwd`"
   # clean
   rm -rf lib$i
  done
  rm -rf share include bin

  # store CFLAGS
  mkdir -p $TGT/share
  echo $CFLAGS > $TGT/share/jemalloc.cflags

  # Difference from AOSP build: -g not used; strip applied;
  #  _FORTIFY_SOURCE=0 not 2
 }