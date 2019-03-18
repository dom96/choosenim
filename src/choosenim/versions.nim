
import os, strutils, algorithm, sequtils

import nimblepkg/version
from nimblepkg/packageinfo import getNameVersion

import download, cliparams, channel, switcher, utils

proc normalizeVersion*(version: string): string =
  if not (version in @["#devel", "#head"]):
    return version.strip(true, false, {'#', 'v'})
  else:
    return version

proc getLocalVersions(params: CliParams): seq[string] =
  let path = getSelectedPath(params)
  
  var localVersions: seq[string] = @[] 
  # check for the locally installed versions of Nim,
  for path in walkDirs(params.getInstallDir() & "/*"):
    let (_, version) = getNameVersion(path)
    if isVersionInstalled(params, parseVersion(version)):
      let displayVersion = version.normalizeVersion()
      localVersions.add(displayVersion)
  localVersions.sort(system.cmp[string], SortOrder.Descending)
  return localVersions

proc getSpecialVersions*(params: CliParams): seq[string] =
  var specialVersions = getLocalVersions(params)
  specialVersions.keepItIf(it.endsWith("#devel") or it.endsWith("#head"))
  return specialVersions

proc getInstalledVersions*(params: CliParams): seq[string] =
  var installedVersions = getLocalVersions(params)
  installedVersions.keepItIf(not (it.endsWith("#devel") or it.endsWith("#head")))
  return installedVersions

proc getAvailableVersions*(params: CliParams): seq[string] =
  var releases = getOfficialReleases(params)
  releases.applyIt(it.normalizeVersion)
  return releases

proc getCurrentVersion*(params: CliParams): string =
  let path = getSelectedPath(params)
  let (currentName, currentVersion) = getNameVersion(path)  
  return currentVersion.normalizeVersion()

proc getLatestVersion*(params: CliParams): string =
  let channel = getCurrentChannel(params)
  let latest = getChannelVersion(channel, params).normalizeVersion()
  return latest
  
proc isLatestVersion*(params: CliParams, version: string): bool =
  let isLatest = (getLatestVersion(params) == version)
  return isLatest
