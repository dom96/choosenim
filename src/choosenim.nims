when defined(macosx):
  switch("define", "curl")
elif not defined(windows):
  switch("define", "curl")
else:
  switch("define", "ssl")

when defined(staticBuild):
  import "choosenimpkg/proxyexe.nims"
