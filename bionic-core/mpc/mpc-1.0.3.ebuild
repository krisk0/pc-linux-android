# Copyright 1999-2015 Gentoo Foundation
# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=4

inherit eutils libtool multilib-minimal gentoo-android befriend-gcc

DESCRIPTION="A library for multiprecision complex arithmetic with exact rounding"
HOMEPAGE="http://mpc.multiprecision.org/"
SRC_URI="http://www.multiprecision.org/mpc/download/${P}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS=amd64
IUSE=""
MULTILIB_COMPAT=64

DEPEND="bionic-core/gmp bionic-core/mpfr bionic-core/0gcc"
RDEPEND="${DEPEND}"

src_prepare() {
 export CC=`0gcc-gcc`
 export CXX=`0gcc-gxx`
	elibtoolize #347317
}

multilib_src_configure() {
	ECONF_SOURCE=${S} econf
}

multilib_src_install_all() {
	einstalldocs
	prune_libtool_files
 zap_doc_a_move_so_h
}
