import nimblepkg/common

type
  ChooseNimError* = object of NimbleError

const
  chooseNimVersion* = "0.3.2"

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