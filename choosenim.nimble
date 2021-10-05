# Package

version       = "0.8.2"
author        = "Dominik Picheta"
description   = "The Nim toolchain installer."
license       = "MIT"

srcDir = "src"
binDir = "bin"
bin = @["choosenim"]

skipExt = @["nim"]

# Dependencies

requires "nim >= 1.2.6", "nimble#8f7af86"
when defined(macosx):
  requires "libcurl >= 1.0.0"
requires "analytics >= 0.3.0"
requires "osinfo >= 0.3.0"
requires "zippy >= 0.7.2"
when defined(windows):
  requires "puppy 1.2.1"

task release, "Build a release binary":
  exec "nimble build -d:release"