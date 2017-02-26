import os

import nimblepkg/[cli, tools, version]
import untar

import switcher

proc extract*(path: string, extractDir: string) =
  display("Extracting", path.extractFilename(), priority = HighPriority)
  var file = newTarFile(path)
  removeDir(extractDir)
  file.extract(extractDir)