#!/bin/sh
# Copyright 2017 Dominik Picheta and Nim developers.
#
# Licensed under the BSD-3-Clause license.
#
# This script performs some platform detection, downloads the latest version
# of choosenim and initiates its installation.

set -u
set -e

url_prefix="https://github.com/dom96/choosenim/releases/download/"

temp_prefix="${TMPDIR:-/tmp}"

CHOOSE_VERSION="${CHOOSENIM_CHOOSE_VERSION:-stable}"

need_tty=yes
debug=""

has_curl() {
  command -v curl >/dev/null 2>&1
}

has_wget() {
  command -v wget >/dev/null 2>&1
}

install() {
  get_platform || return 1
  local platform=$RET_VAL
  local stable_version=
  if has_curl; then
    stable_version=`curl -sSfL https://nim-lang.org/choosenim/stable`
  elif has_wget; then
    stable_version=`wget -qO - https://nim-lang.org/choosenim/stable`
  fi
  local filename="choosenim-$stable_version"_"$platform"
  local url="$url_prefix"v"$stable_version/$filename"
  local ext=""

  case $platform in
    *macosx_amd64* | *linux_amd64* )
      ;;
    *windows_amd64* )
      # Download ZIP for Windows
      local ext=".exe"
      local filename="$filename$ext"
      local url="$url$ext"
      ;;
    * )
      say_err "Sorry, your platform ($platform) is not supported by choosenim."
      say_err "You will need to install Nim using an alternative method."
      say_err "See the following link for more info: https://nim-lang.org/install.html"
      exit 1
      ;;
  esac

  say "Downloading $filename"
  if has_curl; then
    curl -sSfL "$url" -o "$temp_prefix/$filename"
  elif has_wget; then
    wget -qO "$temp_prefix/$filename" "$url"
  fi
  chmod +x "$temp_prefix/$filename"

  if [ "$need_tty" = "yes" ]; then
    # The installer is going to want to ask for confirmation by
    # reading stdin.  This script was piped into `sh` though and
    # doesn't have stdin to pass to its children. Instead we're going
    # to explicitly connect /dev/tty to the installer's stdin.
    if [ ! -t 1 ]; then
      err "Unable to run interactively. Run with -y to accept defaults."
    fi

    # Install Nim from desired channel.
    "$temp_prefix/$filename" $CHOOSE_VERSION --firstInstall ${debug} < /dev/tty
  else
    "$temp_prefix/$filename" $CHOOSE_VERSION --firstInstall -y ${debug}
  fi

  # Copy choosenim binary to Nimble bin.
  local nimbleBinDir=`"$temp_prefix/$filename" --getNimbleBin`
  cp "$temp_prefix/$filename" "$nimbleBinDir/choosenim$ext"
  say "ChooseNim installed in $nimbleBinDir"
  say "You must now ensure that the Nimble bin dir is in your PATH."
  if [ "$platform" != "windows_amd64" ]; then
    say "Place the following line in the ~/.profile or ~/.bashrc file."
    say "    export PATH=$nimbleBinDir:\$PATH"
    case "${SHELL:=sh}" in
      *fish*)
      say "Running fish shell?"
      say "set -ga fish_user_paths $nimbleBinDir"
    ;;
    esac
  fi
}

get_platform() {
  # Get OS/CPU info and store in a `myos` and `mycpu` variable.
  local ucpu=`uname -m`
  local uos=`uname`
  local ucpu=`echo $ucpu | tr "[:upper:]" "[:lower:]"`
  local uos=`echo $uos | tr "[:upper:]" "[:lower:]"`

  case $uos in
    *linux* )
      local myos="linux"
      ;;
    *dragonfly* )
      local myos="freebsd"
      ;;
    *freebsd* )
      local myos="freebsd"
      ;;
    *openbsd* )
      local myos="openbsd"
      ;;
    *netbsd* )
      local myos="netbsd"
      ;;
    *darwin* )
      local myos="macosx"
      if [ "$HOSTTYPE" = "x86_64" ] ; then
        local ucpu="amd64"
      fi
      if [ "$HOSTTYPE" = "arm64" ] ; then
        # TODO: We don't have arm binaries for choosenim so far, rely on Rosetta.
        local ucpu="amd64"
      fi
      ;;
    *aix* )
      local myos="aix"
      ;;
    *solaris* | *sun* )
      local myos="solaris"
      ;;
    *haiku* )
      local myos="haiku"
      ;;
    *mingw* | *msys* )
      local myos="windows"
      ;;
    *)
      err "unknown operating system: $uos"
      ;;
  esac

  case $ucpu in
    *i386* | *i486* | *i586* | *i686* | *bepc* | *i86pc* )
      local mycpu="i386" ;;
    *amd*64* | *x86-64* | *x86_64* )
      local mycpu="amd64" ;;
    *sparc*|*sun* )
      local mycpu="sparc"
      if [ "$(isainfo -b)" = "64" ]; then
        local mycpu="sparc64"
      fi
      ;;
    *ppc64* )
      local mycpu="powerpc64" ;;
    *power*|*ppc* )
      local mycpu="powerpc" ;;
    *mips* )
      local mycpu="mips" ;;
    *arm*|*armv6l* )
      local mycpu="arm" ;;
    *aarch64* )
      local mycpu="arm64" ;;
    *)
      err "unknown processor: $ucpu"
      ;;
  esac

  RET_VAL="$myos"_"$mycpu"
}

say() {
  echo "choosenim-init: $1"
}

say_err() {
  say "Error: $1" >&2
}

err() {
  say_err "$1"
  exit 1
}


# check if we have to use /dev/tty to prompt the user
while getopts "dy" opt; do
  case "$opt" in
    y) need_tty=no
       ;;
    d) debug="--debug"
  esac
done

install
