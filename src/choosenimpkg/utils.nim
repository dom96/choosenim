import httpclient, json, os, streams, strutils, osproc, uri

import nimblepkg/[cli, version]
import nimarchive

import common, cliparams

when defined(windows):
  import switcher


const nightliesPlatformKey* =
  when defined(i386): hostOS & "_x32"
  elif defined(amd64): hostOS & "_x64"
  else: hostOS & "_" & hostCPU


proc parseVersion*(versionStr: string): Version =
  if versionStr[0] notin {'#', '\0'} + Digits:
    let msg = "Invalid version, path or unknown channel. " &
              "Try 0.16.0, #head, #commitHash, or stable. " &
              "See --help for more examples."
    raise newException(ChooseNimError, msg)

  let parts = versionStr.split(".")
  if parts.len >= 3 and parts[2].parseInt() mod 2 != 0:
    let msg = ("Version $# is a development version of Nim. This means " &
              "it hasn't been released so you cannot install it this " &
              "way. All unreleased versions of Nim " &
              "have an odd patch number in their version.") % versionStr
    let exc = newException(ChooseNimError, msg)
    exc.hint = "If you want to install the development version then run " &
               "`choosenim devel`."
    raise exc

  result = newVersion(versionStr)

proc outputReader(stream: Stream, missedEscape: var bool): string =
  result = ""

  template handleEscape: untyped {.dirty.} =
    missedEscape = false
    result.add('\27')
    let escape = stream.readStr(1)
    result.add(escape)
    if escape[0] == '[':
      result.add(stream.readStr(2))

    return

  # TODO: This would be much easier to implement if `peek` was supported.
  if missedEscape:
    handleEscape()

  while true:
    let c = stream.readStr(1)

    if c.len() == 0:
      return

    case c[0]
    of '\c', '\l':
      result.add(c[0])
      return
    of '\27':
      if result.len > 0:
        missedEscape = true
        return

      handleEscape()
    else:
      result.add(c[0])

proc doCmdRaw*(cmd: string, workingDir: string = "", liveOutput=false) =
  # To keep output in sequence
  stdout.flushFile()
  stderr.flushFile()
  let currentDir = getCurrentDir()
  defer:
    setCurrentDir(currentDir)

  if workingDir.len != 0:
    setCurrentDir(workingDir)
  displayDebug("Executing", cmd)

  var
    output = ""
    exitCode: int
  if not liveOutput:
    (output, exitCode) = execCmdEx(cmd)
  else:
    let process = startProcess(cmd, options={poEvalCommand, poStdErrToStdOut})
    var missedEscape = false
    while true:
      if not process.outputStream.atEnd:
        let line = process.outputStream.outputReader(missedEscape)
        output.add(line)
        stdout.write(line)
        if line.len() != 0 and line[0] != '\27':
          stdout.flushFile()
      else:
        exitCode = process.peekExitCode()
        if exitCode != -1: break

    process.close()

  displayDebug("Finished", "with exit code " & $exitCode)
  displayDebug("Output", output)

  if exitCode != QuitSuccess:
    raise newException(ChooseNimError,
        "Execution failed with exit code $1\nCommand: $2\nOutput: $3" %
        [$exitCode, cmd, output])

proc extract*(path: string, extractDir: string) =
  display("Extracting", path.extractFilename(), priority = HighPriority)

  try:
    nimarchive.extract(path, extractDir)
  except Exception as exc:
    raise newException(ChooseNimError, "Unable to extract. Error was '$1'." %
                       exc.msg)

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

proc getLatestCommit*(repo, branch: string): string =
  ## Get latest commit for remote Git repo with ls-remote
  ##
  ## Returns "" if Git isn't available
  let
    git = findExe("git")
  if git.len != 0:
    var
      cmd = when defined(windows): "cmd /c " else: ""
    cmd &= git.quoteShell & " ls-remote " & repo & " " & branch

    let
      (outp, errC) = execCmdEx(cmd)
    if errC == 0:
      for line in outp.splitLines():
        result = line.split('\t')[0]
        break
    else:
      display("Warning", outp & "\ngit ls-remote failed", Warning, HighPriority)

proc getNightliesUrl*(parsedContents: JsonNode): string =
  for jn in parsedContents.getElems():
    if "devel" in jn["name"].getStr():
      for asset in jn["assets"].getElems():
        let aname = asset["name"].getStr()
        if nightliesPlatformKey in aname:
          let downloadUrl = asset["browser_download_url"].getStr()
          if downloadUrl.len != 0:
            return downloadUrl

  if result.len == 0:
    display("Warning", "Recent nightly release not found, installing latest devel commit.",
            Warning, priority = HighPriority)

