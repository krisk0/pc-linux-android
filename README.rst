x86_64-pc-linux-android toolchain 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

(including bionic library) can be compiled from source and installed as a native compiler on any amd64/Intel64 desktop running Linux, without using any propriety binary code. Just like uclibc toolchain brought to /usr/x86_64-pc-linux-uclibc via crossdev script.

Ebuild scripts compiling and installing bionic library (``libc.so``, ``libm.so``, ...), dynamic interpreter ``/system/bin/linker`` and ``/system/bin/linker64`` and everything else required to natively run or compile from source 64-bit or 32-bit Android software (for x86 or x86_64 platform) will be here soon.

How soon? As soon as I convince ``*.mk`` files found in ``.zip`` downloadable from https://github.com/android/platform_build to not use prebuilt compilers. I already built/installed base system headers, jemalloc, and a piece of binutils. My experiments show that ``/usr/bin/x86_64-pc-linux-gnu-gcc`` and ``/usr/bin/clang`` are quite capable of creating library files or executable code (not worse than those found on my Android tablet).

If you want to install a piece of Android onto your Gentoo desktop right now, take my 3 ebuilds and don't forget to add bionic-core to /etc/portage/categories. As of today (16 Nov 2015) everything goes under /usr/x86_64-linux-android; however bionic library and linker will be in /system (for compatibility with Android installed on x86 tablet).

I prefer to get bug-reports via Github mechanism. If you want to teach me how to do something better of faster, enclose a patch. If you report a bug, supply enough information for me to reproduce it.
