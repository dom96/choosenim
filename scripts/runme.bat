@echo off
.\choosenim\choosenim.exe stable --firstInstall

for /f "delims=" %%a in ('.\choosenim\choosenim.exe --getNimbleBin') do @set NIMBLEBIN=%%a
copy .\choosenim\choosenim.exe "%NIMBLEBIN%\choosenim.exe"

echo             Work finished.
echo             Now you must ensure that the Nimble bin dir is in your PATH:
echo               %NIMBLEBIN%

pause