import nimblepkg/version

type
  ChooseNimError* = object of NimbleError

const
  chooseNimVersion* = "0.7.0"

  proxies* = [
      "nim",
      "nimble",
      "nimgrep",
      "nimpretty",
      "nimsuggest",
      "testament",
      "nim-gdb",
    ]

  mingwProxies* = [
    "gcc",
    "g++",
    "gdb",
    "ld"
  ]
