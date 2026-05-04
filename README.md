# Python 3.4.10 for SCO OpenServer 5

A working build of [Python 3.4.10](https://www.python.org/) (March 2019,
final 3.4 release) for **SCO OpenServer 5.0.7**, including TLS via
statically-linked OpenSSL 1.0.2q.

```
$ python3 --version
Python 3.4.10

$ python3 -c 'import ssl; print(ssl.OPENSSL_VERSION)'
OpenSSL 1.0.2q  20 Nov 2018
```

Just want to run Python 3 on your SCO box? Skip to **[Install](#install)**.

## Why 3.4 specifically?

Python 3.6 and later use POSIX.1-2001 real-time clock APIs (`clockid_t`,
`clock_gettime`, `clock_getres`) that SCO doesn't provide. Python 3.5
shares the same time-handling rewrite. Python 3.4 is the most recent
release whose internals don't depend on those APIs.

What you get vs Python 2.7:

- Real Python 3 syntax — proper Unicode strings, `print` as a function,
  no implicit `str`/`unicode` mess
- `pathlib`, `enum` (PEP 435), `asyncio` *type definitions* (without
  threads — see below), `concurrent.futures` API surface
- `*rest` unpacking, dict comprehensions, function annotations
- Bytes/str distinction enforced

What you don't get vs newer Python 3:

- **No f-strings.** PEP 498 f-strings were added in **3.6**. You're stuck
  with `"{}".format(...)` and `%`-formatting in 3.4.
- No type annotation syntax for variables (PEP 526, 3.6+)
- No `async`/`await` keywords (3.5+) — `asyncio` exists but uses
  `@coroutine` decorators

## Install

> **Fresh SCO box?** Install [curl with TLS](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
> first — that's the only file that needs to be transferred via `scp`.
> After that, every release on tachytelic/* (including this one) fetches
> over HTTPS from GitHub.

The full install is ~24 MB packaged. Fetch and extract directly on the
SCO box:

```sh
# On the SCO box (assumes curl-with-TLS is on PATH — see curl-sco):
curl -LO https://github.com/tachytelic/Python-3.4.10-for-SCO-OpenServer-5/releases/download/v1.0.0/python-3.4.10-sco.tar.gz
gtar xzf python-3.4.10-sco.tar.gz
# or with stock tools: gunzip -c python-3.4.10-sco.tar.gz | /usr/bin/tar xf -
mv install34 /usr/local/python-3.4.10
ln -s /usr/local/python-3.4.10/bin/python3 /usr/local/bin/python3
python3 --version       # → Python 3.4.10
```

OpenSSL 1.0.2q is statically linked into `_ssl.so`, so there's no
runtime OpenSSL dependency.

## What's included

48 standard-library modules verified working:

| Category | Modules |
|---|---|
| Core | `os`, `sys`, `json`, `re`, `math`, `time`, `struct`, `datetime`, `collections`, `itertools`, `argparse`, `copy`, `unittest`, `logging`, `random`, `decimal` |
| I/O | `io`, `pickle`, `csv`, `tempfile`, `shutil`, `mmap` |
| Network | `socket`, `select`, `urllib`, `urllib.request`, `http.client`, `email` |
| TLS / crypto | `ssl` (OpenSSL 1.0.2q, modern ECDHE ciphers), `hashlib`, `hmac` |
| Compression | `zlib`, `gzip`, `tarfile`, `zipfile`, `bz2`, `binascii`, `base64` |
| Process | `subprocess` |
| Terminal | `readline`, `termios` |
| Other | `uuid`, `array`, `pyexpat`, `xml.etree.ElementTree`, `enum`, `pathlib` |

## What's not included

- **Threading**: `_thread`, `threading`, `asyncio` (the runtime parts),
  `concurrent.futures` — SCO's threading model isn't compatible with
  CPython. This is the biggest practical loss.
- `_curses` — SCO's curses lacks `wchgat` (wide-char curses)
- `ctypes` — needs libffi (not on SCO)
- `_sqlite3` — needs the SQLite development headers
- `_lzma` — needs liblzma

## Quick test

```python
$ python3
Python 3.4.10 (default, May  3 2026)
[GCC 3.4.6] on sco_sv3
>>> import ssl, urllib.request
>>> ctx = ssl.create_default_context()
>>> # HTTPS works against modern servers (TLS 1.2, ECDHE)
>>> import json, hashlib
>>> hashlib.sha256(b'hello').hexdigest()
'2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
>>> from pathlib import Path
>>> Path('/etc').exists()
True
```

End-to-end TLS handshake confirmed working — modern ECDHE-RSA-AES256-GCM-SHA384
cipher, full Python 3 `ssl.SSLContext` API.

## Building from source

You probably don't need to do this — the release tarball is what
`build.sh` produces. If you want to rebuild:

This is a **native build, not a cross-build** (cross-compile path is
blocked by SCO's loader hiding key libc symbols from GNU-linked
binaries). You build it on the SCO machine itself.

### Requirements

- **GCC 3.4 or later** somewhere on the SCO box (the SCO-shipped GCC
  2.95.3 is C89-only and won't build Python 3 — this build needs full
  C99 support). If you don't already have a newer GCC, you'll need to
  build or install one first; the build script will refuse to start
  with 2.x.
- `/usr/gnu/bin/{gmake,gtar}`, `/usr/bin/patch`
- **Static OpenSSL 1.0.2** at `/usr/local/lib/{libssl,libcrypto}.a` with
  headers at `/usr/local/include/openssl/`. SCO's stock 0.9.7 is too old
  for Python 3.4's `_ssl` module. If you skip this, Python builds without
  `_ssl` and you lose HTTPS.

### Build

If your C99 GCC is on `PATH` as `gcc`:

```sh
cd python34-sco
./build.sh
```

Otherwise tell the script where it lives:

```sh
GCC=/path/to/your/gcc-3.4 ./build.sh
```

Downloads `Python-3.4.10.tgz` from python.org, applies
`patches/python-3.4.10-sco.patch`, configures with appropriate flags,
builds, runs `make install` to `./py_install/`, strips, and you can
then tar+ship.

### What the patches do

`patches/python-3.4.10-sco.patch` is a 4.7 KB unified diff with five
small changes:

1. **`Include/longobject.h`** — add `SIZEOF_PID_T == SIZEOF_SHORT` case.
   SCO's `pid_t` is `short`, which CPython 2.7 and 3.x don't anticipate.
2. **`Modules/socketmodule.c`** — drop the platform-specific guard
   around the `INET_ADDRSTRLEN` fallback `#define`. SCO doesn't define
   this constant in any headers.
3. **`Modules/_localemodule.c`** — fall back to `"ascii"` when
   `nl_langinfo(CODESET)` returns empty (SCO's locale is essentially
   unconfigured).
4. **`Python/pythonrun.c`** — the same fallback in
   `get_locale_encoding()` plus a `initstdio()` fallback to ensure
   stdio always has *some* encoding even when locale is blank.
5. **`Python/random.c`** — fall back to a weak time+pid LCG when
   `/dev/urandom` doesn't exist (SCO has no `/dev/urandom`). This is
   fine for hash randomization (which is all CPython uses it for at
   startup); it would NOT be acceptable for cryptographic use.

The build script also makes two post-configure tweaks: disabling
`HAVE_KQUEUE` in `pyconfig.h` (SCO has `<sys/event.h>` but not the
full kqueue API) and replacing `-std=c99` with `-std=gnu99` in the
Makefile (strict C99 hides POSIX declarations like `struct sigaction`).

## Repository layout

```
patches/
  python-3.4.10-sco.patch    5 patches, 4.7 KB unified diff

build.sh                     Native-build script (run on SCO)
```

The prebuilt 24 MB tarball isn't committed to the repo (would bloat
every clone). Grab it from the **[Releases](../../releases)** page.

## License

Python is © Python Software Foundation, distributed under the [PSF
License](https://docs.python.org/3.4/license.html). The prebuilt
binary is unmodified upstream Python 3.4.10 with the patches in this
repo applied.

The patches and build script in this repo are released under the MIT
license — see [LICENSE](LICENSE).

## See also

If you're keeping a SCO OpenServer 5 box alive, head over to
[my SCO OpenServer 5 binaries page](https://tachytelic.net/2017/07/sco-openserver-5-binaries/)
to find other compiled software for the SCO OpenServer (bash, rsync,
tar, wget, lzop, …) along with notes on running these systems day to
day.
