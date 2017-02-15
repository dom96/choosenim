import os

import nimblepkg/[cli, version]

import options

proc getInstallationDir*(version: Version): string =
  return getInstallDir() / ("nim-$1" % $version)

proc isVersionInstalled*(version: Version): bool =
  return fileExists(getInstallDir() / getInstallationDir(version))

proc switchTo*(version: Version) =
  ## Writes the appropriate proxy into $nimbleDir/bin.
