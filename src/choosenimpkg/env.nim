import os, strutils

import nimblepkg/[cli, options]

import cliparams

when defined(windows):
  # From finish.nim in nim-lang/Nim/tools
  import registry

  proc tryGetUnicodeValue(path, key: string, handle: HKEY): string =
    # Get a unicode value from the registry or ""
    try:
      result = getUnicodeValue(path, key, handle)
    except:
      result = ""

  proc addToPathEnv(path: string) =
    # Append path to user PATH to registry
    var paths = tryGetUnicodeValue(r"Environment", "Path", HKEY_CURRENT_USER)
    let path = if path.contains(Whitespace): "\"" & path & "\"" else: path
    if paths.len > 0:
      if paths[^1] != PathSep:
        paths.add PathSep
      paths.add path
    else:
      paths = path
    setUnicodeValue(r"Environment", "Path", paths, HKEY_CURRENT_USER)

  proc setNimbleBinPath*(params: CliParams) =
    # Ask the user and add nimble bin to PATH
    let nimbleDesiredPath = params.getBinDir()
    if prompt(params.nimbleOptions.forcePrompts,
              nimbleDesiredPath & " is not in your PATH environment variable.\n" &
              "            Should it be added permanently?"):
      addToPathEnv(nimbleDesiredPath)
      display("Note:", "PATH changes will only take effect in new sessions.",
              priority = HighPriority)
  
  proc isNimbleBinInPath*(params: CliParams): bool =
    # This proc searches the $PATH variable for the nimble bin directory,
    # typically ~/.nimble/bin
    result = false
    let nimbleDesiredPath = params.getBinDir()
    when defined(windows):
      # Getting PATH from registry since it is the ultimate source of
      # truth and session local $PATH can be changed.
      let paths = tryGetUnicodeValue(r"Environment", "Path",
        HKEY_CURRENT_USER) & PathSep & tryGetUnicodeValue(
        r"System\CurrentControlSet\Control\Session Manager\Environment", "Path",
        HKEY_LOCAL_MACHINE)
    else:
      let paths = getEnv("PATH")
    for path in paths.split(PathSep):
      if path.len == 0: continue
      let path = path.strip(chars = {'"'})
      let expandedPath =
        try:
          expandFilename(path)
        except:
          ""
      if expandedPath.cmpIgnoreCase(nimbleDesiredPath) == 0:
        result = true
        break