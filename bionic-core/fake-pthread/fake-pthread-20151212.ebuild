# Copyright 1999-2015 Gentoo Foundation
# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit multilib-minimal
k=krisk0
HOMEPAGE=https://github.com/$k/pc-linux-android
DESCRIPTION="Fake pthread.so containing only getpass() subroutine"
LICENSE=LGPL-3
SLOT=0
DEPEND=bionic-core/0gcc
KEYWORDS=amd64
IUSE=""

src_unpack()
 {
  mkdir $k || die
  S=$WORKDIR/$k
  cp "$FILESDIR/getpass.c" $k/ || die
  c=$(best_version $DEPEND)
  c=$(equery f $DEPEND|egrep 'bin/.*-gcc$'|head -1)
  triple=x86_64-linux-android
  p=libpthread.so
 }

multilib_src_compile()
 {
  #EPREFIX with spaces not supported by 0gcc and this ebuild
  $c $CFLAGS $(get_abi_var CFLAGS) "$S/getpass.c" -shared -o $p || die
 }

src_install()
 {
  #EPREFIX with spaces not supported
  cd $ED
  local i=usr/$triple/lib
  mkdir -p ${i}{32,64} || die 'are we full?'
  mv "$WORKDIR/${k}-abi_x86_64.amd64/$p" ${i}64 && 
   mv "$WORKDIR/${k}-abi_x86_32.x86/$p" ${i}32 || die 'mv failed'
  unset c k triple p
 }
