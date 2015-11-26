# Copyright 1999-2015 Gentoo Foundation
# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

# Major difference from official build:
#  a) respect native microarch (for instance, treat Broadwell as Broadwell not
#   K8)
#  b) build with android-targeting gcc compiler for the sole purpose of building
# android-targeting gcc compiler

EAPI=5

inherit eutils libtool toolchain-funcs multilib-minimal befriend-gcc

# While bionic-core/binutils works with sandbox turned on, this ebuild does not
#  I think some script unsets LD_LIBRARY_PATH

MY_PV=${PV/_p*}
MY_P=${PN}-${MY_PV}
PLEVEL=${PV/*p}
DESCRIPTION="GMP library needed to compile GCC"
HOMEPAGE="http://gmplib.org/"
SRC_URI="mirror://gnu/${PN}/${MY_P}.tar.xz
 ftp://ftp.gmplib.org/pub/${MY_P}/${MY_P}.tar.xz"
QA_PRESTRIPPED="usr/x86_64-linux-android/lib64/*"
# For unclear reason 'QA Notice: Pre-stripped files found' complaint
#  does not go away

LICENSE="|| ( LGPL-3+ GPL-2+ )"
SLOT=0
KEYWORDS=amd64
MULTILIB_COMPAT=64

DEPEND="sys-devel/m4 app-arch/xz-utils
 bionic-core/bionic bionic-core/binutils[-stage0]
"

S=${WORKDIR}/${MY_P%a}

DOCS=( AUTHORS ChangeLog NEWS README doc/configuration doc/isa_abi_headache )
HTML_DOCS=( doc )
MULTILIB_WRAPPED_HEADERS=( /usr/include/gmp.h )

src_prepare()
 {
  [ -z "$LD_PRELOAD" ] || die "sorry, this .ebuild does not support sandbox"
  
  [[ -d ${FILESDIR}/${PV} ]] &&
   EPATCH_SUFFIX="diff" EPATCH_FORCE="yes" epatch "${FILESDIR}"/${PV}

  # note: we cannot run autotools here as gcc depends on this package
  elibtoolize

  # GMP uses the "ABI" env var during configure as does Gentoo (econf).
  # So, to avoid patching the source constantly, wrap things up.
  mv configure configure.wrapped || die
  printf '#!/bin/sh\nexec env ABI=$GMPABI "$0.wrapped" "$@"' > configure
  chmod a+rx configure

  # multilib_src_configure() clobbers config.guess, so we run it here
  export build_alias=`/bin/sh $S/config.guess` ||
   die "failed to run config.guess"
  [ -z $build_alias ] && die "empty result from config.guess"
  einfo "guessed processor type: $build_alias"
 }

multilib_src_configure() {
 # ABI mappings (needs all architectures supported)
 case ${ABI} in
  32|x86)       GMPABI=32;;
  64|amd64|n64) GMPABI=64;;
  [onx]32)      GMPABI=${ABI};;
 esac
 export GMPABI

 # 0gcc ebuild does not work when $EPREFIX contains spaces. However this ebuild
 #  attempts to support such freaky EPREFIX
 export CC=`find-then-hypnotize-gcc 490`
 #sed -i "$CC" -e 's:-DGCC_IS_HYPNOTIZED:-fPIC &:' ||
 # die "injecting -fPIC failed"
 einfo "gcc hypnotized"
 export LD_LIBRARY_PATH="${CC/ized.gcc/ized-gcc}/lib"
 export CXX=$(hypnotize-gxx-too "$CC")
 einfo "g++ hypnotized: $CXX"
 export ac_cv_host=$build_alias
 [ -z $ac_cv_host ] && die 'problem with build_alias'
 export ac_build_alias=$ac_cv_host
 emake=`which emake`

 local k="-DBIONIC_CORE_COMPILING"

 ECONF_SOURCE="${S}" econf \
  --localstatedir=/var/state/gmp \
  --enable-shared \
  --disable-cxx    \
  --disable-static
 local i=`find . -type f -name Makefile`
 [ -z "$i" ] && die "no Makefile in `pwd`"
}

multilib_src_test()
{
 einfo "warning: test not implemented"
}

multilib_src_install() {
 "$emake" DESTDIR="$ED" install || die "make install failed"
}

multilib_src_install_all()
 {
  cd "$ED/usr"
  local p=x86_64-linux-android
  mkdir -p $p/{lib64,include}
  (
   local so=$(find . -type f -name "lib$PN.so.*"|head -1)
   "$EPREFIX/usr/bin/strip" --strip-all "$so"
   so=$(dirname $so)
   rm -f $so/*.la
   mv $so/* $p/lib64/
   mv include/$PN.h $p/include/
  ) || die "failed to find or move .so or .h"
  ls | grep -v $p | xargs rm -rf
  unset emake ac_cv_host ac_build_alias CC CXX LDFLAGS QA_PRESTRIPPED
 }

pkg_preinst() {
 preserve_old_lib /usr/$(get_libdir)/libgmp.so.3
}

pkg_postinst() {
 preserve_old_lib_notify /usr/$(get_libdir)/libgmp.so.3
}
