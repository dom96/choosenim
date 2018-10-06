import parseopt2, strutils, os

import nimblepkg/[cli, options, config]
import nimblepkg/common as nimble_common
import analytics

import common

type
  CliParams* = ref object
    commands*: seq[string]
    choosenimDir*: string
    firstInstall*: bool
    forceUpdate*: bool
    nimbleOptions*: Options
    analytics*: AsyncAnalytics
    pendingReports*: int ## Count of pending telemetry reports.


let doc = """
choosenim: The Nim toolchain installer.

Choose a job. Choose a mortgage. Choose life. Choose Nim.

Usage:
  choosenim <version/path/channel>

Example:
  choosenim 0.16.0
    Installs (if necessary) and selects version 0.16.0 of Nim.
  choosenim stable
    Installs (if necessary) Nim from the stable channel (latest stable release)
    and then selects it.
  choosenim #head
    Installs (if necessary) and selects the latest current commit of Nim.
    Warning: Your shell may need quotes around `#head`: choosenim "#head".
  choosenim ~/projects/nim
    Selects the specified Nim installation.
  choosenim update stable
    Updates the version installed on the stable release channel.

Channels:
  stable
    Describes the latest stable release of Nim.
  devel
    Describes the latest development (or nightly) release of Nim taken from
    the devel branch.

Commands:
  update    <version/channel>    Installs the latest release of the specified
                                 version or channel.
  show                           Displays the selected version and channel.
  update    self                 Updates choosenim itself.

Options:
  -h --help             Show this output.
  -y --yes              Agree to every question.
  --version             Show version.
  --verbose             Show low (and higher) priority output.
  --debug               Show debug (and higher) priority output.
  --noColor             Don't colorise output.
  --force               Delete and re-create chosen version/channel.

  --choosenimDir:<dir>  Specify the directory where toolchains should be
                        installed. Default: ~/.choosenim.
  --nimbleDir:<dir>     Specify the Nimble directory where binaries will be
                        placed. Default: ~/.nimble.
  --firstInstall        Used by install script.
"""

proc command*(params: CliParams): string =
  return params.commands[0]

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

proc getCurrentChannelFile*(params: CliParams): string =
  return params.chooseNimDir / "current-channel"

proc getAnalyticsFile*(params: CliParams): string =
  return params.chooseNimDir / "analytics"

proc getMingwPath*(params: CliParams): string =
  return params.getInstallDir() / "mingw32"

proc getMingwBin*(params: CliParams): string =
  return getMingwPath(params) / "bin"

proc getArchiveFormat*(): string =
  when defined(linux):
    return ".xz"
  else:
    return ".gz"

proc getDownloadPath*(params: CliParams, downloadUrl: string): string =
  let (_, name, ext) = downloadUrl.splitFile()
  return params.getDownloadDir() / name & ext

proc writeHelp() =
  echo(doc)
  quit(QuitFailure)

proc writeVersion() =
  echo("choosenim v$1 ($2 $3) [$4/$5]" %
       [chooseNimVersion, CompileDate, CompileTime, hostOS, hostCPU])
  quit(QuitSuccess)

proc writeNimbleBinDir(params: CliParams) =
  # Special option for scripts that install choosenim.
  echo(params.getBinDir())
  quit(QuitSuccess)

proc newCliParams*(proxyExeMode: bool): CliParams =
  new result
  result.commands = @[]
  result.choosenimDir = getHomeDir() / ".choosenim"
  # Init nimble params.
  try:
    result.nimbleOptions = initOptions()
    if not proxyExeMode:
      result.nimbleOptions.config = parseConfig()
  except NimbleQuit:
    discard

proc parseCliParams*(params: var CliParams, proxyExeMode = false) =
  params = newCliParams(proxyExeMode)

  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      params.commands.add(key)
    of cmdLongOption, cmdShortOption:
      let normalised = key.normalize()
      # Don't want the proxyExe to return choosenim's help/version.
      case normalised
      of "help", "h":
        if not proxyExeMode: writeHelp()
      of "version", "v":
        if not proxyExeMode: writeVersion()
      of "getnimblebin":
        # Used by installer scripts to know where the choosenim executable
        # should be copied.
        if not proxyExeMode: writeNimbleBinDir(params)
      of "verbose": setVerbosity(LowPriority)
      of "debug": setVerbosity(DebugPriority)
      of "nocolor": setShowColor(false)
      of "force": params.forceUpdate = true
      of "choosenimdir": params.choosenimDir = val
      of "nimbledir": params.nimbleOptions.nimbleDir = val
      of "firstinstall": params.firstInstall = true
      of "y", "yes": params.nimbleOptions.forcePrompts = forcePromptYes
      else:
        if not proxyExeMode:
          raise newException(ChooseNimError, "Unknown flag: --" & key)
    of cmdEnd: assert(false)

  if params.commands.len == 0 and not proxyExeMode:
    writeHelp()
