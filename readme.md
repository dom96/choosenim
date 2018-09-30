# choosenim

choosenim installs the [Nim programming language](https://nim-lang.org) from
official downloads and sources, enabling you to easily switch between stable
and development compilers.

The aim of this tool is two-fold:

* Provide an easy way to install the Nim compiler and tools.
* Manage multiple Nim installations and allow them to be selected on-demand.

## Typical usage

```
$ choosenim stable
  Installed component 'nim'
  Installed component 'nimble'
  Installed component 'nimgrep'
  Installed component 'nimsuggest'
   Switched to Nim 0.16.0
$ nim -v
Nim Compiler Version 0.16.0 (2017-01-08) [MacOSX: amd64]
```

## Installation

### Windows

Download the latest Windows version from the
[releases](https://github.com/dom96/choosenim/releases) page.

Execute the self-extracting archive, or extract the zip archive and run
the ``runme.bat`` script. Follow any on screen prompts and enjoy your
new Nim and choosenim installation.

### Unix

```
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
```

**Optional:** You can specify the initial version you would like the `init.sh`
              script to install by specifying the ``CHOOSENIM_CHOOSE_VERSION``
              environment variable.

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

|            |           Windows             |        Linux       |        macOS (*)      |
|------------|:-----------------------------:|:------------------:|:---------------------:|
| C compiler | *Downloaded automatically*    |      gcc/clang     |      gcc/clang        |
| OpenSSL    |          >= 1.0.2k            |      >= 1.0.2k     |         N/A           |
| curl       |             N/A               |         N/A        | Any recent version    |
| zlib       | *Statically linked in binary* | Any recent version | Any recent version    |

\* Many macOS dependencies should already be installed. You may need to install
   a C compiler however.

The dependencies shown are recommendations only. You may need to install
them, when you do ensure that they are in your PATH.

OpenSSL version can be checked by executing ``openssl version``.

## Usage

```
$ nim -v
Nim Compiler Version 0.19.0 [MacOSX: amd64]
$ choosenim 0.18.0
  Switched to Nim 0.18.0
$ nim -v
Nim Compiler Version 0.18.0 [MacOSX: amd64]
```

## Analytics

Check out the
[analytics](https://github.com/dom96/choosenim/blob/master/analytics.md)
document for details.

## Troubleshooting

## Development notes

Auto-extracting installer for Windows was created using WinRAR. Instructions
available [here](http://stackoverflow.com/a/27905551/492186).

## License

MIT