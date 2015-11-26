# Copyright (C) 2008 The Android Open Source Project
# Copyright     2015 Денис Крыськов
# License: Apache License, Version 2.0 (/usr/portage/licenses/Apache-2.0)

EAPI=5

# This package is very sensitive to compiler version (for instance, GCC 4.8.4
#  does not work. You may however try to use any gcc or g++ >= 4.9.0:
# CC=... CXX=...

# If CC and/or CXX are unset, compilers gcc and g++ will be chosen
#  automatically. clang and clang++ are taken from $EPREFIX/usr/bin/ directory.

# If you set CC and/or CXX and something bad happens, don't bother me with bug
#  reports.

#  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
# KNOWN-TO-WORK toold: sys-devel/gcc-4.9.3 installed from ebuild stamped
#  Nov 2 2015; sys-devel/clang-3.5.0-r100 stamped 21 Feb 2015; 
#  sys-devel/binutils-2.25 installed from 
# Feel free to experiment but send your bug-reports to yourself
#  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

# This ebuild script is inspired by, shares some code with, and does roughly the
#  same as AOSP makefiles (covered by Apache license). I therefore use Apache
#  license rather than GPL, and mention AOSP in first line of the file. Notice
#  that android-build subtree does not contain any NOTICE file.

DESCRIPTION="64- and 32-bit bionic C libraries, crt*.o and linker*"
# C++ library is to be built by another .ebuild
HOMEPAGE=https://github.com/android/platform_bionic

inherit toolchain-funcs befriend-gcc lunch-with-android

a=android
B=bionic
TGT=/usr/x86_64-linux-$a
# 6 stable links to download. Long live github.com
g=https://github.com
build_sha=60686586a5f9c8f78b9ad16e19782da85e89a760
sha=cc550142cecd5fadbbd812688650073925b7a1a6
dg=device-generic-
pstglia=$g/pstglia/$dg
pstglia_sha0=0db6aac6b5faac55d3ee0a8d16adf0a6e7afd64d
pstglia_sha1=e05f70868b1d204c1aa8f9960769ddbf907fc361
llvm_sha=b89fbd77d4550d5ab55f497ffe0170968058e3c6
SRC_URI="
 $HOMEPAGE/archive/${a}-${PV}_$PR.zip -> ${B}-${PV}_$PR.zip
 $g/$a/platform_build/archive/$build_sha.zip -> ${a}-build-20141210.zip
 $g/pbatard/bootimg-tools/archive/$sha.zip -> pbatard-bootimgT-20150516.zip
 ${pstglia}common/archive/$pstglia_sha0.zip -> ${dg}common-20150726.zip
 ${pstglia}x86_64/archive/$pstglia_sha1.zip -> ${dg}x86_64-20150716.zip
 $g/llvm-mirror/compiler-rt/archive/$llvm_sha.zip -> compiler-rt-20151111.zip
 "
KEYWORDS=amd64
RESTRICT=mirror
# clang and clang++ is used sometimes, instead of gcc or g++. Looks like there
#  is a reason for this

#

DEPEND='
 =sys-devel/binutils-2.25[multitarget]   
 >=sys-devel/llvm-3.5[clang]
 >=sys-devel/gcc-4.9[cxx]
 bionic-core/binutils
 bionic-core/jemalloc
 bionic-core/bionic-headers
'
# /system/bin/linker64 needs nothing except libraries installed by this package
#  to run a program (theoretically). Thus this package has (technically
#  speaking) no runtime dependencies
SLOT=0
# .mk scripts are covered by Apache-2.0 license; bionic source code by 2-clause
#  BSD. Guess /system/bin/linker64 is under BSD-2?
LICENSE=BSD-2

S="$WORKDIR" # $S == $WORKDIR == $ANDROID_BUILD_TOP

src_unpack()
 {
  rm -rf *
  default
  einfo "unpacked .zip total weight: $(du -sh .)"

  # imitate AOSP tree
  mv platform_${B}* $B || die "problem with ${B}-*.zip"
  # Don't have compiler that can create dynamic Android executables, so don't
  #  even try
  rm -rf bionic/{tests,tools}

  mv platform_build-* build || die "problem with *build*.zip"
  # no file --- no problem
  ( find build/tools -type f | grep -ve 'py$' | xargs rm -f ) ||
   die "find or grep executable missing?"
  >build/core/Makefile || die "build/core went away?"

  mkdir -p device/generic/{common,x86_64} || die "mkdir malfunctions?"
  local i
  for i in common x86_64 ; do
   mv device-generic-${i}-* device-generic-${i} || die "hello pstglia!"
   ( cd device-generic-${i} ; cp -r . ../device/generic/$i ) ||
    die "cp -r failed"
   rm -rf device-generic-${i}
  done

  local j=system/core/include/private/
  local h=bootimg-tools-*/include/private
  mkdir -p $j || die "$j resists"
  cp $h/* $j || die "hello pbatard!"
  rm -rf bootimg-tools-*

  local r=external/compiler-rt/lib/builtins
  mkdir -p $r || die "out of space?"
  mv compiler-rt-* compiler-rt || die "hello llvm!"
  cd compiler-rt/lib/builtins || die "where are builtins?"
  # only need .c and .h
  for i in `find . -type f` ; do
   [ ${i%.c} == $i ] && [ ${i%.h} == $i ] && ( rm -f $i || die "$i resists rm" )
  done
  cp -r . "$S/$r/" || die "where we were?"
  cd "$S" || "die S lost in space"
  rm -rf compiler-rt || die "the dir went away?"
  j=out/target/product/x86_64/obj/STATIC_LIBRARIES
  j=$j/libcompiler_rt-extras_intermediates
  ( mkdir -p $j ; >$j/export_includes ) || die "was that too long?"

  # sys-devel/llvm and bionic-core/* ebuild and do not use ROOT,
  #  therefore we use EPREFIX to find our already-installed files

  my_root="$EPREFIX/usr/x86_64-linux-android"
  [ -d "$my_root" ] || die "base library/include/bin not found"

  # copy prebuilt libjemalloc.a to where makefiles want them to be
  j=libjemalloc
  for i in 32 64 ; do
   local k=obj
   [ $i == 32 ] && k=${k}_x86
   k=out/target/product/x86_64/$k/STATIC_LIBRARIES/${j}_intermediates
   ( mkdir -p $k ; cp "$my_root/lib$i/$j.a" $k/ ) ||
    die "failed to copy ${i}-bit $j.a"
   # pretend that export_includes target has been made
   touch $k/export_includes || die "$k/ does not want export_includes"
  done
 }

# du -sh says 286M after build, 137M after unpack before trimming, that's small,
#  no need to check for free disk space
# CHECKREQS_DISK_BUILD="300M"

src_prepare()
 {
  cd bionic || die
  # flock64 redefined in fcntl.h
  sed -e 's:struct flock64 {:struct redefined_flock64 {:' \
   -i libc/include/fcntl.h || exit

  # 2 slightly different machine/endian.h in bionic sources
  # diff arch-x86_64/include/machine/endian.h arch-x86/include/machine
  #< /*    $OpenBSD: endian.h,v 1.5 2011/03/12 22:27:48 guenther Exp $     */
  #---
  #> /*    $OpenBSD: endian.h,v 1.17 2011/03/12 04:03:04 guenther Exp $    */

  # command below copies newer file over older
  local im=include/machine
  cp libc/arch-x86_64/$im/endian.h libc/arch-x86/$im/ ||
   die "machine/endian.h resists"

  # Fix some .S to prevent compilation error: force including of NetBSD
  #  machine/asm.h
  sed -e \
   "/#include <private.bionic_asm.h>/i #include \"arch-x86/$im/asm.h\""\
   -i libc/arch-x86/bionic/setjmp.S libc/arch-x86/bionic/sigsetjmp.S ||
    die ".S files resist"
  cd ..

  local i
  # add empty leaves to .mk tree, or cut-off some branches
  for i in device/generic/common/BoardConfig.mk build/core/Makefile \
   `find . -type f -name *java*` ; do
    >$i
  done
  sed -e '\:common/x86.mk:d' -i device/generic/x86_64/android_x86_64.mk ||
   die "android_x86_64.mk resists"

  # jemalloc header no longer in external/
  local ip="'""$my_root/include""'"
  sed -i bionic/libc/Android.mk -e "s|external/jemalloc/include|$ip|g" ||
   die "bionic Android.mk resists jemalloc include"

  # use regular clang++ executable,
  sed -i build/core/clang/config.mk \
   -e "s+CLANG := .*+CLANG := $EPREFIX/usr/bin/clang+" \
   -e "s-CLANG_CXX := .*-CLANG_CXX := $EPREFIX/usr/bin/clang++-" ||
    die "clang++ not welcome"
  #                                 that knows its include path
  sed -i build/core/clang/config.mk -e\
   "/CLANG_CONFIG_EXTRA_.*_C_INCLUDES := /d" || die "C_INCLUDES resist"
  # remove -Bprebuilts/... flag
  for i in x86_64 x86 ; do
   sed -e '/ -B.*/d' -i build/core/clang/TARGET_$i.mk || die "-B resists"
  done
  # TODO: warning not silenced: '-finline-functions' not supported by clang

  # Tell makefiles about gcc, g++, binutils, include directories
  local ep="$my_root/bin"
  local ip="$my_root/include"
  # GCC 4.8.4 is unable to compile bionic, therefore find gcc >=4.9.0
  local gcc=$(find_gcc 490)
  c_opt=$(gcc_your_include "$gcc")
  c_opt="-mandroid -nostdinc '-I$c_opt'"
  c_opt="$c_opt -I$ip"
  local gpp=$(find_gxx 490)
  # Compilation might fail if gcc and g++ belong to different packages. If this
  #  happens, try setting CC and CXX vars wisely.
  local x
  local y
  # Use prebuilt ld and friends
  i=$(which $(tc-getSTRIP))
  for x in x86 x86_64 ; do
   for y in ar objcopy ld readelf ; do
    sed -i build/core/combo/TARGET_linux-$x.mk -e\
     "s|TARGET_${y^^} := .*|TARGET_${y^^} := $(find_tool $y)|" ||
      die "$y not welcome to TARGET_linux-$x.mk"
   done
   # use standard strip; chosen g++, gcc ; disable wildcard check on gcc; force
   #  Sys5 hash style; point to kernel headers; remove -D_FORTIFY_SOURCE=...

   # if $EPREFIX contains <, then sed below will fail, so stop right here
   [ "${EPREFIX//</}" == "$EPREFIX" ] ||
    die "EPREFIX with < inside not supported"

   sed -i build/core/combo/TARGET_linux-$x.mk \
    -e "s<TARGET_STRIP := .*<TARGET_STRIP := $i<" \
    -e "s<TARGET_CC := .*<TARGET_CC := $gcc $c_opt<" \
    -e "s<TARGET_CXX := .*<TARGET_CXX := $gpp $c_opt<" \
    -e 's<$(wildcard $(.*TARGET_CC))<$(TARGET_CC)<' \
    -e 's|-Wl,--gc-sections|& -Wl,--hash-style=sysv|' \
    -e "s<KERNEL_HEADERS_COMMON := .*<KERNEL_HEADERS_COMMON := $ip<" \
    -e "s<KERNEL_HEADERS_ARCH *:=.*<KERNEL_HEADERS_ARCH := $ip/asm<" \
    -e '/_FORTIFY_SOURCE=/d' || die "failed to patch TARGET_linux-$x.mk"
  done

  # delete garbage left by find_gcc()
  rm -f gccdump.s

  # Don't treat warning as error
  find . -name '*.mk' | xargs sed -e 's: -Werror ::g' -i

  # skip death on Java check failure
  sed -i build/core/main.mk \
   -e 's:\$(error stop)::g' \
    die "build/core/main.mk resists"

  # use standard cp not acp
  sed -i build/core/config.mk -e "s+ACP := .*+ACP := $(which cp)+g" ||
   die "ACP resists"
 }

clang_mulodi4()
# llvm comes without Android.mk stuff. This subroutine is derived from AOSP .mk
#  files, and does roughly the same as make utility, when it builds mulodi4.o
#  object. It means that all bugs are either mine (Денис Крыськов) or belong to
#  AOSP.
# $1: extra compiler flag
# $2: target file
 {
  local i
  local f="$1 -o$2 -c"
  for i in system/core/include bionic/libc/arch-x86_64/include \
   bionic/libc/include bionic/libstdc++/include \
   "$my_root/include" "$my_root/include/asm" \
   bionic/libm/include bionic/libm/include/amd64 ; do
    f="$f -isystem '$i'"
  done
  f="$f
     -fno-exceptions -Wno-multichar -O2 -Wa,--noexecstack
     -Werror=format-security -Wstrict-aliasing=0 -ffunction-sections
     -fno-short-enums -fstrict-aliasing
     -funwind-tables -fstack-protector -no-canonical-prefixes
     -Werror=pointer-to-int-cast -Werror=int-to-pointer-cast
     -include build/core/combo/include/arch/target_linux-x86/AndroidConfig.h
     -DANDROID -fmessage-length=0 -W -Wall -Wno-unused -Winit-self
     -Wpointer-arith -Werror=return-type -Werror=non-virtual-dtor
     -Werror=address -Werror=sequence-point -fno-strict-aliasing -DNDEBUG
     -UDEBUG -g -D__compiler_offsetof=__builtin_offsetof
     -Werror=int-conversion -nostdlibinc -msse3 -fPIC
     -I external/compiler-rt
     external/compiler-rt/lib/builtins/mulodi4.c
    "
  "$EPREFIX/usr/bin/clang" $f || die "mulodi4.o resists, flags=$1"
 }

src_compile()
 {
  # create 2 static libraries libcompiler_rt-extras.a in out/target/product/
  #  x86_64/@/STATIC_LIBRARIES/libcompiler_rt-extras_intermediates/ where @ is
  #  obj_x86 or obj. Do it without makefile, directly call clang then ar
  local ar="$my_root/bin/ar"
  [ -x "$ar" ] || 
   {
    ar="$my_root/bin/ar-stage1"
    [ -x "$ar" ] || 
     {
      ar="$my_root/bin/ar-stage0"
      [ -x "$ar" ] || die "failed to find ar executable"
     }
   }
  local i
  for i in 32 64 ; do
   local j=obj
   local arch=x86-64
   [ $i == 32 ] && { j=${j}_x86; arch=i686; }
   local archT=${arch/-/_}-linux-android
   j=out/target/product/x86_64/$j/STATIC_LIBRARIES
   j=$j/libcompiler_rt-extras_intermediates
   mkdir -p $j || "mkdir failed, i=$i"
   >$j/export_includes || "export_includes resist"
   clang_mulodi4 "-m$i -march=$arch -target $archT" $j/mulodi4.o
   cd $j || die "chdir to $j failed"
   "$ar" crsD libcompiler_rt-extras.a mulodi4.o || die "ar failed"
   einfo "created libcompiler_rt-extras.a in `pwd`"
   cd "$S" || exit
  done
  # there is no NOTICE file in llvm .zip. NOTICE files are only present in
  #  bionic/ tree
  >NOTICE-TARGET-STATIC_LIBRARIES-libcompiler_rt-extras
  einfo "llvm compiler-rt built"

  # To keep zillion ANDROID_* definitions away from /var/db/... , start lunch in
  #  a separate shell process
  lunch-make-script
  # cook targets
  j=""
  for i in libc libdl libm linker ; do
   j="$j $i ${i}_32"
  done
  local o=out/target/product/x86_64/obj
  # crtend* comes without invitation, but crtbegin_* want invitation
  for i in dynamic static so; do
   j="$j $o/lib/crtbegin_$i.o"
   j="$j ${o}_x86/lib/crtbegin_$i.o"
  done
  sed -i lunch-make.sh -e s-@path-/usr/bin:/bin-g -e "s:@tgt:$j:"

  # TODO: which make
  "$BASH" ./lunch-make.sh || die "lunch-make failed"
 }

cp_so_m()
 {
  [ -f $1 ] || die "library not found: $1"
  mkdir -p "$2" || die "cp_so_m(); directory $2 resists"
  cp $1 "$2" || die "cp $1 '$2' failed"
  einfo "installed $1"
  local a=$(echo $1|sed s:/lib.*::)/STATIC_LIBRARIES
  einfo "cut-off lib: $a"
  local b=$(basename ${1%.so}).a
  local c=$(find $a -name $b -type f)
  [ -z "$c" ] && { einfo "failed to find $b in $a"; return; }
  [ -f $c ] || die "not file $c"
  cp $c "$2" || die "cp $a '$2' failed"
 }

QA_PRESTRIPPED="/system/lib.*"

src_install()
 {
  # Android does not follow Linux directory convention
  rm -rf "$ED/system"
  local i
  mkdir -p "$ED/system/bin" || die "/system/$bin resists"

  # please those who have 32-bit x86 tablet and sym-limk lib32 as lib
  ( cd $ED/system; ln -s lib32 lib )

  local p=out/target/product/x86_64
  local j=0
  for i in $p/system/bin/li* ; do
   [ -f $i ] || continue
   cp $i "$ED/system/bin/" || die "$i resists"
   j=$((j+1))
  done
  [ $j == 0 ] && die "binary interpreters not found"
  einfo "$j binaries installed"

  local so="m dl c stdc++"
  for i in $so; do
   local k=lib${i}.so
   j=$p/obj/lib/$k
   cp_so_m $j "$ED/system/lib64"
   j=$p/obj_x86/lib/$k
   cp_so_m $j "$ED/system/lib32"
  done

  # 5*2 compiler stubs
  for i in {begin,end}_so end_android begin_{static,dynamic} ; do
   local jj=$(find out -type f -wholename "*x86_64/*crt$i.o")
   [ -z "$jj" ] && die "crt$i.o not found"
   for j in $jj ; do
    [ ${j/obj_x86/} == $j ] && k=lib64 || k=lib32
    k="$ED/system/$k"
    cp $j $k || die "compiler stub: cp $j $k failed"
   done
  done

  # clean
  unset my_root a B g TGT build_sha sha dg pstglia pstglia_sha0 pstglia_sha1 \
   llvm_sha
 }
