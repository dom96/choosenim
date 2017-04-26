# choosenim

choosenim installs the [Nim programming language](https://nim-lang.org) from
official downloads and sources, enabling you to easily switch between stable
and development compilers.

The aim of this tool is two-fold:

* Provide an easy way to install the Nim compiler and tools.
* Manage multiple Nim installations and allow them to be selected on-demand.

## Typical usage

```
$ choosenim 0.16.0
  Installed component 'nim'
  Installed component 'nimble'
  Installed component 'nimgrep'
  Installed component 'nimsuggest'
   Switched to Nim 0.16.0
$ nim -v
Nim Compiler Version 0.16.0 (2017-01-08) [MacOSX: amd64]
```

## Installation

TODO

## How choosenim works

Similar to the likes of ``rustup`` and ``pyenv``, ``choosenim`` is a
_toolchain multiplexer_.
It installs and manages multiple Nim toolchains and presents them all through
a single set of tools installed in ``~/.nimble/bin``.

The ``nim``, ``nimble`` and other tools installed in ``~/.nimble/bin`` are
proxies that delegate to the real toolchain. ``choosenim`` then allows you
to change the active toolchain by reconfiguring the behaviour of the proxies.

The toolchains themselves are installed into ``~/.choosenim/toolchains``. For
example running ``nim`` will execute the proxy in ``~/.nimble/bin/nim``, which
in turn will run the compiler in ``~/.choosenim/toolchains/nim-0.16.0/bin/nim``,
assuming that 0.16.0 was selected.

### How toolchains are installed

Due to lack of official binaries for most platforms, ``choosenim`` downloads
the source and builds it by default. This operation is only performed once
when a new version is selected.

In the future ``choosenim`` will download binaries whenever they are available.

## Dependencies

* A C compiler (gcc or clang is recommended)
  * On Windows this dependency is downloaded automatically.
  * On Linux and macOS it is expected to be in your PATH.
* zlib

Windows and Linux only:

* OpenSSL
  * At least version 1.0.2k (you can check this by running ``openssl version``).

macOS only:

* curl (macOS ships with this so you shouldn't need to worry about installing it).

## Usage

## Troubleshooting

## License

MIT