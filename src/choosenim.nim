# Copyright (C) Dominik Picheta. All rights reserved.
# BSD-3-Clause License. Look at license.txt for more info.
import os, strutils

import nimblepkg/[cli, tools, version]
import nimblepkg/common as nimbleCommon
from nimblepkg/packageinfo import getNameVersion

import choosenim/[download, builder, switcher, common, cliparams]
import choosenim/[utils, channel, telemetry]

proc parseVersion(versionStr: string): Version =
  if versionStr[0] notin {'#', '\0'} + Digits:
    let msg = "Invalid version, path or unknown channel. " &
              "Try 0.16.0, #head, #commitHash, or stable. " &
              "See --help for more examples."
    raise newException(ChooseNimError, msg)

  let parts = versionStr.split(".")
  if parts.len >= 3 and parts[2].parseInt() mod 2 != 0:
    let msg = ("Version $# is a development version of Nim. This means " &
              "it hasn't been released so you cannot install it this " &
              "way. All unreleased versions of Nim " &
              "have an odd patch number in their version.") % versionStr
    let exc = newException(ChooseNimError, msg)
    exc.hint = "If you want to install the development version then run " &
               "`choosenim devel`."
    raise exc

  result = newVersion(versionStr)

proc installVersion(version: Version, params: CliParams) =
  # Install the requested version.
  let path = download(version, params)
  # Extract the downloaded file.
  let extractDir = params.getInstallationDir(version)
  # Make sure no stale files from previous installation exist.
  removeDir(extractDir)
  extract(path, extractDir)
  # A "special" version is downloaded from GitHub and thus needs a `.git`
  # directory in order to let `koch` know that it should download a "devel"
  # Nimble.
  if version.isSpecial:
    createDir(extractDir / ".git")
  # Build the compiler
  build(extractDir, version, params)

proc chooseVersion(version: string, params: CliParams) =
  # Command is a version.
  let version = parseVersion(version)

  # Verify that C compiler is installed.
  if params.needsCCInstall():
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
    if params.needsDLLInstall():
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
      setCurrentChannel(params.command, params)
    else:
      chooseVersion(params.command, params)

proc updateSelf(params: CliParams) =
  display("Updating", "choosenim", priority = HighPriority)

  let version = getChannelVersion("self", params, live=true).newVersion
  if version <= chooseNimVersion.newVersion:
    display("Info:", "Already up to date at version " & chooseNimVersion,
            Success, HighPriority)
    return

  # https://stackoverflow.com/a/9163044/492186
  let tag = "v" & $version
  let filename = "choosenim-" & $version & "_" & hostOS & "_" & hostCPU
  let url = "https://github.com/dom96/choosenim/releases/download/$1/$2" % [
    tag, filename
  ]
  let newFilename = getAppDir() / "choosenim_new".addFileExt(ExeExt)
  downloadFile(url, newFilename, params)

  let appFilename = getAppFilename()
  # Move choosenim.exe to choosenim_ver.exe
  let oldFilename = "choosenim_" & chooseNimVersion.addFileExt(ExeExt)
  display("Info:", "Renaming '$1' to '$2'" % [appFilename, oldFilename])
  moveFile(appFilename, getAppDir() / oldFilename)

  # Move choosenim_new.exe to choosenim.exe
  display("Info:", "Renaming '$1' to '$2'" % [newFilename, appFilename])
  moveFile(newFilename, appFilename)

  display("Info:", "Setting +x on downloaded file")
  inclFilePermissions(appFilename, {fpUserExec, fpGroupExec})

  display("Info:", "Updated choosenim to version " & $version,
          Success, HighPriority)

proc update(params: CliParams) =
  if params.commands.len != 2:
    raise newException(ChooseNimError,
                       "Expected 1 parameter to 'update' command")

  let channel = params.commands[1]
  if channel.toLowerAscii() == "self":
    updateSelf(params)
    return

  display("Updating", channel, priority = HighPriority)

  # Retrieve the current version for the specified channel.
  let version = getChannelVersion(channel, params, live=true).newVersion

  # Ensure that the version isn't already installed, unless `--force` was used.
  if not (canUpdate(version, params) or params.forceUpdate):
    display("Info:", "Already up to date at version " & $version,
            Success, HighPriority)
    if getSelectedVersion(params) != version:
      switchTo(version, params)
    return

  # Make sure the archive is downloaded again if the version is special.
  if version.isSpecial:
    removeDir(params.getDownloadPath($version).splitFile.dir)

  # Install the new version and pin it.
  installVersion(version, params)
  pinChannelVersion(channel, $version, params)

  display("Updated", "to " & $version, Success, HighPriority)

  # If the currently selected channel is the one that was updated, switch to
  # the new version.
  if getCurrentChannel(params) == channel:
    switchTo(version, params)

proc show(params: CliParams) =
  let channel = getCurrentChannel(params)
  let path = getSelectedPath(params)
  if channel.len > 0:
    display("Channel:", channel, priority = HighPriority)
  else:
    display("Channel:", "No channel selected", priority = HighPriority)

  let (_, version) = getNameVersion(path)
  if version != "":
    display("Version:", version, priority = HighPriority)

  display("Path:", path, priority = HighPriority)

proc performAction(params: CliParams) =
  # Report telemetry.
  report(initEvent(ActionEvent), params)

  case params.command.normalize
  of "update":
    update(params)
  of "show":
    show(params)
  else:
    choose(params)

proc handleTelemetry(params: CliParams) =
  if params.hasPendingReports():
    display("Info:", "Waiting 5 secs for remaining telemetry data to be sent.",
            priority=HighPriority)
    waitForReport(5, params)
    if params.hasPendingReports():
      display("Warning:", "Could not send all telemetry data.",
              Warning, HighPriority)

when isMainModule:
  var error = ""
  var hint = ""
  var params = newCliParams(proxyExeMode = false)
  try:
    parseCliParams(params)
    createDir(params.chooseNimDir)
    discard loadAnalytics(params)
    performAction(params)
  except NimbleError:
    let currentExc = (ref NimbleError)(getCurrentException())
    (error, hint) = getOutputInfo(currentExc)
    # Report telemetry.
    report(currentExc, params)
    report(initEvent(ErrorEvent, label=currentExc.msg), params)

  if error.len > 0:
    displayTip()
    display("Error:", error, Error, HighPriority)
    if hint.len > 0:
      display("Hint:", hint, Warning, HighPriority)
    handleTelemetry(params)
    quit(QuitFailure)

  handleTelemetry(params)
