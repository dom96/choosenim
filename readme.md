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
  Installed component 'nimpretty'
  Installed component 'nimsuggest'
  Installed component 'testament'
   Switched to Nim 1.0.0
$ nim -v
Nim Compiler Version 1.0.0 [Linux: amd64]
```

## Installation

### Windows

Download the latest Windows version from the
[releases](https://github.com/dom96/choosenim/releases) page.

Extract the zip archive and run the ``runme.bat`` script. Follow any on screen
prompts and enjoy your new Nim and choosenim installation.

### Unix

```
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
```

**Optional:** You can specify the initial version you would like the `init.sh`
              script to install by specifying the ``CHOOSENIM_CHOOSE_VERSION``
              environment variable.

## How choosenim works

Similar to the likes of ``rustup`` and ``pyenv``, ``choosenim`` is a
_toolchain multiplexer_. It installs and manages multiple Nim toolchains and
presents them all through a single set of tools installed in ``~/.nimble/bin``.

The ``nim``, ``nimble`` and other tools installed in ``~/.nimble/bin`` are
proxies that delegate to the real toolchain. ``choosenim`` then allows you
to change the active toolchain by reconfiguring the behaviour of the proxies.

The toolchains themselves are installed into ``~/.choosenim/toolchains``. For
example running ``nim`` will execute the proxy in ``~/.nimble/bin/nim``, which
in turn will run the compiler in ``~/.choosenim/toolchains/nim-1.0.0/bin/nim``,
assuming that 1.0.0 was selected.

### How toolchains are installed

``choosenim`` downloads and installs the official release
[binaries](https://nim-lang.org/install.html) on Windows and Linux. On other
platforms, the official source [release](https://nim-lang.org/install_unix.html)
is downloaded and built. This operation is only performed once when a new
version is selected.

As official binaries are made available for more platforms, ``choosenim`` will
install them accordingly.

## Dependencies

|            |           Windows             |        Linux       |        macOS (*)      |
|------------|:-----------------------------:|:------------------:|:---------------------:|
| C compiler | *Downloaded automatically*    |      gcc/clang     |      gcc/clang        |
| OpenSSL    |          >= 1.0.2k            |      >= 1.0.2k     |         N/A           |
| curl       |             N/A               |         N/A        | Any recent version    |

\* Many macOS dependencies should already be installed. You may need to install
   a C compiler however. More information on dependencies is available
   [here](https://nim-lang.org/install_unix.html).

OpenSSL version can be checked by executing ``openssl version``.

Git is required when installing release versions on platforms other than Windows
and Linux, or when installing #HEAD or a specific commit of Nim.

## Usage

```
> choosenim -h
choosenim: The Nim toolchain installer.

Choose a job. Choose a mortgage. Choose life. Choose Nim.

Usage:
  choosenim <version/path/channel>

Example:
  choosenim 0.16.0
    Installs (if necessary) and selects version 0.16.0 of Nim.
  choosenim stable
    Installs (if necessary) Nim from the stable channel (latest stable release)
    and then selects it.
  choosenim #head
    Installs (if necessary) and selects the latest current commit of Nim.
    Warning: Your shell may need quotes around `#head`: choosenim "#head".
  choosenim ~/projects/nim
    Selects the specified Nim installation.
  choosenim update stable
    Updates the version installed on the stable release channel.
  choosenim versions [--installed]
    Lists the available versions of Nim that choosenim has access to.

Channels:
  stable
    Describes the latest stable release of Nim.
  devel
    Describes the latest development (or nightly) release of Nim taken from
    the devel branch.

Commands:
  update    <version/channel>    Installs the latest release of the specified
                                 version or channel.
  show                           Displays the selected version and channel.
  update    self                 Updates choosenim itself.
  versions  [--installed]        Lists available versions of Nim, passing
                                 `--installed` only displays versions that
                                 are installed locally (no network requests).

Options:
  -h --help             Show this output.
  -y --yes              Agree to every question.
  --version             Show version.
  --verbose             Show low (and higher) priority output.
  --debug               Show debug (and higher) priority output.
  --noColor             Don't colorise output.

  --choosenimDir:<dir>  Specify the directory where toolchains should be
                        installed. Default: ~/.choosenim.
  --nimbleDir:<dir>     Specify the Nimble directory where binaries will be
                        placed. Default: ~/.nimble.
  --firstInstall        Used by install script.
```

## Analytics

Check out the
[analytics](https://github.com/dom96/choosenim/blob/master/analytics.md)
document for details.

## License

MIT
