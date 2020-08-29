# Copyright (C) Dominik Picheta. All rights reserved.
# BSD-3-Clause License. Look at license.txt for more info.
import osproc, streams, unittest, strutils, os, sequtils, sugar

var rootDir = getCurrentDir().parentDir()
var exePath = rootDir / "bin" / addFileExt("choosenim", ExeExt)
var nimbleDir = rootDir / "tests" / "nimbleDir"
var choosenimDir = rootDir / "tests" / "choosenimDir"

template cd*(dir: string, body: untyped) =
  ## Sets the current dir to ``dir``, executes ``body`` and restores the
  ## previous working dir.
  let lastDir = getCurrentDir()
  setCurrentDir(dir)
  body
  setCurrentDir(lastDir)

template beginTest() =
  # Clear custom dirs.
  if dirExists(choosenimDir):
    removeDir(nimbleDir)
  createDir(nimbleDir)
  if dirExists(choosenimDir):
    removeDir(choosenimDir)
  createDir(choosenimDir)

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

proc exec(args: varargs[string], exe=exePath,
          yes=true, liveOutput=false,
          global=false): tuple[output: string, exitCode: int] =
  var quotedArgs: seq[string] = @[exe]
  if yes:
    quotedArgs.add("-y")
  quotedArgs.add(@args)
  if not global:
    quotedArgs.add("--nimbleDir:" & nimbleDir)
    if exe != "nimble":
      quotedArgs.add("--choosenimDir:" & choosenimDir)
  quotedArgs.add("--noColor")

  for i in 0..quotedArgs.len-1:
    if " " in quotedArgs[i]:
      quotedArgs[i] = "\"" & quotedArgs[i] & "\""

  if not liveOutput:
    result = execCmdEx(quotedArgs.join(" "))
  else:
    result.output = ""
    let process = startProcess(quotedArgs.join(" "),
                               options={poEvalCommand, poStdErrToStdOut})
    var missedEscape = false
    while true:
      if not process.outputStream.atEnd:
        let line = process.outputStream.outputReader(missedEscape)
        result.output.add(line)
        stdout.write(line)
        if line.len() != 0 and line[0] != '\27':
          stdout.flushFile()
      else:
        result.exitCode = process.peekExitCode()
        if result.exitCode != -1: break

    process.close()

proc processOutput(output: string): seq[string] =
  output.strip.splitLines().filter((x: string) => (x.len > 0))

proc inLines(lines: seq[string], word: string): bool =
  for i in lines:
    if word.normalize in i.normalize: return true

proc hasLine(lines: seq[string], line: string): bool =
  for i in lines:
    if i.normalize.strip() == line.normalize(): return true

test "can compile choosenim":
  cd "..":
    let (_, exitCode) = exec("build", exe="nimble", global=true, liveOutput=true)
    check exitCode == QuitSuccess

test "refuses invalid path":
  beginTest()
  block:
    let (output, exitCode) = exec(getTempDir() / "blahblah")
    check exitCode == QuitFailure
    check inLines(output.processOutput, "invalid")
    check inLines(output.processOutput, "version")
    check inLines(output.processOutput, "path")

  block:
    let (output, exitCode) = exec(getTempDir())
    check exitCode == QuitFailure
    check inLines(output.processOutput, "no")
    check inLines(output.processOutput, "binary")
    check inLines(output.processOutput, "found")

test "fails on bad flag":
  beginTest()
  let (output, exitCode) = exec("--qwetqsdweqwe")
  check exitCode == QuitFailure
  check inLines(output.processOutput, "unknown")
  check inLines(output.processOutput, "flag")

test "can choose v0.16.0":
  when not (defined(i386) or defined(amd64)):
    # 0.16.0 doesn't compile on arm/ppc
    skip()
  else:
    beginTest()
    block:
      let (output, exitCode) = exec("0.16.0", liveOutput=true)
      check exitCode == QuitSuccess

      check inLines(output.processOutput, "building")
      check inLines(output.processOutput, "downloading")
      when defined(windows):
        check inLines(output.processOutput, "already built")
      else:
        check inLines(output.processOutput, "building tools")
      check hasLine(output.processOutput, "switched to nim 0.16.0")

    block:
      let (output, exitCode) = exec("0.16.0")
      check exitCode == QuitSuccess

      check hasLine(output.processOutput, "info: version 0.16.0 already selected")

    block:
      let (output, exitCode) = exec("--version", exe=nimbleDir / "bin" / "nimble")

      check exitCode == QuitSuccess
      check inLines(output.processOutput, "v0.8.2")

test "can choose v1.0.0":
  if "can choose v1.0.0" in getEnv("CHOOSENIM_SKIP_TESTS"):
    skip()
  else:
    beginTest()
    block:
      let (output, exitCode) = exec("1.0.0", liveOutput=true)
      check exitCode == QuitSuccess

      check inLines(output.processOutput, "downloading")
      check(
        inLines(output.processOutput, "already built") or
        # Official Nim binaries not available for the platform, so was built
        inLines(output.processOutput, "building nim")
      )

      check hasLine(output.processOutput, "switched to nim 1.0.0")
      check not dirExists(choosenimDir / "toolchains" / "nim-1.0.0" / "c_code")

test "can update devel with git":
  if "can update devel with git" in getEnv("CHOOSENIM_SKIP_TESTS"):
    skip()
  else:
    beginTest()
    block:
      let (output, exitCode) = exec(@["devel", "--latest"], liveOutput=true)

      # Travis runs into Github API limit
      if not inLines(output.processOutput, "unavailable"):
        check exitCode == QuitSuccess

        check not inLines(output.processOutput, "updating devel")
        check inLines(output.processOutput, "downloading nim devel from github")
        check inLines(output.processOutput, "setting up git repository")
        check inLines(output.processOutput, "building nim #devel")
        check inLines(output.processOutput, "switched to nim #devel")

  block:
    let (output, exitCode) = exec(@["update", "devel", "--latest"], liveOutput=true)

    # Travis runs into Github API limit
    if not inLines(output.processOutput, "unavailable"):
      check exitCode == QuitSuccess

      check not inLines(output.processOutput, "extracting")
      check not inLines(output.processOutput, "setting up git repository")

      check inLines(output.processOutput, "updating devel")
      check inLines(output.processOutput, "fetching latest changes")
      check inLines(output.processOutput, "building nim #devel")
      check inLines(output.processOutput, "updated to #devel")

test "can install and update nightlies":
  beginTest()
  block:
    # Install nightly
    let (output, exitCode) = exec("devel", liveOutput=true)

    # Travis runs into Github API limit
    if not inLines(output.processOutput, "unavailable"):
      check exitCode == QuitSuccess

      check not inLines(output.processOutput, "updating devel")
      check inLines(output.processOutput, "downloading nim devel from github")
      check inLines(output.processOutput, "setting up git repository")
      check(
        (
          inLines(output.processOutput, "recent nightly release not found") and
          inLines(output.processOutput, "building nim #devel")
        ) or
        inLines(output.processOutput, "already built")
      )
      check inLines(output.processOutput, "switched to nim #devel")

      block:
        # Update nightly
        let (output, exitCode) = exec(@["update", "devel"], liveOutput=true)

        # Travis runs into Github API limit
        if not inLines(output.processOutput, "unavailable"):
          check exitCode == QuitSuccess

          check inLines(output.processOutput, "updating devel")
          check inLines(output.processOutput, "downloading nim devel from github")
          check inLines(output.processOutput, "setting up git repository")
          check(
            (
              inLines(output.processOutput, "recent nightly release not found") and
              inLines(output.processOutput, "building nim #devel")
            ) or
            inLines(output.processOutput, "already built")
          )
          check inLines(output.processOutput, "updated to #devel")

      block:
        # Update to devel latest using git
        let (output, exitCode) = exec(@["update", "devel", "--latest"], liveOutput=true)
        check exitCode == QuitSuccess

        check not inLines(output.processOutput, "extracting")
        check not inLines(output.processOutput, "setting up git repository")

        check inLines(output.processOutput, "updating devel")
        check inLines(output.processOutput, "fetching latest changes")
        check inLines(output.processOutput, "building nim #devel")
        check inLines(output.processOutput, "updated to #devel")

test "can update self":
  # updateSelf() doesn't use options --choosenimDir and --nimbleDir. It's used getAppDir().
  # This will rewrite $project/bin dir, it's dangerous.
  # So, this test copy bin/choosenim to test/choosenimDir/choosenim, and use it.
  beginTest()
  let testExePath = choosenimDir / extractFilename(exePath)
  copyFileWithPermissions(exePath, testExePath)
  block:
    let (output, exitCode) = exec(["update", "self", "--debug", "--force"], exe=testExePath, liveOutput=true)

    check exitCode == QuitSuccess
    check inLines(output.processOutput, "updated choosenim to version")
