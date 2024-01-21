const target {.strdefine: "zig.target".} = ""
if target != "":
  switch("cc", "clang")
  let zigCmd = "zigcc" & (if defined(windows): ".cmd" else: "")
  switch("clang.exe", zigCmd)
  switch("clang.linkerexe", zigCmd)
  let targetArgs = "-target " & target
  switch("passL", targetArgs)
  switch("passC", targetArgs)
