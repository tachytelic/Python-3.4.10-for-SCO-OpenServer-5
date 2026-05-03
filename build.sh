#!/bin/sh
# Build Python 3.4.10 natively on SCO OpenServer 5.0.7.
#
# Run this script ON the SCO machine, in a writable directory.
#
# Required:
#   /asottile/prefix/bin/gcc      — GCC 3.4.6 (full C99 support)
#   /usr/gnu/bin/{gmake,gtar}, /usr/bin/patch, /bin/{sed,gunzip}
#   wget or curl, OR drop Python-3.4.10.tgz next to this script
#   Static OpenSSL 1.0.2 at /usr/local/lib/{libssl,libcrypto}.a
#       with headers at /usr/local/include/openssl/.  (For TLS support.
#       SCO's stock OpenSSL 0.9.7 is too old — Python 3.4 needs 1.0.x.)
#
# Output: ./py_install/ (about 24 MB stripped) — a relocatable Python install.

set -e

SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=3.4.10
TARBALL=Python-${VERSION}.tgz
SRCDIR=Python-${VERSION}

# Prefer GCC 3.4.6 (full C99) over the SCO native 2.95.3 (C89 only)
PATH=/asottile/prefix/bin:/usr/gnu/bin:/usr/ccs/bin:/usr/bin:/bin
export PATH

if [ ! -f "$TARBALL" ]; then
    echo "Fetching $TARBALL..."
    if which wget >/dev/null 2>&1; then
        wget --no-check-certificate "https://www.python.org/ftp/python/${VERSION}/${TARBALL}"
    elif which curl >/dev/null 2>&1; then
        curl -kLO "https://www.python.org/ftp/python/${VERSION}/${TARBALL}"
    else
        echo "ERROR: no wget or curl. Drop $TARBALL next to this script." >&2
        exit 1
    fi
fi

if [ ! -d "$SRCDIR" ]; then
    echo "Unpacking $TARBALL..."
    gtar xzf "$TARBALL"
fi

echo "Applying SCO compatibility patches..."
cd "$SRCDIR"
if [ -f .sco_patched ]; then
    echo "  (already applied — skipping)"
else
    patch -p1 < "$SCRIPT_DIR/patches/python-3.4.10-sco.patch"
    touch .sco_patched
fi

echo "Configuring..."
CC=gcc \
CFLAGS="-O2 -std=gnu99" \
CPPFLAGS="-I/usr/local/include -I/usr/local/ssl/include" \
LDFLAGS="-L/usr/local/lib -L/usr/local/ssl/lib" \
./configure --prefix="$SCRIPT_DIR/py_install" --without-pymalloc

# Two post-configure tweaks:
# 1. Disable HAVE_KQUEUE — SCO has <sys/event.h> from some package but the
#    kqueue API is incomplete; without this, Modules/selectmodule.c won't
#    compile and the select extension is silently dropped.
# 2. Replace -std=c99 with -std=gnu99 — strict C99 mode hides POSIX
#    declarations like struct sigaction on SCO's headers.
echo "Post-configure tweaks..."
sed "s|^#define HAVE_KQUEUE 1\$|/* #undef HAVE_KQUEUE */|" pyconfig.h > pyconfig.h.new
mv pyconfig.h.new pyconfig.h
sed "s|-std=c99|-std=gnu99|g" Makefile > Makefile.new
mv Makefile.new Makefile

echo "Compiling (long — go make tea)..."
gmake

echo "Installing to $SCRIPT_DIR/py_install/..."
gmake -s install || true   # ensurepip step may fail (urandom-related); install itself is OK

echo "Stripping binaries..."
strip "$SCRIPT_DIR/py_install/bin/python3.4" 2>/dev/null || true
find "$SCRIPT_DIR/py_install" -name "*.so" -exec strip {} \; 2>/dev/null

ls -l "$SCRIPT_DIR/py_install/bin/python3"
echo
echo "Built: $SCRIPT_DIR/py_install/"
echo "Test it: $SCRIPT_DIR/py_install/bin/python3 --version"
echo
echo "To package: gtar czf python-${VERSION}-sco.tar.gz py_install"
