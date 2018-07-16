@echo off

rem Compile using $DMD if it exists, otherwise use dmd
if "%DMD%" == "" set DMD=dmd

echo DMD=%DMD%
%DMD% -ofci_script_bin ci_script.d && ci_script_bin %*
