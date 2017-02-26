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
  return fileExists(getInstallationDir(version) / "bin" /
                    "nim".addFileExt(ExeExt))

proc switchTo*(version: Version) =
  ## Writes the appropriate proxy into $nimbleDir/bin.
  assert isVersionInstalled(version), "Cannot switch to non-installed version"

  # Verify that the proxy executables are present.
  let nimProxyPath = getBinDir() / "nim".addFileExt(ExeExt)
  writeFile(nimProxyPath, proxyExe)
  # Make sure the exe has +x flag.
  setFilePermissions(nimProxyPath,
                     getFilePermissions(nimProxyPath) + {fpUserExec})

  # TODO: Check whether `nimble` symlink exists, think about what to do.

  # Write selected path to "current file".
  writeFile(getCurrentFile(), getInstallationDir(version))

  display("Switched", "to Nim " & $version, Success, HighPriority)
