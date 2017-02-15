import os
const
  pickNimDir = getHomeDir() / ".picknim"

proc getDownloadDir*(): string =
  return pickNimDir / "downloads"

proc getInstallDir*(): string =
  return pickNimDir / "toolchains"