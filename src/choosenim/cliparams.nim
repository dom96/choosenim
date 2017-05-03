import parseopt2, strutils, os

import nimblepkg/[cli, options, config]
import nimblepkg/common as nimble_common

import common

type
  CliParams* = ref object
    command*: string
    choosenimDir*: string
    nimbleOptions*: Options

let doc = """
choosenim: The Nim toolchain installer.

Choose a job. Choose a mortgage. Choose life. Choose Nim.

Usage:
  choosenim <version/path>

Example:
  choosenim 0.16.0
    Installs (if necessary) and selects version 0.16.0 of Nim.
  choosenim #head
    Installs (if necessary) and selects the latest current commit of Nim.
    Warning: Your shell may need quotes around `#head`: choosenim "#head".
  choosenim ~/projects/nim
    Selects the specified Nim installation.

Options:
  -h --help             Show this output.
  --version             Show version.
  --verbose             Show low (and higher) priority output.
  --debug               Show debug (and higher) priority output.
  --noColor             Don't colorise output.

  --choosenimDir:<dir>  Specify the directory where toolchains should be
                        installed. Default: ~/.choosenim.
  --nimbleDir:<dir>     Specify the Nimble directory where binaries will be
                        placed. Default: ~/.nimble.
"""

proc writeHelp() =
  echo(doc)
  quit(QuitFailure)

proc writeVersion() =
  echo("choosenim v$1 ($2 $3) [$4/$5]" %
       [chooseNimVersion, CompileDate, CompileTime, hostOS, hostCPU])
  quit(QuitSuccess)

proc newCliParams(): CliParams =
  new result
  result.command = ""
  result.choosenimDir = getHomeDir() / ".choosenim"
  # Init nimble params.
  try:
    result.nimbleOptions = initOptions()
    result.nimbleOptions.config = parseConfig()
  except NimbleQuit:
    discard

proc getCliParams*(proxyExeMode = false): CliParams =
  result = newCliParams()

  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      result.command = key
    of cmdLongOption, cmdShortOption:
      let normalised = key.normalize()
      # Don't want the proxyExe to return choosenim's help/version.
      case normalised
      of "help", "h":
        if not proxyExeMode: writeHelp()
      of "version", "v":
        if not proxyExeMode: writeVersion()
      of "verbose": setVerbosity(LowPriority)
      of "debug": setVerbosity(DebugPriority)
      of "nocolor": setShowColor(false)
      of "choosenimdir": result.choosenimDir = val
      of "nimbledir": result.nimbleOptions.nimbleDir = val
      else:
        if not proxyExeMode:
          raise newException(ChooseNimError, "Unknown flag: --" & key)
    of cmdEnd: assert(false)

  if result.command == "" and not proxyExeMode:
    writeHelp()

proc getDownloadDir*(params: CliParams): string =
  return params.chooseNimDir / "downloads"

proc getInstallDir*(params: CliParams): string =
  return params.chooseNimDir / "toolchains"

proc getChannelsDir*(params: CliParams): string =
  return params.chooseNimDir / "channels"

proc getBinDir*(params: CliParams): string =
  return params.nimbleOptions.getBinDir()

proc getCurrentFile*(params: CliParams): string =
  ## Returns the path to the file which specifies the currently selected
  ## installation. The contents of this file is a path to the selected Nim
  ## directory.
  return params.chooseNimDir / "current"

proc getMingwPath*(params: CliParams): string =
  return params.getInstallDir() / "mingw32"

proc getMingwBin*(params: CliParams): string =
  return getMingwPath(params) / "bin"