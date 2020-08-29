import os, times

import nimblepkg/[version, cli]
import nimblepkg/common as nimble_common

import cliparams, download, utils, common, telemetry

when defined(windows):
  import switcher

proc buildFromCSources(params: CliParams) =
  when defined(windows):
    when hostCPU in ["i386", "arm"]:
      doCmdRaw("build.bat", liveOutput=params.debug)
    elif hostCPU in ["amd64", "arm64"]:
      doCmdRaw("build64.bat", liveOutput=params.debug)
  else:
    doCmdRaw("sh build.sh", liveOutput=params.debug)

proc buildCompiler(version: Version, params: CliParams) =
  ## Assumes that CWD contains the compiler (``build`` should have changed it).
  let binDir = getCurrentDir() / "bin"
  if fileExists(binDir / "nim".addFileExt(ExeExt)):
    if not version.isDevel() or not params.latest:
      display("Compiler:", "Already built", priority = HighPriority)
      return
  else:
    if fileExists(getCurrentDir() / "build.sh"):
      buildFromCSources(params)
    else:
      display("Warning:", "Building from latest C sources. They may not be " &
                          "compatible with the Nim version you have chosen to " &
                          "install.", Warning, HighPriority)
      let path = downloadCSources(params)
      let extractDir = getCurrentDir() / "csources"
      extract(path, extractDir)

      display("Building", "C sources", priority = HighPriority)
      setCurrentDir(extractDir) # cd csources
      buildFromCSources(params) # sh build.sh
      setCurrentDir(extractDir.parentDir()) # cd ..

  when defined(windows):
    display("Building", "koch", priority = HighPriority)
    doCmdRaw("bin/nim.exe c koch", liveOutput=params.debug)
    display("Building", "Nim", priority = HighPriority)
    doCmdRaw("koch.exe boot -d:release", liveOutput=params.debug)
  else:
    display("Building", "koch", priority = HighPriority)
    doCmdRaw("./bin/nim c koch", liveOutput=params.debug)
    display("Building", "Nim", priority = HighPriority)
    doCmdRaw("./koch boot -d:release", liveOutput=params.debug)

  if not fileExists(binDir / "nim".addFileExt(ExeExt)):
    raise newException(ChooseNimError, "Nim binary is missing. Build failed.")

proc buildTools(version: Version, params: CliParams) =
  ## Assumes that CWD contains the compiler.
  let binDir = getCurrentDir() / "bin"
  # TODO: I guess we should check for the other tools too?
  if fileExists(binDir / "nimble".addFileExt(ExeExt)):
    if not version.isDevel() or not params.latest:
      display("Tools:", "Already built", priority = HighPriority)
      return

  let msg = "tools (nimble, nimgrep, nimpretty, nimsuggest, testament)"
  display("Building", msg, priority = HighPriority)
  if fileExists(getCurrentDir() / "build.sh"):
    when defined(windows):
      doCmdRaw("bin/nim.exe c koch", liveOutput=params.debug)
      doCmdRaw("koch.exe tools -d:release", liveOutput=params.debug)
    else:
      doCmdRaw("./bin/nim c koch", liveOutput=params.debug)
      doCmdRaw("./koch tools -d:release", liveOutput=params.debug)
  else:
    when defined(windows):
      doCmdRaw("koch.exe tools -d:release", liveOutput=params.debug)
    else:
      doCmdRaw("./koch tools -d:release", liveOutput=params.debug)

# Workaround for #147
when defined(posix):
  proc setPermissions() =
    ## Assumes that CWD contains the compiler
    let binDir = getCurrentDir() / "bin"
    for kind, path in walkDir(binDir):
      if kind == pcFile:
        setFilePermissions(path,
                           {fpUserRead, fpUserWrite, fpUserExec,
                            fpGroupRead, fpGroupExec,
                            fpOthersRead, fpOthersExec}
        )
        display("Info", "Setting rwxr-xr-x permissions: " & path, Message, LowPriority)

proc build*(extractDir: string, version: Version, params: CliParams) =
  # Report telemetry.
  report(initEvent(BuildEvent), params)
  let startTime = epochTime()

  let currentDir = getCurrentDir()
  setCurrentDir(extractDir)
  # Add MingW bin dir to PATH so that `build.bat` script can find gcc.
  let pathEnv = getEnv("PATH")
  when defined(windows):
    if not isDefaultCCInPath(params) and dirExists(params.getMingwBin()):
      putEnv("PATH", params.getMingwBin() & PathSep & pathEnv)
  defer:
    setCurrentDir(currentDir)
    putEnv("PATH", pathEnv)

  display("Building", "Nim " & $version, priority = HighPriority)

  var success = false
  try:
    buildCompiler(version, params)
    buildTools(version, params)
    when defined(posix):
      setPermissions() # workaround for #147
    success = true
  except NimbleError as exc:
    # Display error and output from build separately.
    let (error, hint) = getOutputInfo(exc)
    display("Exception:", error, Error, HighPriority)
    let newError = newException(ChooseNimError, "Build failed")
    newError.hint = hint
    raise newError
  finally:
    if success:
      # Delete c_code / csources
      try:
        removeDir(extractDir / "c_code")
        removeDir(extractDir / "csources")
      except Exception as exc:
        display("Warning:", "Cleaning c_code failed: " & exc.msg, Warning)

      # Report telemetry.
      report(initEvent(BuildSuccessEvent), params)
      report(initTiming(BuildTime, $version, startTime, $LabelSuccess), params)

    if not success:
      # Perform clean up.
      display("Cleaning", "failed build", priority = HighPriority)
      # TODO: Seems I cannot use a try inside a finally?
      # Getting `no exception to reraise` on the following line.
      try:
        removeDir(extractDir)
      except Exception as exc:
        display("Warning:", "Cleaning failed: " & exc.msg, Warning)

      # Report telemetry.
      report(initEvent(BuildFailureEvent), params)
      report(initTiming(BuildTime, $version, startTime, $LabelFailure), params)
