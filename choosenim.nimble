# Package
import std/[os, strutils]

version       = "0.8.4"
author        = "Dominik Picheta"
description   = "The Nim toolchain installer."
license       = "BSD"

srcDir = "src"
binDir = "bin"
bin = @["choosenim"]

skipExt = @["nim"]

# Dependencies

# Note: https://github.com/dom96/choosenim/issues/233 (need to resolve when updating Nimble)
requires "nim >= 1.2.6", "nimble#8f7af86"
requires "libcurl >= 1.0.0"
requires "https://github.com/ire4ever1190/osinfo#aa7d296"
requires "zippy >= 0.7.2"
when defined(windows):
  requires "puppy >= 1.5.4"
