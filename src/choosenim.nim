# Copyright (C) Dominik Picheta. All rights reserved.
# BSD-3-Clause License. Look at license.txt for more info.
import os, strutils, algorithm

import nimblepkg/[cli, version]
import nimblepkg/common as nimbleCommon
from nimblepkg/packageinfo import getNameVersion

import choosenimpkg/[download, builder, switcher, common, cliparams, versions]
import choosenimpkg/[utils, channel, ssl, telemetry]

when defined(windows):
  import choosenimpkg/env

  import times

proc installVersion(version: Version, params: CliParams) =
  let
    extractDir = params.getInstallationDir(version)
    updated = gitUpdate(version, extractDir, params)

  if not updated:
    # Install the requested version.
    let path = download(version, params)
    defer:
      # Delete downloaded file
      discard tryRemoveFile(path)
    # Make sure no stale files from previous installation exist.
    removeDir(extractDir)
    # Extract the downloaded file.
    extract(path, extractDir)

    # A "special" version is downloaded from GitHub and thus needs a `.git`
    # directory in order to let `koch` know that it should download a "devel"
    # Nimble.
    if version.isSpecial:
      gitInit(version, extractDir, params)

  # Build the compiler
  build(extractDir, version, params)

proc chooseVersion(version: string, params: CliParams) =
  # Command is a version.
  let version = parseVersion(version)

  # Verify that C compiler is installed.
  if params.needsCCInstall():
    when defined(windows):
      # Install MingW.
      let path = downloadMingw(params)
      extract(path, getMingwPath(params))
    else:
      let binName =
        when defined(macosx):
          "clang"
        else:
          "gcc"

      raise newException(
        ChooseNimError,
        "No C compiler found. Nim compiler requires a C compiler.\n" &
        "Install " & binName & " using your favourite package manager."
      )

  # Verify that DLLs (openssl primarily) are installed.
  when defined(windows):
    if params.needsDLLInstall():
      # Install DLLs.
      let
        path = downloadDLLs(params)
        tempDir = getTempDir() / "choosenim-dlls"
        binDir = getBinDir(params)
      removeDir(tempDir)
      createDir(tempDir)
      extract(path, tempDir)
      for kind, path in walkDir(tempDir, relative = true):
        if kind == pcFile:
          try:
            if not fileExists(binDir / path) or
              getLastModificationTime(binDir / path) < getLastModificationTime(tempDir / path):
              moveFile(tempDir / path, binDir / path)
              display("Info:", "Copied '$1' to '$2'" % [path, binDir], priority = HighPriority)
          except:
            discard
      removeDir(tempDir)

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

  when defined(windows):
    # Check and add ~/.nimble/bin to PATH
    if not isNimbleBinInPath(params) and params.firstInstall:
      setNimbleBinPath(params)

proc updateSelf(params: CliParams) =
  display("Updating", "choosenim", priority = HighPriority)

  let version = getChannelVersion("self", params, live=true).newVersion
  if not params.force and version <= chooseNimVersion.newVersion:
    display("Info:", "Already up to date at version " & chooseNimVersion,
            Success, HighPriority)
    return

  # https://stackoverflow.com/a/9163044/492186
  let tag = "v" & $version
  let filename = "choosenim-" & $version & "_" & hostOS & "_" & hostCPU.addFileExt(ExeExt)
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

  # Ensure that the version isn't already installed.
  if not canUpdate(version, params):
    display("Info:", "Already up to date at version " & $version,
            Success, HighPriority)
    pinChannelVersion(channel, $version, params)
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
  let (_, version) = getNameVersion(path)
  if version != "":
    display("Selected:", version, priority = HighPriority)

  if channel.len > 0:
    display("Channel:", channel, priority = HighPriority)
  else:
    display("Channel:", "No channel selected", priority = HighPriority)

  display("Path:", path, priority = HighPriority)

  var versions: seq[string] = @[]
  for path in walkDirs(params.getInstallDir() & "/*"):
    let (_, versionAvailable) = getNameVersion(path)
    versions.add(versionAvailable)

  if versions.len() > 1:
    versions.sort(system.cmp, Descending)
    if versions.contains("#head"):
      versions.del(find(versions, "#head"))
      versions.insert("#head", 0)
    if versions.contains("#devel"):
      versions.del(find(versions, "#devel"))
      versions.insert("#devel", 0)

    echo ""
    display("Versions:", " ", priority = HighPriority)
    for ver in versions:
      if ver == version:
        display("*", ver, Success, HighPriority)
      else:
        display("", ver, priority = HighPriority)

proc versions(params: CliParams) =
  let currentChannel = getCurrentChannel(params)
  let currentVersion = getCurrentVersion(params)

  let specialVersions = getSpecialVersions(params)
  let localVersions = getInstalledVersions(params)

  let remoteVersions =
    if params.onlyInstalled: @[]
    else: getAvailableVersions(params)

  proc isActiveTag(params: CliParams, version: Version): string =
    let tag =
      if version == currentVersion: "*"
      else: " " # must have non-zero length, or won't be displayed
    return tag

  proc isLatestTag(params: CliParams, version: Version): string =
    let tag =
      if isLatestVersion(params, version): " (latest)"
      else: ""
    return tag

  proc canUpdateTag(params: CliParams, channel: string): string =
    let version = getChannelVersion(channel, params, live = (not params.onlyInstalled))
    let channelVersion = parseVersion(version)
    let tag =
      if canUpdate(channelVersion, params): " (update available!)"
      else: ""
    return tag

  #[ Display version information,now that it has been collected ]#

  if currentChannel.len > 0:
    display("Channel:", currentChannel & canUpdateTag(params, currentChannel), priority = HighPriority)
    echo ""

  # local versions
  display("Installed:", " ", priority = HighPriority)
  for version in localVersions:
    let activeDisplay =
      if version == currentVersion: Success
      else: Message
    display(isActiveTag(params, version), $version & isLatestTag(params, version), activeDisplay, priority = HighPriority)
  for version in specialVersions:
    display(isActiveTag(params, version), $version, priority = HighPriority)
  echo ""

  # if the "--installed" flag was passed, don't display remote versions as we didn't fetch data for them.
  if (not params.onlyInstalled):
    display("Available:", " ", priority = HighPriority)
    for version in remoteVersions:
      if not (version in localVersions):
        display("", $version & isLatestTag(params, version), priority = HighPriority)
    echo ""

proc remove(params: CliParams) =
  if params.commands.len != 2:
    raise newException(ChooseNimError,
                       "Expected 1 parameter to 'remove' command")

  let version = params.commands[1].newVersion

  let isInstalled = isVersionInstalled(params, version)
  if not isInstalled:
    raise newException(ChooseNimError,
                       "Version $1 is not installed." % $version)

  display("Removing", $version, priority = HighPriority)

  let extractDir = params.getInstallationDir(version)
  removeDir(extractDir)

  display("Info:", "Removed version " & $version,
          Success, HighPriority)

  # TODO: switch to latest available version if current was removed

proc performAction(params: CliParams) =
  # Report telemetry.
  report(initEvent(ActionEvent), params)

  case params.command.normalize
  of "update":
    update(params)
  of "show":
    show(params)
  of "versions":
    versions(params)
  of "remove":
    remove(params)
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
