import os, strutils

import nimblepkg/[version, cli, tools]

import options, download, utils

proc buildFromCSources() =
  when defined(windows):
    doCmd("build.bat")
    # TODO: How should we handle x86 vs amd64?
  else:
    doCmd("sh build.sh")

proc buildCompiler() =
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
    let path = downloadCSources()
    let extractDir = getCurrentDir() / "csources"
    extract(path, extractDir)

    display("Building", "C sources", priority = HighPriority)
    setCurrentDir(extractDir) # cd csources
    buildFromCSources() # sh build.sh
    setCurrentDir(extractDir.parentDir()) # cd ..
    when defined(windows):
      display("Building", "koch", priority = HighPriority)
      doCmd("bin/nim.exe c koch")
      display("Building", "Nim", priority = HighPriority)
      doCmd("koch.exe boot -d:release")
    else:
      display("Building", "koch", priority = HighPriority)
      doCmd("./bin/nim c koch")
      display("Building", "Nim", priority = HighPriority)
      doCmd("./koch boot -d:release")

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

  display("Building", "Nim " & $version, priority = HighPriority)
  buildCompiler()
  buildTools()


