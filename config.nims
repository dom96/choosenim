const target {.strdefine: "zig.target".} = ""
if target != "":
  switch("cc", "clang")
  let zigCmd = "zigcc" & (if defined(windows): ".cmd" else: "")
  switch("clang.exe", zigCmd)
  switch("clang.linkerexe", zigCmd)
  let targetArgs = "-target " & target
  switch("passL", targetArgs)
  switch("passC", targetArgs)

  when defined(macosx):
    # We need to define extra search paths
    # Found via the default paths here
    # https://discussions.apple.com/thread/2390561?sortBy=best#11330927022
    switch("passL", "-F/Library/Frameworks -F/System/Library/Frameworks -F/System/Library/Frameworks/Security.framework -L/usr/lib -L/usr/local/lib")
    switch("passL", "--sysroot=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk")

switch("d", "zippyNoSimd")
