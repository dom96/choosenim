import httpclient, strutils, os, terminal, times, math

import nimblepkg/[version, cli]
when defined(curl):
  import libcurl except Version

import cliparams, common

const
  githubUrl = "https://github.com/nim-lang/Nim/archive/$1.tar.gz"
  websiteUrl = "http://nim-lang.org/download/nim-$1.tar.gz"
  csourcesUrl = "https://github.com/nim-lang/csources/archive/master.tar.gz"
  mingwUrl = "http://nim-lang.org/download/mingw32.tar.gz"

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

when defined(curl):
  proc checkCurl(code: Code) =
    if code != E_OK:
      raise newException(AssertionError, "CURL failed: " & $easy_strerror(code))

  proc downloadFileCurl(url, outputPath: string) =
    # Based on: https://curl.haxx.se/libcurl/c/url2file.html
    let curl = libcurl.easy_init()
    defer:
      curl.easy_cleanup()

    # Enable progress bar.
    #checkCurl curl.easy_setopt(OPT_VERBOSE, 1)
    checkCurl curl.easy_setopt(OPT_NOPROGRESS, 0)

    # Set which URL to download and tell curl to follow redirects.
    checkCurl curl.easy_setopt(OPT_URL, url)
    checkCurl curl.easy_setopt(OPT_FOLLOWLOCATION, 1)

    type
      UserData = ref object
        file: File
        lastProgressPos: int
        bytesWritten: int
        lastSpeedUpdate: float
        speed: BiggestInt
        needsUpdate: bool

    # Set up progress callback.
    proc onProgress(userData: pointer, dltotal, dlnow, ultotal,
                    ulnow: float): cint =
      result = 0 # Ensure download isn't terminated.

      let userData = cast[UserData](userData)

      # Only update once per second.
      if userData.needsUpdate:
        userData.needsUpdate = false
      else:
        return

      let fraction = dlnow.float / dltotal.float
      if fraction.classify == fcNan:
        return

      if fraction == Inf:
        showIndeterminateBar(dlnow.BiggestInt, userData.speed,
                            userData.lastProgressPos)
      else:
        showBar(fraction, userData.speed)

    checkCurl curl.easy_setopt(OPT_PROGRESSFUNCTION, onProgress)

    # Set up write callback.
    proc onWrite(data: ptr char, size: cint, nmemb: cint,
                userData: pointer): cint =
      let userData = cast[UserData](userData)
      let len = size * nmemb
      result = userData.file.writeBuffer(data, len).cint
      doAssert result == len

      # Handle speed measurement.
      const updateInterval = 0.25
      userData.bytesWritten += result
      if epochTime() - userData.lastSpeedUpdate > updateInterval:
        userData.speed = userData.bytesWritten * int(1/updateInterval)
        userData.bytesWritten = 0
        userData.lastSpeedUpdate = epochTime()
        userData.needsUpdate = true

    checkCurl curl.easy_setopt(OPT_WRITEFUNCTION, onWrite)

    # Open file for writing and set up UserData.
    let userData = UserData(
      file: open(outputPath, fmWrite),
      lastProgressPos: 0,
      lastSpeedUpdate: epochTime(),
      speed: 0
    )
    defer:
      userData.file.close()
    checkCurl curl.easy_setopt(OPT_WRITEDATA, userData)
    checkCurl curl.easy_setopt(OPT_PROGRESSDATA, userData)

    # Download the file.
    checkCurl curl.easy_perform()

    # Verify the response code.
    var responseCode: int
    checkCurl curl.easy_getinfo(INFO_RESPONSE_CODE, addr responseCode)

    doAssert responseCode == 200,
             "Expected HTTP code $1 got $2" % [$200, $responseCode]

proc downloadFileNim(url, outputPath: string) =
  var client = newHttpClient()

  var lastProgressPos = 0
  proc onProgressChanged(total, progress, speed: BiggestInt) =
    let fraction = progress.float / total.float
    if fraction == Inf:
      showIndeterminateBar(progress, speed, lastProgressPos)
    else:
      showBar(fraction, speed)

  client.onProgressChanged = onProgressChanged

  client.downloadFile(url, outputPath)

proc downloadFile(url, outputPath: string) =
  # Create outputPath's directory if it doesn't exist already.
  createDir(outputPath.splitFile.dir)

  # Download to temporary file to prevent problems when choosenim crashes.
  let tempOutputPath = outputPath & "_temp"
  try:
    when defined(curl):
      downloadFileCurl(url, tempOutputPath)
    else:
      downloadFileNim(url, tempOutputPath)
  except HttpRequestError, AssertionError:
    echo("") # Skip line with progress bar.
    let msg = "Couldn't download file from $1.\nResponse was: $2" %
              [url, getCurrentExceptionMsg()]
    display("Info:", msg, Warning, MediumPriority)
    raise

  moveFile(tempOutputPath, outputPath)

  showBar(1, 0)
  echo("")

proc downloadImpl(version: Version, params: CliParams): string =
  let outputPath = params.getDownloadDir() / ("nim-$1.tar.gz" % $version)
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

proc download*(version: Version, params: CliParams): string =
  ## Returns the path of the downloaded .tar.gz file.
  try:
    return downloadImpl(version, params)
  except HttpRequestError:
    raise newException(ChooseNimError, "Version $1 does not exist." %
                       $version)

proc downloadCSources*(params: CliParams): string =
  let outputPath = params.getDownloadDir() / "nim-csources.tar.gz"
  if outputPath.existsFile():
    # TODO: Verify sha256.
    display("Info:", "C sources already downloaded", priority=HighPriority)
    return outputPath

  display("Downloading", "Nim C sources from GitHub", priority = HighPriority)
  downloadFile(csourcesUrl, outputPath)
  return outputPath

proc downloadMingw32*(params: CliParams): string =
  let outputPath = params.getDownloadDir() / "mingw32.tar.gz"
  if outputPath.existsFile():
    # TODO: Verify sha256.
    display("Info:", "C compiler (Mingw32) already downloaded",
            priority=HighPriority)
    return outputPath

  display("Downloading", "C compiler (Mingw32)", priority = HighPriority)
  downloadFile(mingwUrl, outputPath)
  return outputPath

proc retrieveUrl*(url: string): string =
  when defined(curl):
    # Based on: https://curl.haxx.se/libcurl/c/simple.html
    let curl = libcurl.easy_init()

    # Set which URL to retrieve and tell curl to follow redirects.
    checkCurl curl.easy_setopt(OPT_URL, url)
    checkCurl curl.easy_setopt(OPT_FOLLOWLOCATION, 1)

    var res = ""
    # Set up write callback.
    proc onWrite(data: ptr char, size: cint, nmemb: cint,
                 userData: pointer): cint =
      var res = cast[ptr string](userData)
      var buffer = newString(size * nmemb)
      copyMem(addr buffer[0], data, buffer.len)
      res[].add(buffer)
      result = buffer.len.cint

    checkCurl curl.easy_setopt(OPT_WRITEFUNCTION, onWrite)
    checkCurl curl.easy_setopt(OPT_WRITEDATA, addr res)

    # Download the file.
    checkCurl curl.easy_perform()

    # Verify the response code.
    var responseCode: int
    checkCurl curl.easy_getinfo(INFO_RESPONSE_CODE, addr responseCode)

    doAssert responseCode == 200,
             "Expected HTTP code $1 got $2" % [$200, $responseCode]

    return res
  else:
    var client = newHttpClient()
    return client.getContent(url)

when isMainModule:

  echo retrieveUrl("https://nim-lang.org")
