import os, strutils, osproc, pegs

import nimblepkg/[cli, version, options]
from nimblepkg/packageinfo import getNameVersion

import cliparams, common

when defined(windows):
  import env

proc compileProxyexe() =
  var cmd = "nim c"
  when defined(release):
    cmd.add " -d:release"
  cmd.add " proxyexe"
  let (output, exitCode) = gorgeEx(cmd)
  doAssert exitCode == 0, $(output, cmd)

static: compileProxyexe()

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

proc isDefaultCCInPath*(params: CliParams): bool =
  # Fixes issue #104
  when defined(OSX):
    return findExe("clang") != ""
  else:
    return findExe("gcc") != ""

proc needsCCInstall*(params: CliParams): bool =
  ## Determines whether the system needs a C compiler to be installed.
  let inPath = isDefaultCCInPath(params)
  let inMingwDir =
    when defined(windows):
      fileExists(params.getMingwBin() / "gcc".addFileExt(ExeExt))
    else: false
  let isInstalled = inPath or inMingwDir
  return not isInstalled

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

when defined(windows):
  # From finish.nim in nim-lang/Nim/tools
  import registry

  proc tryGetUnicodeValue(path, key: string, handle: HKEY): string =
    # Get a unicode value from the registry or ""
    try:
      result = getUnicodeValue(path, key, handle)
    except:
      result = ""

  proc addToPathEnv(e: string) =
    # Append e to user PATH to registry
    var p = tryGetUnicodeValue(r"Environment", "Path", HKEY_CURRENT_USER)
    let x = if e.contains(Whitespace): "\"" & e & "\"" else: e
    if p.len > 0:
      if p[^1] != PathSep:
        p.add PathSep
      p.add x
    else:
      p = x
    setUnicodeValue(r"Environment", "Path", p, HKEY_CURRENT_USER)

  proc setNimbleBinPath*(params: CliParams) =
    # Ask the user and add nimble bin to PATH
    let nimbleDesiredPath = params.getBinDir()
    if prompt(params.nimbleOptions.forcePrompts,
              nimbleDesiredPath & " is not in your PATH environment variable.\n" &
              "            Should it be added permanently?"):
      addToPathEnv(nimbleDesiredPath)
      display("NOTE:", "PATH changes will only take effect in new sessions.",
              priority = HighPriority)

proc isNimbleBinInPath*(params: CliParams): bool =
  # This proc searches the $PATH variable for the nimble bin directory,
  # typically ~/.nimble/bin
  result = false
  let nimbleDesiredPath = params.getBinDir()
  when defined(windows):
    let p = tryGetUnicodeValue(r"Environment", "Path",
      HKEY_CURRENT_USER) & PathSep & tryGetUnicodeValue(
      r"System\CurrentControlSet\Control\Session Manager\Environment", "Path",
      HKEY_LOCAL_MACHINE)
  else:
    let p = getEnv("PATH")
  for x in p.split(PathSep):
    if x.len == 0: continue
    let y =
      try:
        expandFilename(
          if x[0] == '"' and x[^1] == '"':
            substr(x, 1, x.len-2)
          else: x
        )
      except OSError as e:
        if e.errorCode == 0: x
        else: ""
      except: ""
    if y.cmpIgnoreCase(nimbleDesiredPath) == 0:
      result = true
      break

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

  try:
    writeFile(proxyPath, proxyExe)
  except IOError:
<<<<<<< HEAD
    display("Warning:", "component '$1' possibly in use, write failed" % bin, Warning,
=======
    display("Warning:", "component '$1' in use, write failed" % bin, Warning,
>>>>>>> Fix #28 - add ~/.nimble/bin to PATH on Windows
            priority = HighPriority)
    return

  # Make sure the exe has +x flag.
  setFilePermissions(proxyPath,
                     getFilePermissions(proxyPath) + {fpUserExec})
  display("Installed", "component '$1'" % bin, priority = HighPriority)

  # Check whether this is in the user's PATH.
  let fromPATH = findExe(bin)
  if fromPATH == "" and not params.firstInstall:
    let msg =
      when defined(windows):
        "Binary '$1' isn't in your PATH" % bin
      else:
<<<<<<< HEAD
        "Binary '$1' isn't in your PATH. Ensure that '$2' is in your PATH." %
=======
        "Binary '$1' isn't in your PATH. Add '$2' to your PATH." %
>>>>>>> Fix #28 - add ~/.nimble/bin to PATH on Windows
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
  let proxiesInstalled = params.areProxiesInstalled(proxies)
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