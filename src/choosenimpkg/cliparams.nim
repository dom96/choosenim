import parseopt, strutils, os

when not defined(windows):
  import osproc

import nimblepkg/[cli, options, config]
import nimblepkg/common as nimble_common
import analytics

import common

type
  CliParams* = ref object
    commands*: seq[string]
    onlyInstalled*: bool
    choosenimDir*: string
    firstInstall*: bool
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
  choosenim versions [--installed]
    Lists the available versions of Nim that choosenim has access to.

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
  versions  [--installed]        Lists available versions of Nim, passing
                                 `--installed` only displays versions that
                                 are installed locally (no network requests).

Options:
  -h --help             Show this output.
  -y --yes              Agree to every question.
  --version             Show version.
  --verbose             Show low (and higher) priority output.
  --debug               Show debug (and higher) priority output.
  --noColor             Don't colorise output.

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

var cpuArch = 0

proc getCpuArch*(): int =
  ## Get CPU arch on Windows - get env var PROCESSOR_ARCHITECTURE
  if cpuArch != 0:
    return cpuArch

  var failMsg = ""

  let
    archEnv = getEnv("PROCESSOR_ARCHITECTURE")
    arch6432Env = getEnv("PROCESSOR_ARCHITEW6432")
  if arch6432Env.len != 0:
    # https://blog.differentpla.net/blog/2013/03/10/processor-architew6432/
    result = 64
  elif "64" in archEnv:
    # https://superuser.com/a/1441469
    result = 64
  elif "86" in archEnv:
    result = 32
  else:
    failMsg = "PROCESSOR_ARCHITECTURE = " & archEnv &
              ", PROCESSOR_ARCHITEW6432 = " & arch6432Env

  # Die if unsupported - better fail than guess
  if result == 0:
    raise newException(ChooseNimError,
      "Could not detect CPU architecture: " & failMsg)

  # Only once
  cpuArch = result

proc getMingwPath*(params: CliParams): string =
  let arch = getCpuArch()
  return params.getInstallDir() / "mingw" & $arch

proc getMingwBin*(params: CliParams): string =
  return getMingwPath(params) / "bin"

proc getBinArchiveFormat*(): string =
  when defined(windows):
    return ".zip"
  else:
    return ".tar.xz"

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
      of "choosenimdir": params.choosenimDir = val.absolutePath()
      of "nimbledir": params.nimbleOptions.nimbleDir = val.absolutePath()
      of "firstinstall": params.firstInstall = true
      of "y", "yes": params.nimbleOptions.forcePrompts = forcePromptYes
      of "installed": params.onlyInstalled = true
      else:
        if not proxyExeMode:
          raise newException(ChooseNimError, "Unknown flag: --" & key)
    of cmdEnd: assert(false)

  if params.commands.len == 0 and not proxyExeMode:
    writeHelp()
