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

proc writeProxy(bin: string) =
  let proxyPath = getBinDir() / bin.addFileExt(ExeExt)

  if symlinkExists(proxyPath):
    let msg = "Symlink for '$1' detected in '$2'. Can I remove it?" %
              [bin, proxyPath.splitFile().dir]
    if not prompt(dontForcePrompt, msg): return
    let symlinkPath = expandSymlink(proxyPath)
    removeFile(proxyPath)
    display("Removed", "symlink pointing to $1" % symlinkPath,
            priority = HighPriority)

  writeFile(proxyPath, proxyExe)
  # Make sure the exe has +x flag.
  setFilePermissions(proxyPath,
                     getFilePermissions(proxyPath) + {fpUserExec})
  display("Installed", "component '$1'" % bin, priority = HighPriority)

proc switchTo*(version: Version) =
  ## Writes the appropriate proxy into $nimbleDir/bin.
  assert isVersionInstalled(version), "Cannot switch to non-installed version"

  # Return early if this version is already selected.
  if readFile(getCurrentFile()) == getInstallationDir(version):
    display("Info:", "Version $1 already selected" % $version,
            priority = HighPriority)
    return
  else:
    # Write selected path to "current file".
    writeFile(getCurrentFile(), getInstallationDir(version))

  # Create the proxy executables.
  writeProxy("nim")
  writeProxy("nimble")
  writeProxy("nimgrep")
  writeProxy("nimsuggest")

  display("Switched", "to Nim " & $version, Success, HighPriority)
