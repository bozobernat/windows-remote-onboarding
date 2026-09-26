@echo off
REM PAO - a tavtamogatas TELJES eltavolitasa errol a geprol.
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
echo.
echo   Ez eltavolitja a PAO tavtamogatast errol a geprol.
echo.
choice /C IN /N /M "  Biztosan? (I = igen, N = nem): "
if errorlevel 2 goto vege
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-PaoRemote.ps1" -Uninstall
:vege
popd 2>nul
echo.
pause
