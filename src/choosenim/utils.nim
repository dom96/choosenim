import os, strutils, osproc

import nimblepkg/[cli, tools, version]
import untar

import switcher, common

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

proc extractZip(path: string, extractDir: string) =
  var cmd = "unzip -o $1 -d $2"
  if defined(windows):
      cmd = "powershell -nologo -noprofile -command \"& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('$1', '$2'); }\""

  let (outp, errC) = execCmdEx(cmd % [path, extractDir])
  if errC != 0:
    raise newException(ChooseNimError, "Unable to extract ZIP. Error was $1" % outp)

proc extract*(path: string, extractDir: string) =
  display("Extracting", path.extractFilename(), priority = HighPriority)

  let ext = path.splitFile().ext
  var newPath = path
  case ext
  of ".zip":
    extractZip(path, extractDir)
    return
  of ".xz":
    # We need to decompress manually.
    let unxzPath = findExe("unxz")
    if unxzPath.len == 0:
      let msg = "Cannot decompress xz, `unxz` not in PATH"
      raise newException(ChooseNimError, msg)

    let tarFile = newPath.changeFileExt("") # This will remove the .xz
    # `unxz` complains when the .tar file already exists.
    removeFile(tarFile)
    doCmdRaw("unxz \"$1\"" % newPath)
    newPath = tarFile
  of ".gz":
    # untar package will take care of this.
    discard
  else:
    raise newException(ChooseNimError, "Invalid archive format " & ext)

  try:
    var file = newTarFile(newPath)
    file.extract(extractDir)
  except Exception as exc:
    raise newException(ChooseNimError, "Unable to extract. Error was '$1'." %
                       exc.msg)

proc moveDirContents*(srcDir, dstDir: string) =
  for kind, entry in walkDir(srcDir):
    if kind in [pcFile, pcLinkToFile]:
      moveFile(entry, dstDir/entry.extractFilename())
    else:
      moveDir(entry, dstDir/entry.extractFilename())

proc getGccArch*(): int =
  # gcc should be in PATH
  var
    outp = ""
    errC = 0

  when defined(windows):
    (outp, errC) = execCmdEx("cmd /c echo int main^(^) { return sizeof^(void *^); } | gcc -xc - -o archtest && archtest")
  else:
    (outp, errC) = execCmdEx("sh echo \"int main() { return sizeof(void *); }\" | gcc -xc - -o archtest && archtest")

  removeFile("archtest".addFileExt(ExeExt))
  return errC * 8
