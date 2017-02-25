import os

import nimblepkg/[version, cli, tools]

import options

proc buildCompiler() =
  ## Assumes that CWD contains the compiler (``build`` should have changed it).
  let binDir = getCurrentDir() / "bin"
  if fileExists(binDir / "nim".addFileExt(ExeExt)):
    display("Compiler: ", "Already built", priority = HighPriority)
    return

  if fileExists(getCurrentDir() / "build.sh"):
    when defined(windows):
      doCmd("build.bat")
      # TODO: How should we handle x86 vs amd64?
    else:
      doCmd("sh build.sh")
  else:
    discard
    # TODO: Build from GitHub

proc buildTools() =
  ## Assumes that CWD contains the compiler.
  let binDir = getCurrentDir() / "bin"
  # TODO: I guess we should check for the other tools too?
  if fileExists(binDir / "nimble".addFileExt(ExeExt)):
    display("Tools: ", "Already built", priority = HighPriority)
    return

  if fileExists(getCurrentDir() / "build.sh"):
    when defined(windows):
      doCmd("bin/nim c koch")
      doCmd("koch tools")
    else:
      doCmd("./bin/nim c koch")
      doCmd("./koch tools")

proc build*(extractDir: string, version: Version) =
  let currentDir = getCurrentDir()
  setCurrentDir(extractDir)
  defer:
    setCurrentDir(currentDir)

  display("Building", "Nim v" & $version, priority = HighPriority)
  buildCompiler()
  buildTools()


