zap_doc_a_move_so_h()
 {
  cd "$ED/usr"
  find . -type f -name '*.la' -delete
  find . -type f -name '*.a' -delete
  local p=x86_64-linux-android
  mkdir -p $p
  local so
  local d
  for so in $(find . -type f -name "*.so.*") ; do
  [ 0 ] ||
    {
     # kill symbolic links, rename libraries. This can only be done if soname
     #  is not compiled-in. Disabled for now
     d=$(dirname $so)
     find $d -type l -delete
     local m=$(echo $so|sed 's:\.so.*:.so:')
     rm -f $m && mv $so $m || die
     so=m
    }
   local t=$(file -b $so)
   einfo "found lib $so"
   local m=$(echo $so|sed 's:\.so.*:.so:')
   d=$(echo $t|grep -c 'Intel 80386')
   [ $d == 0 ] || 
    { 
     einfo "moving ${m}* to $p/lib32"
     mkdir -p $p/lib32 && mv ${m}* $p/lib32/ || die
     continue
    }
   d=$(echo $t|grep -c 'x86-64')
   [ $d == 0 ] && continue
   einfo "moving ${m}* to $p/lib64"
   mkdir -p $p/lib64 && mv ${m}* $p/lib64/ || die
  done
  rm -rf share
  [ -d include ] &&
   (
    cd include
    d=`ls *.h 2>/dev/null`
    [ -z "$d" ] || ( mkdir -p ../$p/include ; mv $d ../$p/include/ || die )
   )
  find . -type d -depth -empty -exec rmdir "{}" \;
 }
