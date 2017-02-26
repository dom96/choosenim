import parseopt2, strutils

import nimblepkg/cli

import common

type
  CliParams = ref object
    version*: string

let doc = """
choosenim: The Nim toolchain installer.

Choose a job. Choose a mortgage. Choose life. Choose Nim.

Usage:
  choosenim <version>

Example:
  choosenim 0.16.0
    Installs (if necessary) and selects version 0.16.0 of Nim.
  choosenim #head
    Installs (if necessary) and selects the latest current commit of Nim.
    Warning: Your shell may need quotes around `#head`: choosenim "#head".

Options:
  -h --help     Show this screen.
  --version     Show version.
  --verbose     Show low (and higher) priority output.
  --debug       Show debug (and higher) priority output.
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
  result.version = ""

proc getCliParams*(): CliParams =
  result = newCliParams()
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      result.version = key
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h": writeHelp()
      of "version", "v": writeVersion()
      of "verbose": setVerbosity(LowPriority)
      of "debug": setVerbosity(DebugPriority)
      else: discard
    of cmdEnd: assert(false)

  if result.version == "":
    writeHelp()