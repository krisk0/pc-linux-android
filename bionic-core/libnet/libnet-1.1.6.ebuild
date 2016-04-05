# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=4

inherit eutils gentoo-android

DESCRIPTION="A library to manipulate network packets and access kernel network stack"
HOMEPAGE="http://libnet-dev.sourceforge.net/"
SRC_URI="mirror://sourceforge/project/${PN}-dev/$P.tar.gz"

LICENSE="BSD BSD-2 HPND"
SLOT=1.1
KEYWORDS=amd64
IUSE=""

DEPEND="sys-devel/autoconf bionic-core/gcc"
RDEPEND=""

src_configure() {
 export CC=`android_gcc`
 default
}

src_install() {
 default
 zap_doc_a_move_so_h
 [ -d bin ] && rm -rf bin
}
