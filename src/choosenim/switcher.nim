import os, strutils, osproc, pegs

import nimblepkg/[cli, version, options]

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

proc getSelectedPath*(params: CliParams): string =
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

proc isCCInPath(params: CliParams): bool =
  return findExe("gcc") != "" or findExe("clang") != ""

proc needsCCInstall*(params: CliParams): bool =
  ## Determines whether the system needs a C compiler to be installed.
  let inPath = isCCInPath(params)
  let inMingwDir = fileExists(params.getMingwBin() / "gcc".addFileExt(ExeExt))
  let isInstalled = inPath or inMingwDir
  return not isInstalled

proc needsDLLInstall*(params: CliParams): bool =
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

proc getNimbleVersion(toolchainPath: string): Version =
  result = newVersion("0.8.6") # We assume that everything is fine.
  let command = toolchainPath / "bin" / "nimble".addFileExt(ExeExt)
  let (output, _) = execCmdEx(command & " -v")
  var matches: array[0 .. MaxSubpatterns, string]
  if output.find(peg"'nimble v'{(\d+\.)+\d}", matches) != -1:
    result = newVersion(matches[0])
  else:
    display("Warning:", "Could not find toolchain's Nimble version.",
            Warning, MediumPriority)

proc writeProxy(bin: string, params: CliParams) =
  # Create the ~/.nimble/bin dir in case it doesn't exist.
  createDir(params.getBinDir())

  let proxyPath = params.getProxyPath(bin)

  if bin == "nimble":
    # Check for "lib" dir in ~/.nimble. Issue #13.
    let dir = params.nimbleOptions.getNimbleDir() / "lib"
    if dirExists(dir):
      let msg = ("Nimble will fail because '$1' exists. Would you like me " &
                 "to remove it?") % dir
      if prompt(dontForcePrompt, msg):
        removeDir(dir)
        display("Removed", dir, priority = HighPriority)

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
  # If the binary does not exists in the binary directory, and the option
  # firstInstall is not set, display an hint to indicate the solution.
  if fromPATH == "" and not params.firstInstall:
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

  # Check Nimble version to give a warning when it's too old.
  let nimbleVersion = getNimbleVersion(filepath)
  if nimbleVersion < newVersion("0.8.6"):
    display("Warning:", ("Nimble v$1 is not supported by choosenim, using it " &
                         "will yield errors.") % $nimbleVersion,
            Warning, HighPriority)
    display("Hint:", "Installing Nim from GitHub will ensure that a working " &
                     "version of Nimble is installed. You can do so by " &
                     "running `choosenim \"#v0.16.0\"` or similar.",
            Warning, HighPriority)

  var proxiesToInstall = @proxies
  # Handle MingW proxies.
  when defined(windows):
    if not isCCInPath(params):
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
  let filepath = expandFilename(filepath)
  if switchToPath(filepath, params):
    display("Switched", "to Nim ($1)" % filepath, Success, HighPriority)
  else:
    display("Info:", "Path '$1' already selected" % filepath,
            priority = HighPriority)
