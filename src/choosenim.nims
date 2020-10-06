when findExe("musl-gcc").len != 0:
  # Use musl-gcc when available
  putEnv("CC", "musl-gcc")
  switch("gcc.exe", "musl-gcc")
  switch("gcc.linkerexe", "musl-gcc")

# Statically linking everything
when not defined(OSX):
  switch("passL", "-static")
switch("define", "ssl")
switch("dynlibOverride", "ssl")
switch("dynlibOverride", "crypto")
