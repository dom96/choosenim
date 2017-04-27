import os
let
  chooseNimDir = getHomeDir() / ".choosenim"

proc getDownloadDir*(): string =
  return chooseNimDir / "downloads"

proc getInstallDir*(): string =
  return chooseNimDir / "toolchains"

proc getBinDir*(): string =
  # TODO: Grab this from Nimble's config.
  return getHomeDir() / ".nimble" / "bin"

proc getCurrentFile*(): string =
  ## Returns the path to the file which specifies the currently selected
  ## installation. The contents of this file is a path to the selected Nim
  ## directory.
  return chooseNimDir / "current"