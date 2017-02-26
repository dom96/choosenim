import os

import nimblepkg/[cli, tools, version]
import nimblepkg/common as nimbleCommon

import choosenim/[download, builder, options, switcher, common, cliparams]
import choosenim/utils

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
    let extractDir = getInstallationDir(version)
    extract(path, extractDir)
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

