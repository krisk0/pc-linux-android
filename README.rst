x86_64-pc-linux-android toolchain 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

(including bionic library) can be compiled from source and installed as a native compiler on any amd64/Intel64 desktop running Linux, without using any propriety binary code. Just like uclibc toolchain can be brought to ``/usr/x86_64-pc-linux-uclibc`` via ``crossdev`` script.

Ebuild scripts compiling and installing bionic library (``libc.so``, ``libm.so``, ...), dynamic interpreter ``/system/bin/linker`` and ``/system/bin/linker64`` are here since 19 Nov 2015; native binutils and compiler coming soon. Compile/install time *emerge --quiet bionic-core/bionic*: 3 minutes from ``/usr/src/linux`` to ``/system/bin/linker64`` on my 4-proc Core i5-2500K @ 3.30GHz.

How big is your hello_world.exe? Mine is 6240 bytes (with sys-devel/gcc-4.9.3) and 5672 bytes with gcc hypnotized to link for bionic.

I prefer to get bug-reports via Github mechanism. If you want to teach me how to do something in an elegant or standard way, enclose a patch. If you report a bug, supply enough information for me to reproduce it.

All ebuilds bundled in this project only use https download (no git/cvs/...). Which means you can run them on a computer not connected to Internet (just plant all required ``.zip`` to ``distfiles/``).

My ebuild scripts always take fixed version of software (by setting a specific value of SHA1), so they don't get broken by a software update. And I won't change that version or download source, unless there is good reason (such as smaller download size, error fixing, smaller size of library, faster operation).
