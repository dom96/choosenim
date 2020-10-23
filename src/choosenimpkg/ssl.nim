{.used}

import strutils

import nimterop/build

# Download openssl from JuliaBinaryWrappers
setDefines(@[
  "cryptoJBB", "cryptoStatic"
])

getHeader(
  "crypto.h",
  jbburi = "openssl",
  outdir = getProjectCacheDir("nimopenssl")
)

const
  sslLPath = cryptoLPath.replace("crypto", "ssl")

# Link static binaries
{.passL: sslLPath & " " & cryptoLPath.}

# Deps for openssl
when defined(linux):
  {.passL: "-lpthread".}
elif defined(windows):
  {.passL: "-lws2_32".}
