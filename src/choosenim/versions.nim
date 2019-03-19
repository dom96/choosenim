
import os, strutils, algorithm, sequtils

import nimblepkg/version
from nimblepkg/packageinfo import getNameVersion

import download, cliparams, channel, switcher, utils

proc getLocalVersions(params: CliParams): seq[Version] =
  let path = getSelectedPath(params)

  proc cmpVersions(x: Version, y: Version): int =
    if x == y: return 0
    if x < y: return -1
    return 1

  var localVersions: seq[Version] = @[] 
  # check for the locally installed versions of Nim,
  for path in walkDirs(params.getInstallDir() & "/*"):
    let (_, version) = getNameVersion(path)
    let displayVersion = version.newVersion
    if isVersionInstalled(params, displayVersion):
      localVersions.add(displayVersion)
  localVersions.sort(cmpVersions, SortOrder.Descending)
  return localVersions

proc getSpecialVersions*(params: CliParams): seq[Version] =
  var specialVersions = getLocalVersions(params)
  specialVersions.keepItIf(it.isSpecial())
  return specialVersions

proc getInstalledVersions*(params: CliParams): seq[Version] =
  var installedVersions = getLocalVersions(params)
  installedVersions.keepItIf(not it.isSpecial())
  return installedVersions

proc getAvailableVersions*(params: CliParams): seq[Version] =
  var releases = getOfficialReleases(params)
  return releases

proc getCurrentVersion*(params: CliParams): Version =
  let path = getSelectedPath(params)
  let (currentName, currentVersion) = getNameVersion(path)
  return currentVersion.newVersion

proc getLatestVersion*(params: CliParams): Version =
  let channel = getCurrentChannel(params)
  let latest = getChannelVersion(channel, params)
  return latest.newVersion
  
proc isLatestVersion*(params: CliParams, version: Version): bool =
  let isLatest = (getLatestVersion(params) == version)
  return isLatest
