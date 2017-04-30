# Copyright (C) Dominik Picheta. All rights reserved.
# MIT License. Look at license.txt for more info.
import osproc, streams, unittest, strutils, os, sequtils, future

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

test "can compile choosenim":
  cd "..":
    let (_, exitCode) = execCmdEx("nimble build")
    check exitCode == QuitSuccess

template beginTest() =
  # Clear custom dirs.
  removeDir(nimbleDir)
  createDir(nimbleDir)
  removeDir(choosenimDir)
  createDir(choosenimDir)

proc execChooseNim(args: varargs[string]): tuple[output: string, exitCode: int] =
  var quotedArgs = @args
  quotedArgs.insert(exePath)
  quotedArgs.add("--nimbleDir:" & nimbleDir)
  quotedArgs.add("--chooseNimDir:" & choosenimDir)
  quotedArgs.add("--noColor")
  quotedArgs = quoted_args.map((x: string) => ("\"" & x & "\""))

  result = execCmdEx(quotedArgs.join(" "))
  #echo(result.output)

proc processOutput(output: string): seq[string] =
  output.strip.splitLines().filter((x: string) => (x.len > 0))

proc inLines(lines: seq[string], word: string): bool =
  for i in lines:
    if word.normalize in i.normalize: return true

proc hasLine(lines: seq[string], line: string): bool =
  for i in lines:
    if i.normalize.strip() == line.normalize(): return true

test "can choose v0.16.0":
  beginTest()
  block:
    let (output, exitCode) = execChooseNim("0.16.0")
    check exitCode == QuitSuccess

    check inLines(output.processOutput, "building")
    check inLines(output.processOutput, "downloading")
    check hasLine(output.processOutput, "switched to nim 0.16.0")

  block:
    let (output, exitCode) = execChooseNim("0.16.0")
    check exitCode == QuitSuccess

    check hasLine(output.processOutput, "info: version 0.16.0 already selected")