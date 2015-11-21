# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

inherit toolchain-funcs

gcc_your_include()
 {
  local cc1=$($1 -print-prog-name=cc1) || die "$1 refuses to cooperate"
  local d=$(echo|$cc1 -v 2>&1|grep usr/lib/gcc|
            egrep -v '^ignoring nonexistent directory'|
            fgrep -v include-fixed|head -1)
  # I thought $(smth) should give stripped string, but line above produced
  #  directory prefixed by space. Is that bug or feature?
  d=$(echo $d)
  [ -d "$d" ] || die "ask_gcc_for_include() failed"
  echo "$d"
 }

gcc_your_version()
 {
  # file that does not run or exists has by definition version 0
  [ -x "$1" ] || { echo 0; return; }
  "$1" -E -P - <<<"__GNUC__ __GNUC_MINOR__ __GNUC_PATCHLEVEL__" |
   sed -e 's: ::g'
 }

gcc-in-package()
 {
  [ -z $1 ] ||
   {
    (equery f $1|fgrep /gcc-bin/|egrep -- -gcc$|head -1) 2>/dev/null
   }
 }

find-gcc-in-category()
 {
  local s=$(( $2/100 ))
  local j=$(( ($2-100*s)/10 ))
  local k=$(( $2-100*s-10*j ))
  local c=$(best_version ">=$1/gcc-$s.$j.$k")
  c=$(gcc-in-package $c)
  [ $(gcc_your_version "$c") -ge $2 ] && echo "$c"
 }

find-gxx-in-category()
 {
  local s=$(( $2/100 ))
  local j=$(( ($2-100*s)/10 ))
  local k=$(( $2-100*s-10*j ))
  local c=$(best_version ">=$1/gcc-$s.$j.$k")
  c=$(equery f $c|fgrep /gcc-bin/|fgrep -- -g++|head -1)
  [ $(gcc_your_version "$c") -ge $2 ] && echo "$c"
 }

find_gcc()
# $1: required version such as 520 for 5.2.0
# print to stdout gcc executable name
 {
  # respect user setting and try $CC first
  [ $(gcc_your_version "$CC") -ge $1 ] && { echo "$CC" ; return; }
  c=$(find-gcc-in-category sys-devel $1)
  [ -z "$c" ] || { echo $c; return; }
  c=$(find-gcc-in-category cross-x86_64-pc-linux-uclibc $1)
  [ -z "$c" ] || { echo $c; return; }
 }

find_gxx()
# $1: required version such as 520 for 5.2.0
# print to stdout g++ executable name
 {
  # respect user setting and try $CXX first
  [ $(gcc_your_version "$CXX") -ge $1 ] && { echo "$CXX" ; return; }
  local c=`which g++`
  [ $(gcc_your_version "$c") -ge $1 ] && { echo "$c" ; return; }
  c=$(find-gxx-in-category sys-devel $1)
  [ -z "$c" ] || { echo $c; return; }
  c=$(find-gxx-in-category cross-x86_64-pc-linux-uclibc $1)
  [ -z "$c" ] || { echo $c; return; }
 }

hypnotize-gcc()
# $1: gcc executable name
# Create a shell script that convinces the gcc to act as a native
#  x86_64-linux-android compiler. Put the script into $S/hypnotized.gcc. Print
#  the file-name to stdout
 {
  pushd "$S" >/dev/null
  echo "Hypnotizing $1" 1>&2
  local b=hypnotized-gcc
  local spec="$EPREFIX/usr/x86_64-linux-android/share/gcc.specs"
  [ -s "$spec" ] || die "gcc.specs not found. Install bionic-core/gcc-specs"
  rm -rf $b ; mkdir -p $b/{lib,bin,libexec} || die "out of disk space on lib,"
  # populate bin
  cd $b/bin
  local o="$EPREFIX/usr/x86_64-linux-android/bin"
  local i
  # take ld or ld-stage1 or ld-stage0
  for i in ld as ; do
   local j="$o/$i"
   [ -x "$j" ] && { ln -s "$j" ; continue; }
   j=${j}-stage1
   [ -x "$j" ] && { ln -s "$j" ; continue; }
   j=${j%1}0
   [ -x "$j" ] || die "failed to find $i. Install bionic-core/binutils"
   ln -s "$j" $i
  done
  donor=$("$1" -print-prog-name=cc1|xargs dirname)
  for i in $(ls "$donor") ; do
   ln -s $donor/$i
  done
  # populate libexec
  cd ../libexec ; mkdir gcc || die "out-of-space creating gcc"; cd gcc
  o=$("$1" -print-prog-name=liblto_plugin.so)
  cp -L "$o" . || die "plugin $o resists"
  # populate lib
  cd "$S/$b/lib"
  local donor=$("$1" -print-file-name=libgcc.a|
  xargs dirname)
  for i in $(ls "$donor") ; do
   ln -s $donor/$i
  done
  o="-mandroid -specs='$spec' --sysroot=/no.such.file.$RANDOM.$PPID -nostdinc"
  spec=$(dirname "$spec"|xargs dirname)/include
  o="$o -isystem '$spec' -isystem '$donor/include' -Wl,-L,/system/lib64"
  i=${b/-/.}
  # portage sets LD_PRELOAD=libsandbox.so; the library fails to load under
  #  /system/bin/linker64; disabling sandbox does not work. To walk-around 
  #  this portage bug, create fake libsandbox.so
  local fuck_sandbox=libsandbox
  echo "//Walk-around portage-sandbox-does-not-turn-off-bug" |
   "$1" -xc - -O3 -c -mandroid -o$fuck_sandbox.o
  "$1" -mandroid -nostdinc -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now \
   -Wl,--warn-shared-textrel -Wl,--gc-sections -Wl,--hash-style=sysv \
   -nostdlib -Wl,-soname,$fuck_sandbox.so -Wl,-shared $fuck_sandbox.o \
   -o$fuck_sandbox.so ||
    die "$fuck_sandbox compilation failed"
  rm $fuck_sandbox.o
  cd "$S"

  {
   echo '#!/bin/sh'
   echo "@GCC_EXEC_PREFIX='$b/libexec/gcc/has_cryptic_directory_structure'"
   echo "@LIBRARY_PATH='/system/lib64:$b/lib'"
   echo "@LD_LIBRARY_PATH='$b/lib'"
   echo "@PATH='$b/bin:$EPREFIX/system/bin'"
   echo "'$1' $o -DGCC_IS_HYPNOTIZED \$@"
  } | sed \
   -e 's:^@:export :g' \
   -e "s>$b>$S/$b>g" \
   > $i
  chmod +x $i

  # the executable will print the name of its creator
  ( printf '#include <stdio.h>\nint main() { printf("@"); return 0; }' |
   sed "s:@:$S/$i:" | ./$i -xc - -O3 -v -ohello_world.exe ) ||
    die "hypnosis failed"
  # good thing linker64 does not care about /usr/lib64 but respects 
  #  LD_LIBRARY_PATH
  LD_LIBRARY_PATH=$b/lib ./hello_world.exe || die "executable does not run"
  popd >/dev/null
  # export LD_LIBRARY_PATH="$S/$b/lib" this does not work, must export elsewhere
 }
