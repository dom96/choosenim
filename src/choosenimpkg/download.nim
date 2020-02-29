import httpclient, strutils, os, osproc, terminal, times, json, uri

when defined(macosx):
  import math

import nimblepkg/[version, cli]
when defined(curl):
  import libcurl except Version

import cliparams, common, telemetry, utils

const
  githubTagReleasesUrl = "https://api.github.com/repos/nim-lang/Nim/tags"
  githubNightliesReleasesUrl = "https://api.github.com/repos/nim-lang/nightlies/releases"
  githubUrl = "https://github.com/nim-lang/Nim"
  websiteUrl = "http://nim-lang.org/download/nim-$1.tar.xz"
  csourcesUrl = "https://github.com/nim-lang/csources"
  dlArchive = "archive/$1.tar.gz"
  binaryUrl = "http://nim-lang.org/download/nim-$1$2_x$3" & getBinArchiveFormat()

const # Windows-only
  mingwUrl = "http://nim-lang.org/download/mingw$1.7z"
  dllsUrl = "http://nim-lang.org/download/dlls.zip"

const
  progressBarLength = 50

proc showIndeterminateBar(progress, speed: BiggestInt, lastPos: var int) =
  try:
    eraseLine()
  except OSError:
    echo ""
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
    echo ""
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

proc downloadFileNim(url, outputPath: string) =
  var client = newHttpClient(proxy = getProxy())

  var lastProgressPos = 0
  proc onProgressChanged(total, progress, speed: BiggestInt) {.closure, gcsafe.} =
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

proc retrieveUrl*(url: string): string
proc downloadImpl(version: Version, params: CliParams): string =
  let arch = getGccArch(params)
  if version.isSpecial():
    var reference, url = ""
    if $version in ["#devel", "#head"] and not params.latest:
      # Install nightlies by default for devel channel
      let rawContents = retrieveUrl(githubNightliesReleasesUrl)
      let parsedContents = parseJson(rawContents)
      url = getNightliesUrl(parsedContents, arch)
      reference = "devel"

    if url.len == 0:
      let
        commit = getLatestCommit(githubUrl, "devel")
        archive = if commit.len != 0: commit else: "devel"
      reference =
        case normalize($version)
        of "#head":
          archive
        else:
          ($version)[1 .. ^1]
      url = $(parseUri(githubUrl) / (dlArchive % reference))
    display("Downloading", "Nim $1 from $2" % [reference, "GitHub"],
            priority = HighPriority)
    var outputPath: string
    if not needsDownload(params, url, outputPath): return outputPath

    downloadFile(url, outputPath, params)
    result = outputPath
  else:
    display("Downloading", "Nim $1 from $2" % [$version, "nim-lang.org"],
            priority = HighPriority)

    var outputPath: string

    # Use binary builds for Windows and Linux
    when defined(Windows) or defined(linux):
      let os = when defined(linux): "-linux" else: ""
      let binUrl = binaryUrl % [$version, os, $arch]
      if not needsDownload(params, binUrl, outputPath): return outputPath
      try:
        downloadFile(binUrl, outputPath, params)
        return outputPath
      except HttpRequestError:
        display("Info:", "Binary build unavailable, building from source",
                priority = HighPriority)

    let url = websiteUrl % $version
    if not needsDownload(params, url, outputPath): return outputPath

    downloadFile(url, outputPath, params)
    result = outputPath

proc download*(version: Version, params: CliParams): string =
  ## Returns the path of the downloaded .tar.(gz|xz) file.
  try:
    return downloadImpl(version, params)
  except HttpRequestError:
    raise newException(ChooseNimError, "Version $1 does not exist." %
                       $version)

proc downloadCSources*(params: CliParams): string =
  let
    commit = getLatestCommit(csourcesUrl, "master")
    archive = if commit.len != 0: commit else: "master"
    csourcesArchiveUrl = $(parseUri(csourcesUrl) / (dlArchive % archive))

  var outputPath: string
  if not needsDownload(params, csourcesArchiveUrl, outputPath):
    return outputPath

  display("Downloading", "Nim C sources from GitHub", priority = HighPriority)
  downloadFile(csourcesArchiveUrl, outputPath, params)
  return outputPath

proc downloadMingw*(params: CliParams): string =
  let
    arch = getCpuArch()
    url = mingwUrl % $arch
  var outputPath: string
  if not needsDownload(params, url, outputPath):
    return outputPath

  display("Downloading", "C compiler (Mingw$1)" % $arch, priority = HighPriority)
  downloadFile(url, outputPath, params)
  return outputPath

proc downloadDLLs*(params: CliParams): string =
  var outputPath: string
  if not needsDownload(params, dllsUrl, outputPath):
    return outputPath

  display("Downloading", "DLLs (openssl, pcre, ...)", priority = HighPriority)
  downloadFile(dllsUrl, outputPath, params)
  return outputPath

proc retrieveUrl*(url: string): string =
  var userAgent = "choosenim/" & chooseNimVersion
  when defined(curl):
    display("Curl", "Requesting " & url, priority = DebugPriority)
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

    checkCurl curl.easy_setopt(OPT_USERAGENT, addr userAgent[0])

    # Download the file.
    checkCurl curl.easy_perform()

    # Verify the response code.
    var responseCode: int
    checkCurl curl.easy_getinfo(INFO_RESPONSE_CODE, addr responseCode)

    display("Curl", res, priority = DebugPriority)

    doAssert responseCode == 200,
             "Expected HTTP code $1 got $2 for $3" % [$200, $responseCode, url]

    return res
  else:
    display("Http", "Requesting " & url, priority = DebugPriority)
    var client = newHttpClient(proxy = getProxy(), userAgent = userAgent)
    return client.getContent(url)

proc getOfficialReleases*(params: CliParams): seq[Version] =
  let rawContents = retrieveUrl(githubTagReleasesUrl)
  let parsedContents = parseJson(rawContents)
  let cutOffVersion = newVersion("0.16.0")

  var releases: seq[Version] = @[]
  for release in parsedContents:
    let name = release["name"].getStr().strip(true, false, {'v'})
    let version = name.newVersion
    if cutOffVersion <= version:
      releases.add(version)
  return releases

template isDevel*(version: Version): bool =
  $version in ["#head", "#devel"]

proc gitUpdate*(version: Version, extractDir: string, params: CliParams): bool =
  if version.isDevel() and params.latest:
    let git = findExe("git")
    if git.len != 0 and fileExists(extractDir / ".git" / "config"):
      result = true

      let lastDir = getCurrentDir()
      setCurrentDir(extractDir)
      defer:
        setCurrentDir(lastDir)

      display("Fetching", "latest changes", priority = HighPriority)
      for cmd in [" fetch --all", " reset --hard origin/devel"]:
        var (outp, errC) = execCmdEx(git & cmd)
        if errC != QuitSuccess:
          display("Warning:", "git" & cmd & " failed: " & outp, Warning, priority = HighPriority)
          return false

proc gitInit*(version: Version, extractDir: string, params: CliParams) =
  createDir(extractDir / ".git")
  if version.isDevel():
    let git = findExe("git")
    if git.len != 0:
      let lastDir = getCurrentDir()
      setCurrentDir(extractDir)
      defer:
        setCurrentDir(lastDir)

      var init = true
      display("Setting", "up git repository", priority = HighPriority)
      for cmd in [" init", " remote add origin https://github.com/nim-lang/nim"]:
        var (outp, errC) = execCmdEx(git & cmd)
        if errC != QuitSuccess:
          display("Warning:", "git" & cmd & " failed: " & outp, Warning, priority = HighPriority)
          init = false
          break

      if init:
        discard gitUpdate(version, extractDir, params)

when isMainModule:

  echo retrieveUrl("https://nim-lang.org")
