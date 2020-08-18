import httpclient, json, os, strutils, osproc, uri

import nimblepkg/[cli, version]
import nimarchive

import common

when defined(windows):
  import switcher

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

proc doCmdRaw*(cmd: string, workingDir: string = "") =
  # To keep output in sequence
  stdout.flushFile()
  stderr.flushFile()
  let currentDir = getCurrentDir()
  defer:
    setCurrentDir(currentDir)

  if workingDir.len != 0:
    setCurrentDir(workingDir)
  displayDebug("Executing", cmd)
  let (output, exitCode) = execCmdEx(cmd)
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
  let os =
    when defined(linux): "linux"
    elif defined(windows): "windows"
    elif defined(macosx): "osx"
  let key =
    when defined(macosx):
      when hostCPU == "amd64": os
      else: os & "_" & hostCPU # osx_arm64 nightlies might exist someday
    else:
      when hostCPU == "i386": os & "_x32"
      elif hostCPU == "amd64": os & "_x64"
      else: os & "_" & hostCPU

  if key.len != 0:
    for jn in parsedContents.getElems():
      if jn["name"].getStr().contains("devel"):
        for asset in jn["assets"].getElems():
          let aname = asset["name"].getStr()
          if key in aname:
            let downloadUrl = asset["browser_download_url"].getStr()
            if downloadUrl.len != 0:
              return downloadUrl

  if result.len == 0:
    display("Warning", "Recent nightly release not found, installing latest devel commit.",
            Warning, priority = HighPriority)
