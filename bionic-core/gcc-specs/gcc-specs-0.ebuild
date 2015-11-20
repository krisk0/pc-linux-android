# Copyright      2015 Денис Крыськов
# Distributed under the terms of the GNU General Public License v2

EAPI=5
DESCRIPTION="Auxillary file used to hypnotize gcc compiler"
HOMEPAGE=https://github.com/krisk0/pc-linux-android
SLOT=0
S="${WORKDIR}"

src_install()
 {
  local f=gcc.specs
  local d="$ED/usr/x86_64-linux-android/share"
  mkdir -p $d
  lzma -d < "$FILESDIR/$f.lzma" > "$d/$f" || die
 }
