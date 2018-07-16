@echo off

rem Don't use unit-threaded on AppVeyor. I can't get it to work there.
set NO_UT=true

rem Compile using $DMD if it exists, otherwise use dmd
if "%DMD%" == "" set DMD=dmd

echo DMD=%DMD%
%DMD% -ofci_script_bin ci_script.d && ci_script_bin %*
