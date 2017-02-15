import httpclient, strutils, os, terminal

import nimblepkg/[version, cli]

import options, common

const
  githubUrl = "https://github.com/nim-lang/Nim/archive/$1.tar.gz"
  websiteUrl = "http://nim-lang.org/download/nim-$1.tar.gz"

const
  progressBarLength = 50

proc downloadFile(url, outputPath: string) =
  var client = newHttpClient()
  proc onProgressChanged(total, progress, speed: BiggestInt) =
    eraseLine()
    let percent = progress.float / total.float
    let hashes = repeat('#', int(percent * progressBarLength))
    let spaces = repeat(' ', progressBarLength - hashes.len)
    stdout.write("[$1$2] $3% $4kb/s" % [
                    hashes, spaces, formatFloat(percent * 100, precision=4),
                    $(speed div 1000)
                 ])
    stdout.flushFile()
  client.onProgressChanged = onProgressChanged

  try:
    client.downloadFile(url, outputPath)
  except HttpRequestError:
    raise newException(PicknimError,
                       "Couldn't download file from $1.\nResponse was: $2" %
                       [url, getCurrentExceptionMsg()])

proc download*(version: Version): string =
  ## Returns the path of the downloaded .tar.gz file.
  let outputPath = getDownloadDir() / ("nim-$1.tar.gz" % $version)
  if outputPath.existsFile():
    # TODO: Verify sha256.
    display("Info:", "Nim $1 already downloaded" % $version,
            priority=HighPriority)
    return outputPath
  # Create outputPath's directory if it doesn't exist already.
  createDir(outputPath.splitFile.dir)

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

  