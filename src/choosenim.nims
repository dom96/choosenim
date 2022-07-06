when defined(macosx):
  switch("define", "curl")
  switch("passC","-arch arm64 -arch x86_64")
  switch("passL","-arch arm64 -arch x86_64")
elif not defined(windows):
  switch("define", "curl")

when defined(staticBuild):
  import "choosenimpkg/proxyexe.nims"
