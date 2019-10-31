import httpclient, os, strutils, osproc, sequtils, times, uri

import nimblepkg/[cli, tools, version]
import nimarchive

import switcher, cliparams, common

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

proc doCmdRaw*(cmd: string) =
  # To keep output in sequence
  stdout.flushFile()
  stderr.flushFile()

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

proc getGccArch*(params: CliParams): int =
  var
    outp = ""
    errC = 0

  when defined(windows):
    # Add MingW bin dir to PATH so getGccArch can find gcc.
    let pathEnv = getEnv("PATH")
    if not isDefaultCCInPath(params) and dirExists(params.getMingwBin()):
      putEnv("PATH", params.getMingwBin() & PathSep & pathEnv)

    (outp, errC) = execCmdEx("cmd /c echo int main^(^) { return sizeof^(void *^); } | gcc -xc - -o archtest && archtest")

    putEnv("PATH", pathEnv)
  else:
    (outp, errC) = execCmdEx("echo \"int main() { return sizeof(void *); }\" | gcc -xc - -o archtest && ./archtest")

  removeFile("archtest".addFileExt(ExeExt))
  return errC * 8
