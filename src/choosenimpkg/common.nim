import nimblepkg/version

type
  ChooseNimError* = object of NimbleError

const
  chooseNimVersion* = "0.8.4"

  proxies* = [
      "nim",
      "nimble",
      "nimgrep",
      "nimpretty",
      "nimsuggest",
      "testament",
      "nim-gdb",
      "atlas"
    ]

  mingwProxies* = [
    "gcc",
    "g++",
    "gdb",
    "ld"
  ]
