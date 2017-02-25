import os

import nimblepkg/[cli, tools, version]
import nimblepkg/common as nimbleCommon
import untar

import choosenimpkg/[download, builder, options, switcher, common, cliparams]

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
  let params = getCliParams()

  var error = ""
  var hint = ""
  try:
    choose(params.version)
  except NimbleError:
    let currentExc = (ref NimbleError)(getCurrentException())
    (error, hint) = getOutputInfo(currentExc)

  if error.len > 0:
    displayTip()
    display("Error:", error, Error, HighPriority)
    if hint.len > 0:
      display("Hint:", hint, Warning, HighPriority)
    quit(1)

