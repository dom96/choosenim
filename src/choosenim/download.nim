import httpclient, strutils, os, terminal, times, math, uri

import nimblepkg/[version, cli]
when defined(curl):
  import libcurl except Version

import cliparams, common, telemetry, utils

const
  githubUrl = "https://github.com/nim-lang/Nim/archive/$1.tar.gz"
  websiteUrl = "http://nim-lang.org/download/nim-$1.tar" &
    getArchiveFormat()
  csourcesUrl = "https://github.com/nim-lang/csources/archive/$1.tar.gz"
  winBinaryZipUrl = "http://nim-lang.org/download/nim-$1_x$2.zip"

const # Windows-only
  mingwUrl = "http://nim-lang.org/download/mingw32.tar.gz"
  dllsUrl = "http://nim-lang.org/download/dlls.tar.gz"

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
  try:
    eraseLine()
  except OSError:
    discard
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

    if responseCode != 200:
      raise newException(HTTPRequestError,
             "Expected HTTP code $1 got $2" % [$200, $responseCode])

proc getProxy*(): Proxy =
  ## Returns ``nil`` if no proxy is specified.
  var url = ""
  try:
    if existsEnv("http_proxy"):
      url = getEnv("http_proxy")
    elif existsEnv("https_proxy"):
      url = getEnv("https_proxy")
  except ValueError:
    display("Warning:", "Unable to parse proxy from environment: " &
        getCurrentExceptionMsg(), Warning, HighPriority)

  if url.len > 0:
    var parsed = parseUri(url)
    if parsed.scheme.len == 0 or parsed.hostname.len == 0:
      parsed = parseUri("http://" & url)
    let auth =
      if parsed.username.len > 0: parsed.username & ":" & parsed.password
      else: ""
    return newProxy($parsed, auth)
  else:
    return nil

proc downloadFileNim(url, outputPath: string) =
  var client = newHttpClient(proxy = getProxy())

  var lastProgressPos = 0
  proc onProgressChanged(total, progress, speed: BiggestInt) =
    let fraction = progress.float / total.float
    if fraction == Inf:
      showIndeterminateBar(progress, speed, lastProgressPos)
    else:
      showBar(fraction, speed)

  client.onProgressChanged = onProgressChanged

  client.downloadFile(url, outputPath)

proc downloadFile*(url, outputPath: string, params: CliParams) =
  # Telemetry
  let startTime = epochTime()

  # Create outputPath's directory if it doesn't exist already.
  createDir(outputPath.splitFile.dir)

  # Download to temporary file to prevent problems when choosenim crashes.
  let tempOutputPath = outputPath & "_temp"
  try:
    when defined(curl):
      downloadFileCurl(url, tempOutputPath)
    else:
      downloadFileNim(url, tempOutputPath)
  except HttpRequestError:
    echo("") # Skip line with progress bar.
    let msg = "Couldn't download file from $1.\nResponse was: $2" %
              [url, getCurrentExceptionMsg()]
    display("Info:", msg, Warning, MediumPriority)
    report(initTiming(DownloadTime, url, startTime, $LabelFailure), params)
    raise

  moveFile(tempOutputPath, outputPath)

  showBar(1, 0)
  echo("")

  report(initTiming(DownloadTime, url, startTime, $LabelSuccess), params)

proc needsDownload(params: CliParams, downloadUrl: string,
                   outputPath: var string): bool =
  ## Returns whether the download should commence.
  ##
  ## The `outputPath` argument is filled with the valid download path.
  result = true
  outputPath = params.getDownloadPath(downloadUrl)
  if outputPath.existsFile():
    # TODO: Verify sha256.
    display("Info:", "$1 already downloaded" % outputPath,
            priority=HighPriority)
    return false

proc downloadCheck(params: CliParams, url: string): string =
  result = ""
  if not needsDownload(params, url, result): return

  downloadFile(url, result, params)

proc downloadCheckRenamed(params: CliParams, url, filename: string): string =
  # Special check since we have to rename to disambiguate
  result = getDownloadDir(params) / filename
  if not fileExists(result):
    let origfile = downloadCheck(params, url)
    moveFile(origfile, result)

proc downloadImpl(version: Version, params: CliParams): string =
  let arch = getGccArch()
  if version.isSpecial():
    let reference =
      case normalize($version)
      of "#head":
        "devel"
      else:
        ($version)[1 .. ^1]
    display("Downloading", "Nim $1 from $2" % [reference, "GitHub"],
            priority = HighPriority)
    result = downloadCheck(params, githubUrl % reference)
  else:
    display("Downloading", "Nim $1 from $2" % [$version, "nim-lang.org"],
            priority = HighPriority)

    # Check if binary build available
    when defined(windows):
      try:
        result = downloadCheck(params, winBinaryZipUrl % [$version, $arch])
        return
      except HttpRequestError:
        display("Info:", "Binary build unavailable, building from source",
                priority = HighPriority)

    # Check if source tar.gz posted on nim-lang.org
    try:
      result = downloadCheck(params, websiteUrl % $version)
    except HttpRequestError:
      # Fallback to downloading from Github
      # Rename to nim-VERSION.tar.gz to disambiguate
      result = downloadCheckRenamed(params, githubUrl % ("v" & $version),
                                    "nim-$1.tar.gz" % $version)

proc download*(version: Version, params: CliParams): string =
  ## Returns the path of the downloaded .tar.(gz|xz) file.
  try:
    return downloadImpl(version, params)
  except HttpRequestError:
    raise newException(ChooseNimError, "Version $1 does not exist." %
                       $version)

proc downloadCSources*(params: CliParams, version: Version): string =
  display("Downloading", "Nim C sources from GitHub", priority = HighPriority)
  try:
    # Download csources tagged version from Github
    # Rename to csources-VERSION.tar.gz to disambiguate
    result = downloadCheckRenamed(params, csourcesUrl % ("v" & $version),
                                  "csources-$1.tar.gz" % $version)
  except HttpRequestError:
    result = downloadCheck(params, csourcesUrl % "master")
    display("Warning:", "Building from latest C sources. They may not be " &
                        "compatible with the Nim version you have chosen to " &
                        "install.", Warning, HighPriority)

proc downloadMingw32*(params: CliParams): string =
  display("Downloading", "C compiler (Mingw32)", priority = HighPriority)
  result = downloadCheck(params, mingwUrl)

proc downloadDLLs*(params: CliParams): string =
  display("Downloading", "DLLs (openssl, pcre, ...)", priority = HighPriority)
  result = downloadCheck(params, dllsUrl)

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
    var client = newHttpClient(proxy = getProxy())
    return client.getContent(url)

when isMainModule:

  echo retrieveUrl("https://nim-lang.org")
