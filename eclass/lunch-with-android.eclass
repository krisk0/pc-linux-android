lunch-make-script()
 {
  cat << EOF > lunch-make.sh
PATH=@path
. build/envsetup.sh ; lunch android_x86_64-user
export PATH=@path
'@make' $MAKEOPTS -f build/core/main.mk @tgt
EOF
  sed -i lunch-make.sh -e "s>@make>$(which make)>"
 }
