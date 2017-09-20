# Package

version       = "0.2.2"
author        = "Dominik Picheta"
description   = "The Nim toolchain installer."
license       = "MIT"

srcDir = "src"
binDir = "bin"
bin = @["choosenim"]

skipExt = @["nim"]

# Dependencies

requires "nim >= 0.16.1", "nimble >= 0.8.5", "untar >= 0.1.0"
requires "libcurl >= 1.0.0"
requires "analytics >= 0.1.0"

task test, "Run the choosenim tester!":
  withDir "tests":
    exec "nim c -r tester"