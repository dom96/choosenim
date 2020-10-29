# Package

version       = "0.7.5"
author        = "Dominik Picheta"
description   = "The Nim toolchain installer."
license       = "MIT"

srcDir = "src"
binDir = "bin"
bin = @["choosenim"]

skipExt = @["nim"]

# Dependencies

requires "nim >= 1.2.6", "nimble#8f7af86"
requires "nimterop >= 0.6.12", "nimarchive >= 0.5.3"
#requires "libcurl >= 1.0.0" - OSX now uses httpclient
requires "analytics >= 0.2.0"
requires "osinfo >= 0.3.0"
