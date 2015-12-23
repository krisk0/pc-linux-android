# Copyright 1999-2015 Gentoo Foundation
# Copyright      2015 Крыськов Денис
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5

inherit eutils multilib-minimal gentoo-android befriend-gcc

DESCRIPTION="A library for manipulating integer points bounded by linear constraints"
HOMEPAGE="http://isl.gforge.inria.fr/"
SRC_URI="http://isl.gforge.inria.fr/$P.tar.xz"

LICENSE=LGPL-2.1
SLOT="0/14"
KEYWORDS=amd64
MULTILIB_COMPAT=64

RDEPEND="bionic-core/gmp bionic-core/0gcc"
DEPEND="${RDEPEND}
	app-arch/xz-utils
	virtual/pkgconfig"

src_prepare() {
 export CC=`0gcc-gcc`
 export CXX=`0gcc-gxx`
	# m4/ax_create_pkgconfig_info.m4 is broken but avoid eautoreconf
	# https://groups.google.com/group/isl-development/t/37ad876557e50f2c
	sed -i -e '/Libs:/s:@LDFLAGS@ ::' configure || die #382737
}

multilib_src_configure()
 {
 	ECONF_SOURCE="${S}" econf
 }

# No rule to make target
# '/tmp/portage/bionic-core/isl-0.14/work/isl-0.14/isl.py', needed by
# 'install-data-local'
# Disabling parallel make solves the problem
multilib_src_install()
 {
  make install DESTDIR="$ED"
 }

multilib_src_install_all() {
	einstalldocs
	prune_libtool_files
 zap_doc_a_move_so_h
 find . -name '*.py' -delete
 mv include x86_64-linux-android/ || die
 rm -rf lib64
}
