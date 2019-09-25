import distros

when detectOs(Ubuntu, Debian):
  foreignDep "build-essential"
when detectOS(Alpine):
  foreignDep "build-base"
when detectOs(MacOSX):
  foreignCmd "xcode-select --install"
