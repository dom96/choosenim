import os
const
  pickNimDir = getHomeDir() / ".picknim"

proc getDownloadDir*(): string =
  return pickNimDir / "downloads"

proc getInstallDir*(): string =
  return pickNimDir / "toolchains"

proc getBinDir*(): string =
  # TODO: Grab this from Nimble's config.
  return getHomeDir() / ".nimble" / "bin"

proc getCurrentFile*(): string =
  ## Returns the path to the file which specifies the currently selected
  ## installation. The contents of this file is a path to the selected Nim
  ## directory.
  return pickNimDir / "current"