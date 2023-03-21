setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat"

set target=targets\win32\x86
set root=mbedtls
set build=%root%\build\win32-x86\
set pwd=%~dp0

if /I [%1] == [rebuild] (
	rd /q /s %build%
)

if not exist %build% (
	mkdir %build%
	cd %build%
	cmake %pwd%\%root% -A Win32 -DENABLE_TESTING=OFF -DENABLE_PROGRAMS=OFF
) else (
	cd %build%
)

if /I [%1] == [rebuild] (
	set option="-t:Rebuild"
)

msbuild "Mbed TLS.sln" -p:Configuration=Release -p:Platform=Win32 %option%

cd %pwd%
if exist %target% (
	del %target%\*.lib
)

robocopy %build%\library\Release %target% *.lib /NDL /NJH /NJS /nc /ns /np
REM robocopy %build%\lib\Debug %target% *.lib /NDL /NJH /NJS /nc /ns /np
for %%f in (%target%\*.lib) do ren %%f lib%%~nf.lib
lib.exe /OUT:%target%/libmedtls_.lib %target%/*.lib

robocopy mbedtls\include targets\include *.h /NDL /NJH /NJS /nc /ns /np


endlocal

