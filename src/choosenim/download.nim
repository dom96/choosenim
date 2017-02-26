import httpclient, strutils, os, terminal

import nimblepkg/[version, cli]

import options, common

const
  githubUrl = "https://github.com/nim-lang/Nim/archive/$1.tar.gz"
  websiteUrl = "http://nim-lang.org/download/nim-$1.tar.gz"
  csourcesUrl = "https://github.com/nim-lang/csources/archive/master.tar.gz"

const
  progressBarLength = 50

proc showIndeterminateBar(progress, speed: BiggestInt, lastPos: var int) =
  eraseLine()
  if lastPos >= progressBarLength:
    lastPos = 0

  var spaces = repeat(' ', progressBarLength)
  spaces[lastPos] = '#'
  lastPos.inc()
  stdout.write("[$1] $2mb $3kb/s" % [
                  spaces, $(progress div (1000*1000)),
                  $(speed div 1000)
                ])
  stdout.flushFile()

proc showBar(fraction: float, speed: BiggestInt) =
  eraseLine()
  let hashes = repeat('#', int(fraction * progressBarLength))
  let spaces = repeat(' ', progressBarLength - hashes.len)
  stdout.write("[$1$2] $3% $4kb/s" % [
                  hashes, spaces, formatFloat(fraction * 100, precision=4),
                  $(speed div 1000)
                ])
  stdout.flushFile()

proc downloadFile(url, outputPath: string) =
  var client = newHttpClient()

  var lastProgressPos = 0
  proc onProgressChanged(total, progress, speed: BiggestInt) =
    let fraction = progress.float / total.float
    if fraction == Inf:
      showIndeterminateBar(progress, speed, lastProgressPos)
    else:
      showBar(fraction, speed)

  client.onProgressChanged = onProgressChanged

  # Create outputPath's directory if it doesn't exist already.
  createDir(outputPath.splitFile.dir)
  # Download to temporary file to prevent problems when choosenim crashes.
  let tempOutputPath = outputPath & "_temp"
  try:
    client.downloadFile(url, tempOutputPath)
  except HttpRequestError:
    echo("") # Skip line with progress bar.
    let msg = "Couldn't download file from $1.\nResponse was: $2" %
              [url, getCurrentExceptionMsg()]
    display("Info:", msg, Warning, MediumPriority)
    raise

  moveFile(tempOutputPath, outputPath)

  showBar(1, 0)
  echo("")

proc downloadImpl(version: Version): string =
  let outputPath = getDownloadDir() / ("nim-$1.tar.gz" % $version)
  if outputPath.existsFile():
    # TODO: Verify sha256.
    display("Info:", "Nim $1 already downloaded" % $version,
            priority=HighPriority)
    return outputPath

  if version.isSpecial():
    let reference =
      case normalize($version)
      of "#head":
        "devel"
      else:
        ($version)[1 .. ^1]
    display("Downloading", "Nim $1 from $2" % [reference, "GitHub"],
            priority = HighPriority)
    downloadFile(githubUrl % reference, outputPath)
    result = outputPath
  else:
    display("Downloading", "Nim $1 from $2" % [$version, "nim-lang.org"],
            priority = HighPriority)
    downloadFile(websiteUrl % $version, outputPath)
    result = outputPath

proc download*(version: Version): string =
  ## Returns the path of the downloaded .tar.gz file.
  try:
    return downloadImpl(version)
  except HttpRequestError:
    raise newException(ChooseNimError, "Version $1 does not exist." %
                       $version)

proc downloadCSources*(): string =
  let outputPath = getDownloadDir() / "nim-csources.tar.gz"
  if outputPath.existsFile():
    # TODO: Verify sha256.
    display("Info:", "C sources already downloaded", priority=HighPriority)
    return outputPath

  display("Downloading", "Nim C sources from GitHub", priority = HighPriority)
  downloadFile(csourcesUrl, outputPath)
  return outputPath