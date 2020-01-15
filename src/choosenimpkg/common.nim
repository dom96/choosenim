import nimblepkg/version

type
  ChooseNimError* = object of NimbleError

const
  chooseNimVersion* = "0.5.1"

  proxies* = [
      "nim",
      "nimble",
      "nimgrep",
      "nimpretty",
      "nimsuggest",
      "testament"
    ]

  mingwProxies* = [
    "gcc",
    "g++",
    "gdb",
    "ld"
  ]
