import nimblepkg/common

type
  ChooseNimError* = object of NimbleError

const
  chooseNimVersion* = "0.3.0"

  proxies* = [
      "nim",
      "nimble",
      "nimgrep",
      "nimsuggest"
    ]

  mingwProxies* = [
    "gcc",
    "g++",
    "gdb",
    "ld"
  ]