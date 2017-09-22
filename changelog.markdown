# Choosenim changelog

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