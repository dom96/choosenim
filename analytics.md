# Anonymous gathering of user analytics

Starting with version 0.3.0, choosenim has the ability to gather anonymous
aggregate user behaviour analytics and to report them to Google Analytics.

This is entirely optional and is "opt-neutral", that is choosenim will
ask you to decide whether you want to participate in this data gathering
without offering a default option. You must choose.

## Why?

This is the most straightforward way to gather information about Nim's users
directly. It allows us to be aware of the platforms where Nim is being used
and any installation issues that our users are facing.

Overall the data we collect allows us to prioritise fixes and features based on
how people are using choosenim. For example:

* If there is a high exception count on specific platforms, we can prioritise
fixing it for the next release.
* Collecting the OS version allows us to decide which platforms to prioritise
and support.

## What is collected?

At a high level we currently collect a number of events, exception counts and
build and download timings.

To be more specific, we record the following information:

* OS information, for example: ``Mac OS X v10.11 El Capitan`` or
  ``Linux 4.11.6-041106-generic x86_64``.
* The command-line arguments passed to choosenim, for example
  ``choosenim --nimbleDir:~/myNimbleDir stable``.
* Events when a build is started, when it fails and when it succeeds.
* Build time in seconds and download time in seconds (including the
  URL that was downloaded).
* The choosenim version.

For each user a new UUID is generated so there is no way for us or Google
to identify you. The UUID is used to measure user counts.

## Where is the data sent?

The recorded data is sent to Google Analytics over HTTPS.

## Who has access?

The analytics are currently only accessible to the maintainers of choosenim.
At the minute this only includes @dom96.

Summaries of the data may be released in the future to the public.

## Where is the code?

The code is viewable in [telemetry.nim](https://github.com/dom96/choosenim/blob/master/src/choosenim/telemetry.nim).

The reporting is done asynchronously and will fail fast to avoid any
delay in execution.

## Opting out

Choosenim analytics help us and leaving them on is appreciated. However,
we understand if you don't feel comfortable having them on.

To opt out simply answer "no" or "n" to the following question:

```
Prompt: Can choosenim record and send anonymised telemetry data? [y/n]
    ... Anonymous aggregate user analytics allow us to prioritise
    ... fixes and features based on how, where and when people use Nim.
    ... For more details see: https://goo.gl/NzUEPf.
Answer:
```

You can also set the ``CHOOSENIM_NO_ANALYTICS`` variable in your environment:

```
export CHOOSENIM_NO_ANALYTICS=1
```
