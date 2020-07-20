# Package

version       = "0.6.0"
author        = "Dominik Picheta"
description   = "The Nim toolchain installer."
license       = "MIT"

srcDir = "src"
binDir = "bin"
bin = @["choosenim"]

skipExt = @["nim"]

# Dependencies

requires "nim >= 1.2.4", "nimble#14a6946", "nimarchive >= 0.5.2"
requires "libcurl >= 1.0.0"
requires "analytics >= 0.2.0"
requires "osinfo >= 0.3.0"

task test, "Run the choosenim tester!":
  withDir "tests":
    exec "nim c -r tester"
