when defined(staticBuild):
  when defined(linux):
    putEnv("CC", "musl-gcc")
    switch("gcc.exe", "musl-gcc")
    switch("gcc.linkerexe", "musl-gcc")
  when not defined(OSX):
    switch("passL", "-static")
