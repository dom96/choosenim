# This file is embedded in the `choosenim` executable and is written to
# ~/.nimble/bin/. It emulates a portable symlink with some nice additional
# features.

import strutils, os, osproc

import nimblepkg/cli
import nimblepkg/common as nimbleCommon
import options
from common import PicknimError

proc getExePath(): string {.raises: [PicknimError, ValueError].} =
  # TODO: This code is disgusting. I wanted to make it as safe/informative as
  # possible but all these try statements are horrible.

  var path = ""
  try:
    path = getCurrentFile()
    if not fileExists(path):
      let msg = "No installation has been chosen. (File missing: $1)" % path
      raise newException(PicknimError, msg)

    result = readFile(path)
  except PicknimError:
    raise
  except Exception as exc:
    let msg = "Unable to read $1. (Error was: $2)" % [path, exc.msg]
    raise newException(PicknimError, msg)

  try:
    let exeName = getAppFilename().extractFilename
    return result / "bin" / exeName
  except Exception as exc:
    let msg = "getAppFilename failed. (Error was: $1)" % exc.msg
    raise newException(PicknimError, msg)

proc main() {.raises: [PicknimError, ValueError].} =
  let exePath = getExePath()
  if not fileExists(exePath):
    raise newException(PicknimError,
        "Requested executable is missing. (Path: $1)" % exePath)

  try:
    # Launch the desired process.
    let p = startProcess(exePath, args=commandLineParams(),
                         options={poParentStreams})
    discard p.waitForExit()
    p.close()
  except Exception as exc:
    raise newException(PicknimError,
        "Spawning of process failed. (Error was: $1)" % exc.msg)

when isMainModule:
  var error = ""
  var hint = ""
  try:
    main()
  except NimbleError as exc:
    (error, hint) = getOutputInfo(exc)

  if error.len > 0:
    displayTip()
    display("Error:", error, Error, HighPriority)
    if hint.len > 0:
      display("Hint:", hint, Warning, HighPriority)

    display("Info:", "Please report this error to " &
            "https://github.com/dom96/choosenim", Warning, HighPriority)
    quit(1)