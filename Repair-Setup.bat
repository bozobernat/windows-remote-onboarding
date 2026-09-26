@echo off
REM PAO - a tipikus elromlasok javitasa (fokent a szerver cime).
REM Hasznalat: jobbklikk erre a fajlra -> "Futtatas rendszergazdakent".
setlocal
pushd "%~dp0" 2>nul
if not exist "%~dp0Setup-PaoRemote.ps1" (
  echo.
  echo   NEM TALALOM a Setup-PaoRemote.ps1-et itt: %~dp0
  echo.
  echo   A leggyakoribb ok: ez a mappa halozati meghajton ^(pl. Z:^) van, es a
  echo   "Futtatas rendszergazdakent" emelt jogu munkamenete NEM latja a
  echo   lekepezett meghajtokat. Ez Windows-alapbeallitas, nem hiba.
  echo.
  echo   MEGOLDAS: masold az EGESZ mappat a gepre ^(pl. az asztalra^), es
  echo   onnan inditsd. Tavoli gepnel amugy is igy visszuk.
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-PaoRemote.ps1" -Repair
popd 2>nul
echo.
pause
