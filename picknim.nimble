# Package

version       = "0.1.0"
author        = "Dominik Picheta"
description   = "The Nim toolchain installer."
license       = "MIT"

srcDir = "src"
bin = @["picknim"]

skipExt = @["nim"]

# Dependencies

requires "nim >= 0.15.3", "nimble >= 0.8.0", "docopt >= 0.6.4", "untar >= 0.1.0"

