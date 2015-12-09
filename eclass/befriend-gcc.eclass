# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

inherit toolchain-funcs

maybe_find_tool()
 {
  local d="$EPREFIX/usr/x86_64-linux-android/bin"
  [ $1 == ld ] && 
   {
    # select ld or ld-stage0, not stage1
    [ -x "$d/$1" ] && { echo "$d/$1" ; return; }
    [ -x "$d/${1}-stage0" ] && { echo "$d/$1-stage0" ; return; }
   }
  [ -x "$d/$1" ] && { echo "$d/$1" ; return; }
  [ -x "$d/${1}-stage1" ] && { echo "$d/$1-stage1" ; return; }
  [ -x "$d/${1}-stage0" ] && { echo "$d/$1-stage0" ; return; }
 }

find_tool()
 {
  local d=$(maybe_find_tool $1)
  [ -z "$d" ] && die "failed to find tool $1"
  echo "$d"
 }

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

gxx-in-package()
 {
  [ -z $1 ] ||
   {
    (equery f $1|fgrep /gcc-bin/|egrep -- -g++$|head -1) 2>/dev/null
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
  c=$(gxx-in-package $c)
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
  local triple=x86_64-linux-android
  local linker_home="$S/$b/bin"
  local spec="$EPREFIX/usr/$triple/share/gcc.specs"
  [ -s "$spec" ] || die "gcc.specs not found. Install bionic-core/gcc-specs"
  rm -rf $b ; mkdir -p $b/{lib,bin,libexec} || die "out of disk space on lib,"

  # populate bin
  cd $b/bin
  local i
  # take ld or ld-stage1 or ld-stage0
  for i in ld as ; do
   j=$(find_tool $i)
   ln -s "$j" $i
  done
  # if other tools exist, link them
  for i in nm objcopy objdump readelf ar ranlib; do
   j=$(maybe_find_tool $i)
   [ -z "$j" ] || ln -s "$j" $i
  done
  # GCC wants x86_64-linux-android-nm to compile himself, so we sym-link
  for i in * ; do
   [ -x $i ] && ln -s $i ${triple}-$i
  done
   
  donor=$("$1" -print-prog-name=cc1|xargs dirname)
  for i in $(ls "$donor") ; do
   ln -s $donor/$i
  done

  # populate libexec
  cd ../libexec ; mkdir gcc || die "out-of-space creating gcc"; cd gcc
  o=$("$1" -print-prog-name=liblto_plugin.so)
  cp -L "$o" . || die "plugin $o resists"
  # put 32-bit libgcc.a to libexec
  cd ..; ln -s $("$1" -m32 -print-file-name=libgcc.a)
  # ld message 'skipping incompatible .../lib/libgcc.a' is not a bug but feature

  # populate lib
  cd "$S/$b/lib"
  local donor=$("$1" -print-file-name=libgcc.a|xargs dirname)
  for i in $(ls "$donor") ; do
   ln -s $donor/$i
  done
  # We already have libstdc++ in /system/lib64, don't overdoze
  rm -f libstdc++.*
  
  o="-mandroid -D__ANDROID__"
  o="$o -specs='$spec' --sysroot=/no.such.file.$RANDOM.$PPID -nostdinc"
  # Force usage of our linker which is already in bin/ld
  o="$o -B '$linker_home'"
  # Don't use GNU unique binding
  o="$o -fno-gnu-unique"
  spec=$(dirname "$spec"|xargs dirname)/include
  o="$o -isystem '$spec' -isystem '$donor/include' -Wl,-L,/system/lib64 -pie"
  i=${b/-/.}
  # portage sets LD_PRELOAD=libsandbox.so; the library fails to load under
  #  /system/bin/linker64; we create a fake .so that does nothing
  local dummy_sandbox=libsandbox
  export cxx_exe="$1"
  echo "//Walk-around libsandbox.so incompatibility problem" |
   "$1" -xc - -O3 -c -mandroid -o$dummy_sandbox.o
  local link_so="$EPREFIX/usr/x86_64-linux-android/share/link-so"
  "$link_so" -Wl,-soname,$dummy_sandbox.so \
   -Wl,-shared $dummy_sandbox.o -o$dummy_sandbox.so >/dev/null ||
    die "$dummy_sandbox compilation failed"
  rm $dummy_sandbox.o
  cd "$S"

  {
   echo '#!/bin/sh'
   echo 'u=$(echo "$@"|grep -c -- --print-multi-lib)'
   echo '[ $u == 0 ] || { echo ".;" "32;@m32"; exit; }'
   echo "@GCC_EXEC_PREFIX='$b/libexec/gcc/has_cryptic_directory_structure'"
   echo "@LIBRARY_PATH='/system/lib64:$b/lib'"
   echo "@LD_LIBRARY_PATH='$b/lib'"
   echo '[ -x "@BIN/ld" ] ||'
   echo ' {'
   echo '  echo "$0: where is my linker?" 1>&2'
   echo '  echo "Put it into @BIN and call me again" 1>&2'
   echo '  exit 1'
   echo ' }'
   echo "@cxx_exe='$cxx_exe'"
   echo 's=$(echo "$@"|fgrep -c -- -Wl,-shared)'
   echo 'u=$(echo "$@"|fgrep -c -- -Wl,-soname)'
   echo "[ \${s}\$u == 00 ] || exec '$link_so' \$@"
   echo 'v=$(echo "$@"|grep -c -- " -o")'
   echo '[ $v == 0 ] ||'
   echo ' {'
   echo '  v=$("$EPREFIX/usr/bin/realpath" . --relative-to "$S")'
   echo '  echo "$0: from $v called with $@"'
   echo ' }'
   echo "@PATH='$b/bin:$EPREFIX/system/bin'"
   echo "'$1' $o -DGCC_IS_HYPNOTIZED \$@"
  } | sed \
   -e 's:^@:export :g' \
   -e "s>$b>$S/$b>g" \
   > $i
  sed -i $i -e "s>@BIN>$linker_home>g"
  chmod +x $i

  # the executable will print the name of its creator
  ( printf '#include <stdio.h>\nint main() { printf("@"); return 0; }' |
   sed "s:@:$S/$i:" | ./$i -xc - -O3 -ohello_world.exe &> /dev/null) ||
    die "hypnosis failed"
  # good thing linker64 does not care about /usr/lib64 but respects
  #  LD_LIBRARY_PATH
  LD_LIBRARY_PATH=$b/lib ./hello_world.exe || die "executable does not run"
  popd >/dev/null
  # export LD_LIBRARY_PATH="$S/$b/lib" this does not work, must export elsewhere
 }

find-then-hypnotize-gcc()
 {
  local c=$(find_gcc $1)
  hypnotize-gcc "$c"
 }

stage0-ld-please()
 {
  (
   cd $S/hypnotized-gcc/bin || die "directory $S/hypnotized-gcc/bin went away"
   ln -sf "$EPREFIX/usr/x86_64-linux-android/bin/ld-stage0" ld
   [ -x ld ] || die "not executable `pwd`/ld"
  )
 }

un-hypnotize-gcc()
# extract and print executable name from last line of script $1
 {
  local i=$(tail -1 "$1"|sed 's> .*>>') ; i=${i#\'}; i=${i%\'};
  echo "$i"
 }

hypnotize-gxx-too()
# $1: hypnotized gcc script
# print hypnotized g++ script name
 {
  local c=$(un-hypnotize-gcc "$1")
  [ -x "$c" ] || die "not executable $c"
  local cxx_exe=${c%cc}'++'
  #echo "$c -> $cxx_exe" 1>&2
  [ -x "$cxx_exe" ] || die "no such file $cxx_exe, don't know how to define CXX"
  local cxx=${1%cc}'++'
  sed -e "s>$c>$cxx_exe>" < "$1" > "$cxx" || die "failed to cook g++ script"
  chmod +x "$cxx"
  # compiler will want to find his cstddef and other files
  local w=cstddef
  local cxx_p=$(equery b "$cxx_exe")
  local i=$(equery f $cxx_p|fgrep $w|head -1)
  [ -f "$i" ] || die "failed to find $w include"
  i=$(dirname "$i")
  local u=${w}-and-friends
  local q=${1/ized.gcc/ized-gcc}
  ( mkdir -p "$q/include" ;  cd "$q/include"; ln -s "$i" $u ||
   die "failed to link g++ includes" )
  sed -i "$cxx" -e "s>-DGCC_IS_HYPNOTIZED>& -isystem '$q/include/$u'>"
  # ... and bits/*.h
  w=bits/c++config.h
  i=$(equery f $cxx_p|fgrep $w|grep -v /32/bits|head -1)
  [ -f "$i" ] || die "failed to find $w include"
  i=$(dirname "$i")
  u='more-friends-20151123'
  pushd "$q/include" >/dev/null
  mkdir -p $u; cd $u; cp -r "$i" . || die "failed to cp bits/ includes"
  sed -i "$cxx" -e "s>-DGCC_IS_HYPNOTIZED>& -isystem '$q/include/$u'>"
  # patch GLIBC-specific bits/os_defines.h
  sed -i bits/os_defines.h -e 's:__GLIBC_PREREQ(2,15):0:g' ||
   die "patching GLIBC artefact failed"
  echo "$cxx"
  popd >/dev/null
 }
