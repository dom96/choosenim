## This module implements information about release channels.
##
## In the future these may become configurable.

import strutils, tables, os

import nimblepkg/version

import download, cliparams, switcher

let
  channels = {
    "stable": "http://nim-lang.org/channels/stable",
    "devel": "#devel"
  }.toTable()

proc isReleaseChannel*(command: string): bool =
  return command in channels

proc getChannelVersion*(channel: string, params: CliParams,
                        live=false): string =
  if not isReleaseChannel(channel):
    # Assume that channel is a version.
    return channel

  if not live:
    # Check for pinned version.
    let filename = params.getChannelsDir() / channel
    if fileExists(filename):
      return readFile(filename).strip()

  # Grab version from website or the hash table.
  let value = channels[channel]
  if value.startsWith("http"):
    # TODO: Better URL detection?
    return retrieveUrl(value).strip()
  else:
    return value

proc pinChannelVersion*(channel: string, version: string, params: CliParams) =
  ## Assigns the specified version to the specified channel. This is done
  ## so that choosing ``stable`` won't install a new version (when it is
  ## released) until the ``update`` command is used.
  createDir(params.getChannelsDir())

  writeFile(params.getChannelsDir() / channel, version)

proc canUpdate*(version: Version, params: CliParams): bool =
  ## Determines whether this version can be updated.
  if version.isSpecial:
    return true

  return not isVersionInstalled(params, version)

proc setCurrentChannel*(channel: string, params: CliParams) =
  writeFile(params.getCurrentChannelFile(), channel)

proc getCurrentChannel*(params: CliParams): string =
  if not fileExists(params.getCurrentChannelFile()):
    return ""
  return readFile(params.getCurrentChannelFile()).strip()