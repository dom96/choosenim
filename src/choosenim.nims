when findExe("musl-gcc").len != 0:
  # Use musl-gcc when available
  putEnv("CC", "musl-gcc")
  switch("gcc.exe", "musl-gcc")
  switch("gcc.linkerexe", "musl-gcc")

# Statically linking everything
when not defined(OSX):
  switch("passL", "-static")

switch("define", "ssl")

when defined(windows):
  # TODO: change once issue nim#15520 is resolved
  switch("define", "noOpenSSLHacks")
  switch("dynlibOverride", "ssl-")
  switch("dynlibOverride", "crypto-")
  switch("define", "sslVersion:(")

  switch("passL", "-lws2_32")
else:
  switch("dynlibOverride", "ssl")
  switch("dynlibOverride", "crypto")
