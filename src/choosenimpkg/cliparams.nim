import parseopt2, strutils

import common

type
  CliParams = ref object
    version*: string

let doc = """
choosenim: The Nim toolchain installer.

Choose a job. Choose a mortgage. Choose life. Choose Nim.

Usage:
  choosenim <version>

Options:
  -h --help     Show this screen.
  --version     Show version.
"""

proc writeHelp() =
  echo(doc)
  quit(QuitFailure)

proc writeVersion() =
  echo("choosenim v$1 ($2 $3)" % [chooseNimVersion, CompileDate, CompileTime])
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
      else: discard
    of cmdEnd: assert(false)

  if result.version == "":
    writeHelp()