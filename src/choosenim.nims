when defined(linux):
  switch("passL", "-lpthread")
elif defined(windows):
  switch("passL", "-lws2_32")

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
