import os, strutils, osproc

import nimblepkg/[version, cli, tools]
import nimblepkg/common as nimble_common

import cliparams, download, utils, common

proc doCmdRaw(cmd: string) =
  # To keep output in sequence
  stdout.flushFile()
  stderr.flushFile()

  displayDebug("Executing", cmd)
  let (output, exitCode) = execCmdEx(cmd)
  displayDebug("Finished", "with exit code " & $exitCode)
  displayDebug("Output", output)

  if exitCode != QuitSuccess:
    raise newException(ChooseNimError,
        "Execution failed with exit code $1\nCommand: $2\nOutput: $3" %
        [$exitCode, cmd, output])

proc buildFromCSources() =
  when defined(windows):
    doCmdRaw("build.bat")
    # TODO: How should we handle x86 vs amd64?
  else:
    doCmdRaw("sh build.sh")

proc buildCompiler(params: CliParams) =
  ## Assumes that CWD contains the compiler (``build`` should have changed it).
  let binDir = getCurrentDir() / "bin"
  if fileExists(binDir / "nim".addFileExt(ExeExt)):
    display("Compiler: ", "Already built", priority = HighPriority)
    return

  if fileExists(getCurrentDir() / "build.sh"):
    buildFromCSources()
  else:
    display("Warning:", "Building from latest C sources. They may not be " &
                        "compatible with the Nim version you have chosen to " &
                        "install.", Warning, HighPriority)
    let path = downloadCSources(params)
    let extractDir = getCurrentDir() / "csources"
    extract(path, extractDir)

    display("Building", "C sources", priority = HighPriority)
    setCurrentDir(extractDir) # cd csources
    buildFromCSources() # sh build.sh
    setCurrentDir(extractDir.parentDir()) # cd ..
    when defined(windows):
      display("Building", "koch", priority = HighPriority)
      doCmdRaw("bin/nim.exe c koch")
      display("Building", "Nim", priority = HighPriority)
      doCmdRaw("koch.exe boot -d:release")
    else:
      display("Building", "koch", priority = HighPriority)
      doCmdRaw("./bin/nim c koch")
      display("Building", "Nim", priority = HighPriority)
      doCmdRaw("./koch boot -d:release")

proc buildTools() =
  ## Assumes that CWD contains the compiler.
  let binDir = getCurrentDir() / "bin"
  # TODO: I guess we should check for the other tools too?
  if fileExists(binDir / "nimble".addFileExt(ExeExt)):
    display("Tools: ", "Already built", priority = HighPriority)
    return

  let msg = "tools (nimble, nimgrep, nimsuggest)"
  display("Building", msg, priority = HighPriority)
  if fileExists(getCurrentDir() / "build.sh"):
    when defined(windows):
      doCmdRaw("bin/nim.exe c koch")
      doCmdRaw("koch.exe tools -d:release")
    else:
      doCmdRaw("./bin/nim c koch")
      doCmdRaw("./koch tools -d:release")
  else:
    when defined(windows):
      doCmdRaw("koch.exe tools -d:release")
    else:
      doCmdRaw("./koch tools -d:release")

proc build*(extractDir: string, version: Version, params: CliParams) =
  let currentDir = getCurrentDir()
  setCurrentDir(extractDir)
  defer:
    setCurrentDir(currentDir)

  display("Building", "Nim " & $version, priority = HighPriority)

  var success = false
  try:
    buildCompiler(params)
    buildTools()
    success = true
  except NimbleError as exc:
    # Display error and output from build separately.
    let (error, hint) = getOutputInfo(exc)
    display("Exception:", error, Error, HighPriority)
    let newError = newException(ChooseNimError, "Build failed")
    newError.hint = hint
    raise newError
  finally:
    if not success:
      # Perform clean up.
      display("Cleaning", "failed build", priority = HighPriority)
      removeDir(extractDir)

