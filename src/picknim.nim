import os

import docopt
import nimblepkg/[cli, tools, version, common]
import untar

import picknimpkg/[download, builder, options, switcher]

let doc = """
picknim: The Nim toolchain installer.

Usage:
  picknim <version>

Options:
  -h --help     Show this screen.
  --version     Show version.
"""

const
  pickNimVersion = "0.1.0"

proc pick(versionStr: string) =
  let version = newVersion(versionStr)

  if not isVersionInstalled(version):
    # Install the requested version.
    let path = download(version)
    # Extract the downloaded file.
    display("Extracting", path.extractFilename(), priority = HighPriority)
    var file = newTarFile(path)
    let extractDir = getInstallationDir(version)
    removeDir(extractDir)
    file.extract(extractDir)
    # Build the compiler
    build(extractDir, version)

switchTo(version)

when isMainModule:
  let args = docopt(doc, version = "picknim v" & pickNimVersion)

  var error = ""
  var hint = ""
  try:
    pick($args["<version>"])
  except NimbleError:
    let currentExc = (ref NimbleError)(getCurrentException())
    (error, hint) = getOutputInfo(currentExc)

  if error.len > 0:
    displayTip()
    display("Error:", error, Error, HighPriority)
    if hint.len > 0:
      display("Hint:", hint, Warning, HighPriority)
    quit(1)

