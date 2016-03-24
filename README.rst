x86_64-pc-linux-android toolchain 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

(including bionic library) compiled from source and installed as a native compiler on your amd64/Intel64 desktop running Linux, without using any propriety binary code. Just like uclibc toolchain brought to ``/usr/x86_64-pc-linux-uclibc`` via ``ct-ng`` script.

Ebuild scripts compiling and installing bionic library (``libc.so``, ``libm.so``, ...), dynamic interpreter ``/system/bin/linker`` and ``/system/bin/linker64`` are here since 19 Nov 2015; full-featured gcc/g++ is here since 12 Dec 2015; gcc-5.3 pretending to be native bionic compiler since 31 Dec 2015.

See INSTALL/manual.txt for installation instructions.

I prefer to get bug-reports via Github mechanism. If you want to teach me how to do something in an elegant or standard way, enclose a patch. If you report a bug, supply enough information for me to reproduce it.

All ebuilds bundled in this project only use https download (no git/cvs/...). Which means you can run them on a computer not connected to Internet (just plant all required ``.zip`` to ``distfiles/``).

My ebuilds take fixed version of software, thus don't get broken by a software update. And I won't change that version or download source without a reason (such as smaller download size, error fixing, smaller size of library, faster operation).
