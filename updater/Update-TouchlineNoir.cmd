@echo off
setlocal
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules;%PSModulePath%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-TouchlineNoir.ps1" %*
set "noir_result=%errorlevel%"
if not "%NOIR_NO_PAUSE%"=="1" pause
exit /b %noir_result%
