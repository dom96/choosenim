# Copyright (C) Dominik Picheta. All rights reserved.
# BSD-3-Clause License. Look at license.txt for more info.

import os, strutils, options, times

import analytics, nimblepkg/cli

import cliparams, common

type
  EventCategory* = enum
    ActionEvent,
    BuildEvent, BuildSuccessEvent, BuildFailureEvent,
    ErrorEvent

  Event* = object
    category*: EventCategory
    action*: string
    label*: string
    value*: Option[int]

  # TODO: Download time
  TimingCategory* = enum
    BuildSuccessTime, BuildFailureTime

  Timing* = object
    category*: TimingCategory
    name*: string
    time*: int
    label*: string

proc promptCustom(msg: string, params: CliParams): string =
  if params.nimbleOptions.forcePrompts == forcePromptYes:
    display("Prompt:", msg, Warning, HighPriority)
    display("Answer:", "Forced Yes", Warning, HighPriority)
    return "y"
  else:
    return promptCustom(msg, "")

proc analyticsPrompt(params: CliParams) =
  let msg = ("Can choosenim record and send anonymised telemetry " &
             "data? [y/n]\n" &
             "Anonymous aggregate user analytics allow us to prioritise\n" &
             "fixes and features based on how, where and when people " &
             "use Nim.\n" &
             "For more details see: https://goo.gl/bJY3qA.")

  let resp = promptCustom(msg, params)
  let analyticsFile = params.getAnalyticsFile()
  case resp.normalize
  of "y", "yes":
    let clientID = analytics.genClientID()
    writeFile(analyticsFile, clientID)
    display("Info:", "Your client ID is " & clientID, priority=LowPriority)
  of "n", "no":
    # Write an empty file to signify that the user answered "No".
    writeFile(analyticsFile, "")
    return
  else:
    # Force the user to answer.
    analyticsPrompt(params)

proc loadAnalytics*(params: CliParams) =
  if params.isNil:
    raise newException(ValueError, "Params is nil.")

  if not params.analytics.isNil:
    return

  let analyticsFile = params.getAnalyticsFile()
  if not fileExists(analyticsFile):
    params.analyticsPrompt()

  let clientID = readFile(analyticsFile)
  if clientID.len == 0:
    display("Info:",
            "No client ID found in '$1', not sending analytics." %
              analyticsFile,
            priority=LowPriority)
    return

  params.analytics = newAnalytics("UA-105812497-2", clientID, "choosenim",
                                  chooseNimVersion)

proc initEvent*(category: EventCategory, action="", label="",
                value=none(int)): Event =
  let cmd = "choosenim " & commandLineParams().join(" ")
  return Event(category: category,
               action: if action.len == 0: cmd else: action,
               label: label, value: value)

proc initTiming*(category: TimingCategory, name: string, startTime: float,
                 label=""): Timing =
 ## The `startTime` is the Unix epoch timestamp for when the timing started
 ## (from `epochTime`).
 ## This function will automatically calculate the elapsed time based on that.
 let elapsed = int((epochTime() - startTime)*1000)
 return Timing(category: category,
               name: name,
               label: label, time: elapsed)

proc report*(obj: Event | Timing | ref Exception, params: CliParams) =
  try:
    loadAnalytics(params)
  except Exception as exc:
    display("Warning:", "Could not load analytics reporter due to error:" &
            exc.msg, Warning, MediumPriority)
    return

  try:
    # TODO: Run in separate thread.
    when obj is Event:
      params.analytics.reportEvent($obj.category, obj.action, obj.label,
                                   obj.value)
    elif obj is Timing:
      params.analytics.reportTiming($obj.category, obj.name, obj.time,
                                    obj.label)
    else:
      params.analytics.reportException(obj.msg)

  except Exception as exc:
    display("Warning:", "Could not report to analytics due to error:" &
            exc.msg, Warning, MediumPriority)

