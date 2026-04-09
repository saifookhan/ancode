@echo off
setlocal
set "FLUTTER_ROOT=C:\Users\DCL\.puro\envs\stable\flutter"
set "PUB_CACHE=C:\Users\DCL\AppData\Local\Pub\Cache"
set "MSYSTEM="
set "MSYSTEM_PREFIX="
set "MINGW_PREFIX="
set "MSYS_NO_PATHCONV=1"
set "MSYS2_ARG_CONV_EXCL=*"

REM --no-web-resources-cdn: serve CanvasKit/fonts locally so startup does not hang when CDN is blocked/slow (fixes stuck "Caricamento" in index.html).
set "FLUTTER_ARGS=-d chrome --release --no-web-resources-cdn"
if /I "%~1"=="debug" set "FLUTTER_ARGS=-d chrome --no-web-resources-cdn"

if exist "%FLUTTER_ROOT%\bin\flutter.bat" (
  call "%FLUTTER_ROOT%\bin\flutter.bat" run %FLUTTER_ARGS%
) else (
  flutter run %FLUTTER_ARGS%
)
