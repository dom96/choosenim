import os, strutils, osproc, pegs

import nimblepkg/[cli, version, options]
from nimblepkg/packageinfo import getNameVersion

import cliparams, common, utils

when defined(windows):
  import env

proc compileProxyexe(additionalMacOSFlag: string = "", proxyName = "proxyexe") =
  var cmd =
    when defined(windows):
      "cmd /C \"cd ../../ && nimble c"
    elif defined(macosx):
      "cd ../../ && nimble c " & additionalMacOSFlag 
    else:
      "cd ../../ && nimble c"

  cmd.add " --out:src/choosenimpkg/" & proxyName

  when defined(release):
    cmd.add " -d:release"
  when defined(staticBuild):
    cmd.add " -d:staticBuild"
  cmd.add " src/choosenimpkg/proxyexe"
  when defined(windows):
    cmd.add("\"")
  let (output, exitCode) = gorgeEx(cmd)
  doAssert exitCode == 0, $(output, cmd)

proc isMacOSBelowBigSurCompileTime(): bool =
  const (versionOutput, _) = gorgeEx("sw_vers -productVersion")
  const currentVersion = versionOutput.split(".")

  if currentVersion.len() < 1: return false # version should be at least 11, like this
  let twoVersion = parseFloat(
    if currentVersion.len() == 1:
      currentVersion[0].strip()
    else: currentVersion[0..1].join(".").strip())

  return twoVersion < 11

proc isMacOSBelowBigSur(): bool =
  let (versionOutput, _) = execCmdEx("sw_vers -productVersion")
  let currentVersion = versionOutput.split(".")

  if currentVersion.len() < 1:
    return false # version should be at least 11 like this
  let twoVersion = parseFloat(
    if currentVersion.len() == 1:
      currentVersion[0].strip()
    else: currentVersion[0..1].join(".").strip())

  return twoVersion < 11

proc isAppleSilicon(): bool =
  let (output, exitCode) = execCmdEx("uname -m")  # arch -x86_64 uname -m returns x86_64 on M1 🥲
  assert exitCode == 0, output
  return output == "arm64" or isRosetta()

static:
  when defined(macosx):
    compileProxyexe("--cpu:amd64 --passC:'-arch x86_64' --passL:'-arch x86_64'", "proxyexe-amd64")
    # if CI or building machine is below macOS Big Sur, don't compile cross-compile arm64 proxyexe
    when not isMacOSBelowBigSurCompileTime():
      compileProxyexe("--cpu:arm64 --passC:'-arch arm64' --passL:'-arch arm64'", "proxyexe-arm64")
  else:
    compileProxyexe()

when defined(macosx):
  when not isMacOSBelowBigSurCompileTime():
    const embeddedProxyExeArm: string = staticRead("proxyexe-arm64".addFileExt(ExeExt))
  const embeddedProxyExe = staticRead("proxyexe-amd64".addFileExt(ExeExt))
else:
  const embeddedproxyExe: string = staticRead("proxyexe".addFileExt(ExeExt))

proc proxyToUse(): string =
  result = embeddedProxyExe
  when defined(macosx):
    if not isMacOSBelowBigSur():
      when declared(embeddedProxyExeArm):
        result = (if isAppleSilicon(): embeddedProxyExeArm else: embeddedProxyExe)
      else:
        # result is already embeddedProxyExe
        {.warning: "Since choosenim is compiled on macOS that doesn't support arm64, choosenim proxies won't be able to produce arm64 result.".}

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
  let proxyExe = proxyToUse()
  for proxy in proxies:
    # Verify that proxy exists.
    let path = params.getProxyPath(proxy)
    if not fileExists(path):
      return false

    # Verify that proxy binary is up-to-date.
    let contents = readFile(path)
    if contents != proxyExe:
      return false

proc isDefaultCCInPath*(params: CliParams): bool =
  # Fixes issue #104
  when defined(macosx):
    return findExe("clang") != ""
  else:
    return findExe("gcc") != ""

proc needsCCInstall*(params: CliParams): bool =
  ## Determines whether the system needs a C compiler to be installed.
  let inPath = isDefaultCCInPath(params)

  when defined(windows):
    let inMingwDir =
      when defined(windows):
        fileExists(params.getMingwBin() / "gcc".addFileExt(ExeExt))
      else: false

    # Check whether the `gcc` we have in PATH is actually choosenim's proxy exe.
    # If so and toolchain mingw dir doesn't exit then we need to install.
    if inPath and findExe("gcc") == params.getProxyPath("gcc"):
      return not inMingwDir

  return not inPath

proc needsDLLInstall*(params: CliParams): bool =
  ## Determines whether DLLs need to be installed (Windows-only).
  ##
  ## TODO: In the future we can probably extend this and let the user
  ## know what DLLs they are missing on all operating systems.
  proc isInstalled(params: CliParams, name: string): bool =
    let
      inPath = findExe(name, extensions=["dll"]) != ""
      inNimbleBin = fileExists(params.getBinDir() / name & ".dll")

    return inPath or inNimbleBin

  for dll in ["libeay", "pcre", "pdcurses", "sqlite3_", "ssleay"]:
    for bit in ["32", "64"]:
      result = not isInstalled(params, dll & bit)
      if result: return

proc getNimbleVersion(toolchainPath: string): Version =
  result = newVersion("0.8.6") # We assume that everything is fine.
  let command = toolchainPath / "bin" / "nimble".addFileExt(ExeExt)
  let (output, _) = execCmdEx(command & " -v")
  var matches: array[0 .. MaxSubpatterns, string]
  if output.find(peg"'nimble v'{(\d+\.)+\d+}", matches) != -1:
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

  let proxyExe = proxyToUse()
  # Don't write the file again if it already exists.
  if fileExists(proxyPath) and readFile(proxyPath) == proxyExe: return

  try:
    writeFile(proxyPath, proxyExe)
  except IOError:
    display("Warning:", "component '$1' possibly in use, write failed" % bin, Warning,
            priority = HighPriority)
    return

  # Make sure the exe has +x flag.
  setFilePermissions(proxyPath,
                     getFilePermissions(proxyPath) + {fpUserExec})
  display("Installed", "component '$1'" % bin, priority = HighPriority)

  # Check whether this is in the user's PATH.
  let fromPATH = findExe(bin)
  display("Debug:", "Proxy path: " & proxyPath, priority = DebugPriority)
  display("Debug:", "findExe: " & fromPATH, priority = DebugPriority)
  if fromPATH == "" and not params.firstInstall:
    let msg =
      when defined(windows):
        "Binary '$1' isn't in your PATH" % bin
      else:
        "Binary '$1' isn't in your PATH. Ensure that '$2' is in your PATH." %
          [bin, params.getBinDir()]
    display("Hint:", msg, Warning, HighPriority)
  elif fromPATH != "" and fromPATH != proxyPath:
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
    if not isDefaultCCInPath(params):
      let mingwBin = getMingwBin(params)
      if not fileExists(mingwBin / "gcc".addFileExt(ExeExt)):
        let msg = "No 'gcc' binary found in '$1'." % mingwBin
        raise newException(ChooseNimError, msg)

      proxiesToInstall.add(mingwProxies)

  # Return early if this version is already selected.
  let selectedPath = params.getSelectedPath()
  let proxiesInstalled = params.areProxiesInstalled(proxiesToInstall)
  if selectedPath == filepath and proxiesInstalled:
    return false
  else:
    # Write selected path to "current file".
    writeFile(params.getCurrentFile(), filepath)

  # Create the proxy executables.
  for proxy in proxiesToInstall:
    writeProxy(proxy, params)

  when defined(windows):
    if not isNimbleBinInPath(params):
      display("Hint:", "Use 'choosenim <version/channel> --firstInstall' to add\n" &
                  "$1 to your PATH." % params.getBinDir(), Warning, HighPriority)

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

proc getSelectedVersion*(params: CliParams): Version =
  let path = getSelectedPath(params)
  let (_, version) = getNameVersion(path)
  return version.newVersion
