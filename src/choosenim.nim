import os, strutils

import nimblepkg/[cli, tools, version]
import nimblepkg/common as nimbleCommon

import choosenim/[download, builder, switcher, common, cliparams]
import choosenim/[utils, channel]

proc parseVersion(versionStr: string): Version =
  try:
    result = newVersion(versionStr)
  except:
    let msg = "Invalid version, path or unknown channel. " &
              "Try 0.16.0, #head, #commitHash, or stable. " &
              "See --help for more examples."
    raise newException(ChooseNimError, msg)

proc installVersion(version: Version, params: CliParams) =
  # Install the requested version.
  let path = download(version, params)
  # Extract the downloaded file.
  let extractDir = params.getInstallationDir(version)
  extract(path, extractDir)
  # Build the compiler
  build(extractDir, version, params)

proc chooseVersion(version: string, params: CliParams) =
  # Command is a version.
  let version = parseVersion(version)

  # Verify that C compiler is installed.
  if params.needsCC():
    when defined(windows):
      # Install MingW.
      let path = downloadMingw32(params)
      extract(path, getMingwPath(params))
    else:
      display("Warning:", "No C compiler found. Nim compiler might fail.",
              Warning, HighPriority)
      display("Hint:", "Install clang or gcc using your favourite package manager.",
              Warning, HighPriority)

  # Verify that DLLs (openssl primarily) are installed.
  when defined(windows):
    if params.needsDLLs():
      # Install DLLs.
      let path = downloadDLLs(params)
      extract(path, getBinDir(params))

  if not params.isVersionInstalled(version):
    installVersion(version, params)

  switchTo(version, params)

proc choose(params: CliParams) =
  if dirExists(params.command):
    # Command is a file path likely pointing to an existing Nim installation.
    switchTo(params.command, params)
  else:
    # Check for release channel.
    if params.command.isReleaseChannel():
      let version = getChannelVersion(params.command, params)

      chooseVersion(version, params)
      pinChannelVersion(params.command, version, params)
    else:
      chooseVersion(params.command, params)

proc update(params: CliParams) =
  if params.commands.len != 2:
    raise newException(ChooseNimError,
                        "Expected 1 parameter to 'update' command")

  let param = params.commands[1]
  display("Updating", param, priority = HighPriority)

  # Retrieve the current version for the specified channel.
  let version = getChannelVersion(param, params, live=true).newVersion

  # Ensure that the version isn't already installed.
  if not canUpdate(version, params):
    display("Info:", "Already up to date at version " & $version,
            Success, HighPriority)
    return

  # Install the new version and pin it.
  installVersion(version, params)
  pinChannelVersion(param, $version, params)

  display("Updated", "to " & $version, Success, HighPriority)

proc performAction(params: CliParams) =
  case params.command.normalize
  of "update":
    update(params)
  else:
    choose(params)

when isMainModule:
  var error = ""
  var hint = ""
  try:
    let params = getCliParams()
    performAction(params)
  except NimbleError:
    let currentExc = (ref NimbleError)(getCurrentException())
    (error, hint) = getOutputInfo(currentExc)

  if error.len > 0:
    displayTip()
    display("Error:", error, Error, HighPriority)
    if hint.len > 0:
      display("Hint:", hint, Warning, HighPriority)
    quit(1)

