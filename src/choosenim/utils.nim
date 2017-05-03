import os, strutils

import nimblepkg/[cli, tools, version]
import untar

import switcher, common

proc extract*(path: string, extractDir: string) =
  display("Extracting", path.extractFilename(), priority = HighPriority)
  try:
    var file = newTarFile(path)
    file.extract(extractDir)
  except Exception as exc:
    raise newException(ChooseNimError, "Unable to extract. Error was '$1'." %
                       exc.msg)