# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

# todo: remove /lib64 and /usr/lib64 from library search path

EAPI=5
inherit befriend-gcc check-reqs gcc-configure
HOMEPAGE=http://gcc.gnu.org/
LICENSE=GPL-3
SRC_URI="mirror://gnu/gcc/gcc-$PV/gcc-$PV.tar.bz2"
KEYWORDS=amd64
SLOT=${PV%.?}
b=bionic-core
# need nm and other tools that can find lto plugin, use standard gcc for that
DEPEND="$b/0gcc $b/isl $b/mpc $b/mpfr $b/GNU_STL >=sys-devel/gcc-4.9.0"
RDEPEND="$b/binutils[-stage0] $b/GNU_STL"

CHECKREQS_DISK_BUILD=800M
src_unpack()
 {
  [ -z $LD_PRELOAD ] || die "Sorry, this .ebuild does not support sandbox"
  gcc-unpack

  # GCC tries to compile libstdc++-v3 and fails, though configured to skip the
  #  library
  rm -rf $gcc_srcdir/libstdc++-v3
 }

src_prepare()
 {
  cd $gcc_srcdir
  # bionic linker does not support rpath, so we optimize link command-line
  sed -e 's:-rpath.$.toolexeclibdir.::g' -i `find . -name Makefile.in -type f` ||
   die 'rpath resists'

  cd gcc
  # a in version stands for Android
  echo ${PV}a > BASE-VER || die "BASE-VER resists"

  # Inject -lgnustl_shared automagically into collect2 command-line
  ( cd cp; patch -p0 < "$FILESDIR/gnustl_automagic.diff" ||
     die "g++spec resists" )

  # turn off a loong subroutine that creates a loong libgcc setting; use -lgcc
  sed -i gcc.c -e \
   's:defined.ENABLE_SHARED_LIBGCC..&&.!defined.REAL_LIBGCC_SPEC.:0:g' \
   -e 's:=.LIBGCC_SPEC;:= "-lgcc";:g' || die "gcc|libgcc_spec resists"

  # link with g++ not with gcc
  # sed -i Makefile.in -e 's:ifeq..$.HOST_LIBS.,.:ifneq (use,g++):'

  # Force /system/lib64 into library search path
  local s='Sysrooted prefixes are relocated because target_system_root is'
  local a='add_prefix(&startfile_prefixes,\"/system/lib64/\",'
  local a="${a}NULL,PREFIX_PRIORITY_B_OPT,0,1);"
  sed -i gcc.c -e "\:$s:i $a" || die 'gcc startfile_prefixes resist'

  # /lib and /usr/lib out of library path
  s='#define STANDARD_STARTFILE_PREFIX_'
  for a in 1 2 ; do
   sed -i gcc.c -e "s:${s}$a .*:${s}$a \"\":" || die 'gcc /lib resists'
  done

  # To reduce length of library search path, disable
  #  UPDATE_PATH_HOST_CANONICALIZE magic
  sed -i prefix.c -e 's:#ifdef UPDATE_PATH_HOST_CANONICALIZE:#if 0:'

  # to make /system/bin/linker64 happy, must use pie flag when compiling or
  #  linking. Directive like below published by Magnus Granberg 2014-07-31
  (
   echo '#define DRIVER_SELF_SPECS \'
   echo '"%{pie|fpie|fPIE|fno-pic|fno-PIC|fno-pie|fno-PIE| \'
   echo ' shared|static|nostdlib|nodefaultlibs|nostartfiles:;:-fPIE -pie}"'
  ) >> config/linux-android.h || die "linux-android.h resists"

  # aint need no local/include
  (
   echo '#undef LOCAL_INCLUDE_DIR'
   echo '#undef NATIVE_SYSTEM_HEADER_DIR'
   echo "#define NATIVE_SYSTEM_HEADER_DIR \"/usr/$triple/include\""
  ) >> config/linux-android.h

  export CC=`0gcc-gcc`
  export CXX=`0gcc-gxx`
  # stage 1 compiler does not understand -funconfigured-libstdc++-v3, and fails
  #  to find standard c++ include files like <string>
  cXXi=$(gxx-include $CXX)
  local j=$cXXi/$triple
  sed -i $gcc_srcdir/configure -e \
   "s:echo.-funconfigured-libstdc++-v3:echo -isystem $cXXi -isystem $j:" ||
   die "unconfigured-libstdc++ resists"

  a='-z noexecstack -z relro -z now'
  # add $a to linker options, to match NDK specs
  sed -i config/linux-android.h -e \
   "s^\"%{shared: -Bsymbolic}\"^\"%{shared: -Bsymbolic} $a\"^"
 }

src_configure()
 {
  saved_PATH="$PATH"
  o=`native-gcc-configure-options`
  emake=`which emake`
  local p=`which strip|xargs dirname|xargs dirname|xargs dirname`
  export PATH=$p/usr/bin:$p/bin
  einfo "configure options: $o"
  "$gcc_srcdir/configure" $o || die "configure failed"
 }

src_compile()
 {
  $emake
 }

src_install()
 {
  # install: cannot stat '.libs/libgomp.lai'
  # Solve this problem by putting .lai wherever .la exists
  local i
  for i in `find . -name '*.la'` ; do
   [ -f ${i}i ] && einfo "${i}i already exists"
   [ -f ${i}i ] ||
    (
     einfo "creating ${i}i"
     cp -L $i ${i}i || die ".lai: cp $i failed"
    )
  done

  $emake DESTDIR="$ED" install ||
   die "make install failed, parallel make issue?"

  PATH="$saved_PATH"

  cd "$ED/usr" || die '/usr missing'
  # all 32-bit libraries shall be under lib32/ or 32/
  mv lib lib32 || die "lib directory missing"
  # this way gcc will fail to find includes, must move lib32/lib
  ( cd lib32; mv lib .. || die "lib32/lib resists" )

  # Put ld into libexec/...
  cp -L $EPREFIX/usr/$triple/bin/ld-stage1 libexec/gcc/$triple/${PV}a/ld ||
   die "ld-stage1 resists"
  QA_PRESTRIPPED='/usr/.*'

  # copy C++ headers
  i=include/c++/${PV}a
  mkdir -p $i ; cp -r $cXXi/* $i || die "C++ headers resist"

  # Put everything under /usr/$triple/, by moving the whole tree
  i=`ls`
  mkdir $triple && mv $i $triple/ || die "mv to $triple/ failed"

  # 64-bit libraries are now in /usr/$triple/lib64; 32-bit in
  #  /usr/$triple/lib. Sym-link compiler stub and bionic libraries so collect2
  #  finds them
  cd $triple/lib64
  symlink-stub /system/lib64
  cd ../lib32
  symlink-stub /system/lib32

  # name x86_64-linux-android-gcc-ar appears strange to me. Link
  #  x86_64-linux-android-ar -> x86_64-linux-android-gcc-ar
  cd ../bin || die
  for i in `ls x86_64-linux-android-gcc-*` ; do
   [ -f $i ] && ln -s $i ${i/gcc-/} 2>/dev/null
  done

  unset k CHECKREQS_DISK_BUILD gcc_srcdir emake triple root saved_PATH b cXXi
 }
