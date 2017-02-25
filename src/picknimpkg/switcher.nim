import os, strutils

import nimblepkg/[cli, version]

import options

static:
  when defined(release):
    const output = staticExec "nim c -d:release proxyexe"
  else:
    const output = staticExec "nim c proxyexe"
  doAssert("operation successful" in output)

const
  proxyExe = staticRead("proxyexe".addFileExt(ExeExt))

proc getInstallationDir*(version: Version): string =
  return getInstallDir() / ("nim-$1" % $version)

proc isVersionInstalled*(version: Version): bool =
  return fileExists(getInstallDir() / getInstallationDir(version))

proc switchTo*(version: Version) =
  ## Writes the appropriate proxy into $nimbleDir/bin.
  assert isVersionInstalled(version), "Cannot switch to non-installed version"

  # Verify that the proxy executables are present.
  let nimProxyPath = getBinDir() / "nim".addFileExt(ExeExt)
  if not fileExists(nimProxyPath):
    writeFile(nimProxyPath, proxyExe)

  # Write selected path to "current file".
  writeFile(getCurrentFile(), getInstallationDir(version))

