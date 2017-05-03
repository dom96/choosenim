import os, strutils

import nimblepkg/[cli, version]

import cliparams, common

static:
  when defined(release):
    const output = staticExec "nim c -d:release proxyexe"
  else:
    const output = staticExec "nim c proxyexe"
  doAssert("operation successful" in output)

const
  proxyExe = staticRead("proxyexe".addFileExt(ExeExt))

proc getInstallationDir*(params: CliParams, version: Version): string =
  return params.getInstallDir() / ("nim-$1" % $version)

proc isVersionInstalled*(params: CliParams, version: Version): bool =
  return fileExists(params.getInstallationDir(version) / "bin" /
                    "nim".addFileExt(ExeExt))

proc getSelectedPath(params: CliParams): string =
  if fileExists(params.getCurrentFile()): readFile(params.getCurrentFile())
  else: ""

proc getProxyPath(params: CliParams, bin: string): string =
  return params.getBinDir() / bin.addFileExt(ExeExt)

proc areProxiesInstalled(params: CliParams, proxies: openarray[string]): bool =
  result = true
  for proxy in proxies:
    # Verify that proxy exists.
    let path = params.getProxyPath(proxy)
    if not fileExists(path):
      return false

    # Verify that proxy binary is up-to-date.
    let contents = readFile(path)
    if contents != proxyExe:
      return false

proc needsCC*(params: CliParams): bool =
  ## Determines whether the system needs a C compiler.
  return findExe("gcc") == "" and findExe("clang") == ""

proc needsDLLs*(params: CliParams): bool =
  ## Determines whether DLLs need to be installed (Windows-only).
  ##
  ## TODO: In the future we can probably extend this and let the user
  ## know what DLLs they are missing on all operating systems.
  let inPath = findExe("libeay32", extensions=["dll"]) != "" and
               findExe("ssleay32", extensions=["dll"]) != ""
  let inNimbleBin = fileExists(params.getBinDir() / "libeay32.dll") and
                    fileExists(params.getBinDir() / "ssleay32.dll")
  let isInstalled = inPath or inNimbleBin
  return not isInstalled

proc writeProxy(bin: string, params: CliParams) =
  # Create the ~/.nimble/bin dir in case it doesn't exist.
  createDir(params.getBinDir())

  let proxyPath = params.getProxyPath(bin)

  if symlinkExists(proxyPath):
    let msg = "Symlink for '$1' detected in '$2'. Can I remove it?" %
              [bin, proxyPath.splitFile().dir]
    if not prompt(dontForcePrompt, msg): return
    let symlinkPath = expandSymlink(proxyPath)
    removeFile(proxyPath)
    display("Removed", "symlink pointing to $1" % symlinkPath,
            priority = HighPriority)

  # Don't write the file again if it already exists.
  if fileExists(proxyPath) and readFile(proxyPath) == proxyExe: return

  writeFile(proxyPath, proxyExe)
  # Make sure the exe has +x flag.
  setFilePermissions(proxyPath,
                     getFilePermissions(proxyPath) + {fpUserExec})
  display("Installed", "component '$1'" % bin, priority = HighPriority)

  # Check whether this is in the user's PATH.
  let fromPATH = findExe(bin)
  if fromPATH == "":
    display("Hint:", "Binary '$1' isn't in your PATH. Add '$2' to your PATH." %
            [bin, params.getBinDir()], Warning, HighPriority)
  elif fromPATH != proxyPath:
    display("Warning:", "Binary '$1' is shadowed by '$2'." %
            [bin, fromPATH], Warning, HighPriority)
    display("Hint:", "Ensure that '$1' is before '$2' in the PATH env var." %
            [params.getBinDir(), fromPATH.splitFile.dir], Warning, HighPriority)

proc switchToPath(filepath: string, params: CliParams): bool =
  ## Switches to the specified file path that should point to the root of
  ## the Nim repo.
  ##
  ## Returns `false` when no switching occurs (because that version was
  ## already selected).
  result = true
  if not fileExists(filepath / "bin" / "nim".addFileExt(ExeExt)):
    let msg = "No 'nim' binary found in '$1'." % filepath / "bin"
    raise newException(ChooseNimError, msg)

  var proxiesToInstall = @proxies
  # Handle MingW proxies.
  when defined(windows):
    if needsCC(params):
      let mingwBin = getMingwBin(params)
      if not fileExists(mingwBin / "gcc".addFileExt(ExeExt)):
        let msg = "No 'gcc' binary found in '$1'." % mingwBin
        raise newException(ChooseNimError, msg)

      proxiesToInstall.add(mingwProxies)

  # Return early if this version is already selected.
  let selectedPath = params.getSelectedPath()
  let proxiesInstalled = params.areProxiesInstalled(proxies)
  if selectedPath == filepath and proxiesInstalled:
    return false
  else:
    # Write selected path to "current file".
    writeFile(params.getCurrentFile(), filepath)

  # Create the proxy executables.
  for proxy in proxiesToInstall:
    writeProxy(proxy, params)

proc switchTo*(version: Version, params: CliParams) =
  ## Switches to the specified version by writing the appropriate proxy
  ## into $nimbleDir/bin.
  assert params.isVersionInstalled(version),
         "Cannot switch to non-installed version"

  if switchToPath(params.getInstallationDir(version), params):
    display("Switched", "to Nim " & $version, Success, HighPriority)
  else:
    display("Info:", "Version $1 already selected" % $version,
            priority = HighPriority)

proc switchTo*(filepath: string, params: CliParams) =
  ## Switches to an existing Nim installation.
  if switchToPath(filepath, params):
    display("Switched", "to Nim ($1)" % filepath, Success, HighPriority)
  else:
    display("Info:", "Path '$1' already selected" % filepath,
            priority = HighPriority)
