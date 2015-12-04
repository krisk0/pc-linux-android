# Copyright     2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v3

EAPI=5
HOMEPAGE=https://gcc.gnu.org/libstdc++
SLOT=0
KEYWORDS=amd64

DESCRIPTION="A piece of GNU libstdc++.so installed as libgnustl_shared.so"
# 2 libraries installed: 32-bit (-m32) and 64-bit (-m64). No mx32 variant

DEPEND="bionic-core/bionic bionic-core/binutils[-stage0] bionic-core/gmp
>=sys-devel/gcc-4.9.3"
# gcc configure will be unhappy without gmp, mpfr, mpc
SRC_URI="mirror://gnu/gcc/gcc-$PV/gcc-$PV.tar.bz2
 http://www.mpfr.org/mpfr-current/mpfr-3.1.3.tar.xz
 http://www.multiprecision.org/mpc/download/mpc-1.0.2.tar.gz"

k=krisk0
inherit befriend-gcc gcc-configure
l=libstdc++-v3

CHECKREQS_DISK_BUILD=750M   # peak usage inside src_unpack()
src_unpack()
 {
  [ -z "$LD_PRELOAD" ] || die "Sorry, this .ebuild does not support sandbox"
  gcc-unpack
  saved_PATH="$PATH"
 }

src_prepare()
# This subroutine only patches sub-directory libstdc++-v3, nothing else
 {
  cd ../gCc/$l || die "lost in `pwd`"
  patch="$FILESDIR/libstdc-20151120.diff"
  patch -p0 < "$patch" || die "patch failed"
  # This patch will be used in other .ebuild scripts
 }

maybe-hypnotize-gcc()
 {
  # if a good compiler is installed, use it
  local p=$(best_version bionic-core/gcc)
  [ -z $p ] || { gcc-in-package $p; return; }
  # no suitable compiler found, will hypnotize regular gcc
  hypnotize-gcc $(find_gcc 490)
 }

maybe-hypnotize-gxx()
 {
  [ $(basename "$1") == hypnotized.gcc ] && ( hypnotize-gxx-too "$1"; return )
  local p=$(best_version bionic-core/gcc)
  gxx-in-package $p
 }

inject()
 {
  sed -i "$1" -e "/^#add lib/i $2"
 }

refine-link-so()
 {
  # make it so extra libraries .libs/take.us/*.o are added when linking a .so
  local o="$EPREFIX/usr/x86_64-linux-android/share/link-so"
  local n=$(dirname "$CC")/link-so
  sed -e "s>$o>$n>" -i "$CC"
  sed '/^b=/a #add libgcc_eh.a' < "$o" > "$n"
  # line below finds .o then replaces end-of-line with space
  inject "$n" 'a=$(find .libs/take.us -name '"'"'*.o'"'"' -type f|xargs echo)'
  inject "$n" 'b=$(echo "$b"|sed "s>-lm>$a &>")'
  inject "$n" 'echo "cwd=`pwd` link-so flags: $b"'
  inject "$n" '[ -z "$b" ] && exit 1'
  sed -i "$n" -e '/^#add lib/d' || die 'final touch'
  chmod +x "$n"
 }

src_configure()
 {
  triple=x86_64-linux-android
  export CC=`maybe-hypnotize-gcc`
  # create list of supported multilib directories
  local i
  unset m
  for i in $("$CC" --print-multi-lib) ; do
   local j=`echo $i | sed 's/;.*$//'`
   [ $j == '.' ] ||
    {
     [ -z "$m" ] && m=$j || m="$m $j"
    }
  done
  einfo "multilib directories: $m"
  refine-link-so
  einfo "improved link-so"
  export CXX=$(maybe-hypnotize-gxx "$CC")
  einfo "G++ hypnotized"
  # GCC configure scripts want compiler executable in current multilib
  #  directory, so we sym-link
  for i in $m ; do
   j=../$i/$k
   { mkdir -p $j && cd $j; } || die "32-bit directory $j resists"
   for j in cc ++ ; do
    ln -s ../../$k/hypnotized.g$j || die "sym-link on hypnotized gcc failed"
   done
   cd "$S"
  done
  local f="-enable-multilib"
  f="$f --enable-libstdcxx-time --disable-symvers --disable-nls --with-pic"
  f="$f --disable-sjlj-exceptions --disable-tls --disable-libstdcxx-pch"
  # mstackrealign: assume stack on subroutine entry is mis-aligned
  local o='-ffunction-sections -fdata-sections -mstackrealign'
  o="$o -O2 -fPIC -fexceptions -frtti -funwind-tables -D__BIONIC__"
  export CFLAGS="$o"
  export CXXFLAGS="$o"
  local h=$triple
  local root="$EPREFIX/usr/$h"
  ../gCc/$l/configure --host=$h --build=$h --target=$h \
   --disable-static --enable-shared \
   $f || die "gCc/configure failed"

  # Compiler command-line is stupid:
  #  -DPIC <...no files in-between> -Xcompiler-static -UPIC
  # First of all, -Xcompiler-static is passed un-modified to $CC and brings in
  #  error. Secondly, it is stupid to define PIC then undefine it

  # We remove the stupid flag addition that breaks compilation
  cd ..
  for i in `find -type f -wholename *src/Makefile` ; do
   sed -i $i -e 's:-Xcompiler-static.*::' || die '-Xcompiler resists'
  done

  i="Messages 'ld: skipping incompatible ...' during compilation"
  einfo "$i are normal, never mind"
 }

# To create gnustl_shared.so with stack unwinding stuff, we need to compile
#  libgcc_eh.a. This file is created by gcc at some stage of compiling itself.
#  We lack a C++ library and cannot normally get to that stage. So we compile
#  libgcc_eh.a bypassing configure/make

build_libgcc_eh_a()
# $1/take.us target dir
# $2 compile flag
 {
  [ -z "$2" ] && einfo "building libgcc_eh.a in $1" ||
   einfo "building libgcc_eh.a in $1, extra compile flag: $2"
  local o="unwind-dw2 unwind-dw2-fde-dip unwind-sjlj unwind-c emutls"
  local f="$2 -pipe -O2 -Os -g -DIN_GCC -W -Wall -Wno-narrowing"
  f="$f -DTARGET_POSIX_IO -fno-short-enums -DCROSS_DIRECTORY_STRUCTURE"
  f="$f -Wwrite-strings -Wcast-qual -Wno-format -Wstrict-prototypes"
  f="$f -Wmissing-prototypes -Wold-style-definition -isystem ./include -fPIC"
  f="$f -mlong-double-80 -funwind-tables -DENABLE_DECIMAL_BID_FORMAT -DUSE_TLS"
  f="$f -DIN_LIBGCC2 -fbuilding-libgcc -fno-stack-protector"
  f="$f -fexceptions "
  f="$f -I../include -I../gcc"
  # need some includes pre-cooked by build scripts
  mkdir -p "$1"
  local d=$(realpath "$1" --relative-to="$libgcc_src")
  local t=$d/take.us
  pushd "$libgcc_src" 1>/dev/null || die "libgcc is gone"
  mkdir $t || die 'build_libgcc_eh_a(): $t resists'
  cooked=$(realpath $d/../../include/$triple --relative-to=.)
  [ -z $cooked ] && die "where is cooked include for $d?"
  [ -d $cooked/bits ] || die "failed to find bits directory, d=$d"
  [ -f $cooked/bits/gthr-default.h ] || die "gthr-default.h is gone, d=$d"
  f="$f -I$cooked -I$cooked/bits"
  local i
  einfo "sitting in `pwd` compiling with flags $f"
  for i in $o ; do
   "$CC" $f $i.c -c -o $t/$i.o || die "$i.o resists"
  done
  popd 1>/dev/null
 }

h_files()
 {
  local o="$(gcc-configure-options)"
  local h=${triple%android}gnu
  o="$o --target=$triple --host=$h --build=$h"
  local d=$(realpath "$1")
  [ -z "$emake" ] && emake=`which emake`
  export PATH="$S/bin:$EPREFIX/usr/bin:$EPREFIX/bin"
  mkdir -p ../h_files; cd ../h_files || die "h_files resist"
  old_CFLAGS="$CFLAGS"
  export CFLAGS="$CFLAGS -fPIC"
  ../gCc/configure $o || die "h_files(): configure failed"
  # -DPKGVERSION="\"(GCC) \"" is ok for g++, but not for POSIX script wrapper
  #   around g++. Eliminating spaces inside such strings solves the problem
  "$emake" configure-gcc
  sed -i gcc/Makefile \
   -e 's:(GCC) :(GCC):' \
   -e 's:$(DEVPHASE_c), :$(DEVPHASE_c),:g' \
    || die 'healing gcc/Makefile failed'
  local l=libiberty.a
  local b=build-x86_64-linux-gnu/libiberty
  mkdir -p $b && cp libiberty/$l $b/ ||
   die "failed to copy $l"
  cd gcc && cp auto-host.h "$d/" || die "auto-host.h resists"
  local h='tm.h tconfig.h options.h insn-constants.h insn-modes.h insn-codes.h'
  "$emake" $h
  cp $h "$d/" || die "tconfig.h resists"
  einfo 'put 7 auto-generated header files into gcc/'
  CFLAGS="$old_CFLAGS"
  cd "$S"
 }

src_compile()
 {
  libgcc_src="$WORKDIR/gCc/libgcc"
  h_files "$libgcc_src"
  # glibc_tm.h does nothing except including i386/value-unwind.h
  i386="$libgcc_src/config/i386"
  local libgcc_tm="$i386/value-unwind.h"
  cp "$libgcc_tm" "$libgcc_src/libgcc_tm.h" || die 'value-unwind.h resists'
  # md-unwind-support.h is just a sym-link to i386/linux-unwind.h
  cp "$i386/linux-unwind.h" "$libgcc_src/md-unwind-support.h" ||
   die "linux-unwind.h resists"

  build_libgcc_eh_a src/.libs ""
  local i
  for i in $("$CC" --print-multi-lib) ; do
   local d=`echo $i | sed 's/;.*$//'`
   local o=`echo $i | sed 's/.*;@//'`
   [ "$d" == . ] || build_libgcc_eh_a ../$d/$k/src/.libs -$o
  done
  einfo "built stack unwinding .o"
  "$emake"
 }

src_test()
 {
  einfo "Sorry, test not implemented"
 }

# some configure scripts support --with-multisubdir magic, some do not. We
#  silence portage warning message concerning this
QA_CONFIGURE_OPTIONS='--with-multisubdir --with-multisrctop'

src_install()
 {
  export PATH="$saved_PATH"
  cd ..
  local n=libgnustl_shared.so
  local p="$ED/usr/$triple/lib"
  local i
  for i in $m; do
   local j="${p}$i"
   mkdir -p $j
   mv $(find $i -name $n -type f) $j || die "$i/....so resists, cwd=`pwd`"
  done
  j=${p}64
  mkdir -p $j
  mv $(find . -name $n -type f) $j || die "64-bit .so resists"
  p="${p%lib}share"
  i=$(basename "$patch")
  mkdir -p "$p"
  lzma < "$patch" > "$p/$i.lzma" || die "installation of $i failed"
  unset k l m patch triple emake root libgcc_src saved_PATH
 }
