when defined(macosx):
  switch("define", "curl")

when defined(staticBuild):
  import "choosenimpkg/proxyexe.nims"
