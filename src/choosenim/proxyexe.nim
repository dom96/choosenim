# This file is embedded in the `choosenim` executable and is written to
# ~/.nimble/bin/. It emulates a portable symlink with some nice additional
# features.

import strutils, os, osproc

import nimblepkg/cli
import nimblepkg/common as nimbleCommon
import cliparams
from common import ChooseNimError, mingwProxies

proc getSelectedPath(params: CliParams): string =
  var path = ""
  try:
    path = params.getCurrentFile()
    if not fileExists(path):
      let msg = "No installation has been chosen. (File missing: $1)" % path
      raise newException(ChooseNimError, msg)

    result = readFile(path)
  except Exception as exc:
    let msg = "Unable to read $1. (Error was: $2)" % [path, exc.msg]
    raise newException(ChooseNimError, msg)

proc getExePath(params: CliParams): string
  {.raises: [ChooseNimError, ValueError].} =
  try:
    let exeName = getAppFilename().extractFilename
    if exeName.splitFile.name in mingwProxies and defined(windows):
      return getMingwBin(params) / exeName
    else:
      return getSelectedPath(params) / "bin" / exeName
  except Exception as exc:
    let msg = "getAppFilename failed. (Error was: $1)" % exc.msg
    raise newException(ChooseNimError, msg)

proc main(params: CliParams) {.raises: [ChooseNimError, ValueError].} =
  let exePath = getExePath(params)
  if not fileExists(exePath):
    raise newException(ChooseNimError,
        "Requested executable is missing. (Path: $1)" % exePath)

  try:
    # Launch the desired process.
    let p = startProcess(exePath, args=commandLineParams(),
                         options={poParentStreams})
    let exitCode = p.waitForExit()
    p.close()
    quit(exitCode)
  except Exception as exc:
    raise newException(ChooseNimError,
        "Spawning of process failed. (Error was: $1)" % exc.msg)

when isMainModule:
  var error = ""
  var hint = ""
  try:
    let params = getCliParams(proxyExeMode = true)
    main(params)
  except NimbleError as exc:
    (error, hint) = getOutputInfo(exc)

  if error.len > 0:
    displayTip()
    display("Error:", error, Error, HighPriority)
    if hint.len > 0:
      display("Hint:", hint, Warning, HighPriority)

    display("Info:", "If unexpected, please report this error to " &
            "https://github.com/dom96/choosenim", Warning, HighPriority)
    quit(1)