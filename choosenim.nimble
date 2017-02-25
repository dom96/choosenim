# Package

version       = "0.1.0"
author        = "Dominik Picheta"
description   = "The Nim toolchain installer."
license       = "MIT"

srcDir = "src"
bin = @["choosenim"]

skipExt = @["nim"]

# Dependencies

requires "nim >= 0.16.1", "nimble >= 0.8.0", "untar >= 0.1.0"

