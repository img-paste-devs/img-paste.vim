@echo off
powershell -ep bypass -File "%~dp0\%~n0.ps1" %1
pause