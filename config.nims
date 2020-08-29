when defined(macosx):
  switch("define", "curl")
else:
  switch("define", "ssl")
