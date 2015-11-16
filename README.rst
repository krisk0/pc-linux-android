x86_64-pc-linux-android toolchain 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

(including bionic library) can be compiled from source and installed as a native compiler on any amd64/Intel64 desktop running Linux, without using any propriety binary code.

Ebuild scripts compiling and installing bionic library (libc.so, libm.so, ...), dynamic interpreter /system/bin/linker and /system/bin/linker64 and everything else required to natively run or compile from source 64-bit or 32-bit Android software (for x86 or x86_64 platform) will be here soon.

How soon? As soon as I convince *.mk files found in .zip downloadable from https://github.com/android/platform_build to not use prebuilt compilers. I already built/installed base system headers, jemalloc, and a piece of binutils. My testing shows that /usr/bin/x86_64-pc-linux-gnu-gcc and /usr/bin/clang are quite capable of creating all the necessary library files and /system/bin/linker*.

If you want to install a piece of Android onto your Gentoo Linux right now, take my 3 ebuilds and don't forget to add bionic-core to /etc/portage/categories. As of today (16 Nov 2015) everything goes under /usr/x86_64-linux-android; however bionic library and linker will be in /system (just like your in Android tablet).
