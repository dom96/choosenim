when defined(macosx):
  switch("define", "curl")
else:
  switch("define", "ssl")

when hostCPU in ["i386", "amd64"]:
  switch("define", "x86")
