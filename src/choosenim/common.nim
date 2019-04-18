import nimblepkg/common

type
  ChooseNimError* = object of NimbleError

const
  chooseNimVersion* = "0.4.0"

  proxies* = [
      "nim",
      "nimble",
      "nimgrep",
      "nimpretty",
      "nimsuggest"
    ]

  mingwProxies* = [
    "gcc",
    "g++",
    "gdb",
    "ld"
  ]