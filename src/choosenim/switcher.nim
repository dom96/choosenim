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

proc getProxyPath(bin: string): string =
  return getBinDir() / bin.addFileExt(ExeExt)

proc areProxiesInstalled(proxies: openarray[string]): bool =
  result = true
  for proxy in proxies:
    # Verify that proxy exists.
    let path = getProxyPath(proxy)
    if not fileExists(path):
      return false

    # Verify that proxy binary is up-to-date.
    let contents = readFile(path)
    if contents != proxyExe:
      return false

proc writeProxy(bin: string) =
  # Create the ~/.nimble/bin dir in case it doesn't exist.
  createDir(getBinDir())

  let proxyPath = getProxypath(bin)

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

  # Check whether this is in the user's PATH.
  let fromPATH = findExe(bin)
  if fromPATH == "":
    display("Hint:", ("Binary '$1' isn't in your PATH. Add '$2' to " &
                     "your PATH.") % [bin, getBinDir()], Warning, HighPriority)
  elif fromPATH != proxyPath:
    display("Warning:", "Binary '$1' is shadowed by '$2'." %
            [bin, fromPATH], Warning, HighPriority)
    display("Hint:", "Ensure that '$1' is before '$2' in the PATH env var." %
            [getBinDir(), fromPATH.splitFile.dir], Warning, HighPriority)

proc switchTo*(version: Version) =
  ## Writes the appropriate proxy into $nimbleDir/bin.
  assert isVersionInstalled(version), "Cannot switch to non-installed version"

  const proxies = [
    "nim",
    "nimble",
    "nimgrep",
    "nimsuggest"
  ]

  # Return early if this version is already selected.
  let selectedVersion =
    if fileExists(getCurrentFile()): readFile(getCurrentFile())
    else: ""
  let proxiesInstalled = areProxiesInstalled(proxies)
  if selectedVersion == getInstallationDir(version) and proxiesInstalled:
    display("Info:", "Version $1 already selected" % $version,
            priority = HighPriority)
    return
  else:
    # Write selected path to "current file".
    writeFile(getCurrentFile(), getInstallationDir(version))

  # Create the proxy executables.
  for proxy in proxies:
    writeProxy(proxy)

  display("Switched", "to Nim " & $version, Success, HighPriority)
