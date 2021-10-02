# Choosenim changelog

## 0.8.0 - 02/10/2021

This is a major new release containing many new significant improvements.
In particular:

* unxz/tar and the Nim zippy library are now used for extracting archives.
* puppy is used for downloading via HTTP on Windows.
* curl is used again for downloading via HTTP on macOS.
* fixed issues building new Nim source code that relies on the new `build_all`
scripts.
* choosenim binaries no longer rely on musl.
* better handling of antivirus false positives.

See the full list of changes here:

https://github.com/dom96/choosenim/compare/v0.7.4...0.8.0

## 0.7.4 - 20/10/2020

This is a bug fix release to resolve a regression where a spurious `pkgs`
directory was being created when any choosenim shim was executed.

Once choosenim is upgraded, simply switch Nim versions and the shims will be
regenerated, solving the issue.

## 0.7.2 - 17/10/2020

This is a bug fix release to resolve a regression caused by changes in Nimble
which prevented choosenim from finding the Nimble directory.

## 0.7.0 - 16/10/2020

The major new feature is that all builds are now static. There should be no
runtime dependencies for choosenim anymore.

Changes:

* A critical bug was fixed where choosenim would fail if existng DLLs were present.
* The `update` command will now always change to the newly installed version.
  In previous versions this would only happen when the currently selected
  channel is updated.
* A new `remove` command is now available.
* The `nim-gdb` utility is now shimmed.
* Various small bug fixes, #203 and #195.
* The `GITHUB_TOKEN` env var will now be used if present for certain actions.
* Better messages when downloading nightlies.

## 0.6.0 - 06/03/2020

The major new feature is default installation of 64-bit Nim
binaries on Windows.

Changes:
* Install latest nightly build of Nim on `choosenim devel` and
  `choosenim update devel`
* Install latest devel commit instead of nightlies with the
  `--latest` flag
* Git based update for `choosenim update devel --latest` instead
  of deleting, downloading and bootstrapping from scratch
* Optionally add `~/.nimble/bin` to PATH on Windows when using the
  `--firstInstall` flag
* Fix `choosenim update self` failure on Windows
* Fix crash where shims could not be rewritten when in use
* Fix crash on OSX due to an openssl version conflict

See the full list of changes here:

https://github.com/dom96/choosenim/compare/v0.5.1...v0.6.0

## 0.5.1 - 15/01/2020

Includes multiple bug fixes and minor improvements.

* Create a shim for testament
* Ship x64 binaries for Windows
* Delete downloaded archives and csources directory after successful
  installation to save disk space
* Error if C compiler is not found rather than just warning
* Extract Nim binaries with execute permissions
* Enable installation using `nimble install choosenim`

See the full list of changes here:

https://github.com/dom96/choosenim/compare/v0.5.0...v0.5.1

## 0.5.0 - 14/11/2019

The major new feature is the use of nimarchive and
support for Linux binary builds.

See the full list of changes here:

https://github.com/dom96/choosenim/compare/v0.4.0...v0.5.0

## 0.4.0 - 18/04/2019

The major new features include Windows 64-bit support, the installation
of Windows binaries and the `versions` command.

See the full list of changes here:

https://github.com/dom96/choosenim/compare/v0.3.2...v0.4.0

## 0.3.2 - 27/02/2018

The major new feature in this release is the ability for choosenim to
update itself, this is done by executing ``choosenim update self``.

* A bug where choosenim would fail because of an existing .tar file
  was fixed.
* Proxy support implemented.
* Fixes #17 and #51.

## 0.3.0 - 22/09/2017

The major new feature in this release is the ability to record analytics.
For more information see the
[analytics document](https://github.com/dom96/choosenim/blob/master/analytics.md).

* On Linux a .tar.xz archive will now be downloaded instead of the larger
  .tar.gz archive. This means that choosenim depends on `unxz` on Linux.
* Improve messages during the first installation.

## 0.2.2 - 17/05/2017

Includes two bug fixes.

* The exit codes are now handled correctly for proxied executables.
* Choosenim now checks for the presence of a `lib` directory inside
  ``~/.nimble`` and offers to remove it.
  (Issue [#13](https://github.com/dom96/choosenim/issues/13))

## 0.2.0 - 09/05/2017

Includes multiple bug fixes and some improvements.

* Implements warning when Nimble's version is lower than 0.8.6. (Issue
  [#10](https://github.com/dom96/choosenim/issues/10))
* Improves choosenim unix init script to support stdin properly.
* Fixes invalid condition for checking the presence of a C compiler.
* Fixes relative paths not being expanded when they are selected by a user.
* Fixes problem with updating a version not a channel.

----

Full changelog: https://github.com/dom96/choosenim/compare/v0.1.0...v0.2.0
