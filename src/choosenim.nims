switch("define", "ssl")

when defined(windows):
  # TODO: change once issue nim#15220 is resolved
  switch("define", "noOpenSSLHacks")
  switch("dynlibOverride", "ssl-")
  switch("dynlibOverride", "crypto-")
  switch("define", "sslVersion:(")
else:
  switch("dynlibOverride", "ssl")
  switch("dynlibOverride", "crypto")

when defined(staticBuild):
  import "choosenimpkg/proxyexe.nims"
