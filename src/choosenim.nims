when defined(macosx):
  switch("define", "curl")
elif not defined(windows):
  switch("define", "curl")

when defined(staticBuild):
  import "choosenimpkg/proxyexe.nims"

# We don't need it, but nimble does for SslError import
switch("define", "ssl")
