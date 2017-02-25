import os

import docopt
import nimblepkg/[cli, tools, version]
import nimblepkg/common as nimbleCommon
import untar

import choosenimpkg/[download, builder, options, switcher, common]

let doc = """
choosenim: The Nim toolchain installer.

Usage:
  choosenim <version>

Options:
  -h --help     Show this screen.
  --version     Show version.
"""

const
  chooseNimVersion = "0.1.0"

proc parseVersion(versionStr: string): Version =
  try:
    result = newVersion(versionStr)
  except:
    let msg = "Invalid version. Try 0.16.0, #head or #commitHash."
    raise newException(ChooseNimError, msg)

proc choose(versionStr: string) =
  let version = parseVersion(versionStr)

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
  let args = docopt(doc, version = "choosenim v" & chooseNimVersion)

  var error = ""
  var hint = ""
  try:
    choose($args["<version>"])
  except NimbleError:
    let currentExc = (ref NimbleError)(getCurrentException())
    (error, hint) = getOutputInfo(currentExc)

  if error.len > 0:
    displayTip()
    display("Error:", error, Error, HighPriority)
    if hint.len > 0:
      display("Hint:", hint, Warning, HighPriority)
    quit(1)

