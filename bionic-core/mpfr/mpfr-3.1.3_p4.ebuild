# Copyright 1999-2015 Gentoo Foundation
# Copyright      2015 Денис Крыськов   
# Distributed under the terms of the GNU General Public License v2

EAPI=4

# NOTE: we cannot depend on autotools here starting with gcc-4.3.x
inherit eutils libtool multilib multilib-minimal gentoo-android befriend-gcc

MY_PV=${PV/_p*}
MY_P=${PN}-${MY_PV}
PLEVEL=${PV/*p}
DESCRIPTION="library for multiple-precision floating-point computations with exact rounding"
HOMEPAGE="http://www.mpfr.org/"
SRC_URI="http://www.mpfr.org/mpfr-${MY_PV}/${MY_P}.tar.xz"

LICENSE=LGPL-2.1
SLOT=0
KEYWORDS=amd64
IUSE=""
# setting CC=smth is incompatible with multilib
MULTILIB_COMPAT=64

RDEPEND="bionic-core/gmp bionic-core/0gcc"
DEPEND="$RDEPEND"

S=$WORKDIR/$MY_P

src_prepare() {
 if [[ $PLEVEL != $PV ]] ; then
  local i
  for (( i = 1; i <= PLEVEL; ++i )) ; do
   epatch "$FILESDIR"/patch$(printf '%02d' $i)
  done
 fi
 find . -type f -exec touch -r configure {} +
 export CC=`0gcc-gcc`
 export CXX=`0gcc-gxx`
 elibtoolize
}

multilib_src_configure() {
 # Make sure mpfr doesn't go probing toolchains it shouldn't #476336#19
 ECONF_SOURCE=${S} \
 user_redefine_cc=yes \
 econf \
  --docdir="\$(datarootdir)/doc/${PF}"
 # TODO: disable soname injection by patching libtool or smth else
}

multilib_src_install_all() {
 zap_doc_a_move_so_h
}
