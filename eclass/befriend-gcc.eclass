# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

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
  # file that does not run assigned 0 
  [ -x "$1" ] || { echo 0; return; }
  "$1" -E -P - <<<"__GNUC__ __GNUC_MINOR__ __GNUC_PATCHLEVEL__" | 
   sed -e 's: ::g'
 }

find-gcc-in-category()
 {
  local s=$(( $2/100 ))
  local j=$(( ($2-100*s)/10 ))
  local k=$(( $2-100*s-10*j ))
  local c=$(best_version ">=$1/gcc-$s.$j.$k")
  c=$(equery f $c|fgrep /gcc-bin/|fgrep -- -gcc|head -1)
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
# $1: required version such as 52 for 5.2.0
 {
  # respect user setting and try $CC first
  [ $(gcc_your_version "$CC") -ge $1 ] && { echo "$CC" ; return; }
  local c=`which gcc`
  [ $(gcc_your_version "$c") -ge $1 ] && { echo "$c" ; return; }
  c=$(find-gcc-in-category sys-devel $1)
  [ -z "$c" ] || { echo $c; return; }
  c=$(find-gcc-in-category cross-x86_64-pc-linux-uclibc $1)
  [ -z "$c" ] || { echo $c; return; }
 }

find_gxx()
# $1: required version such as 52 for 5.2.0
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
