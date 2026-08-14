@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

if defined XILINX_VIVADO (
  if exist "%XILINX_VIVADO%\settings64.bat" call "%XILINX_VIVADO%\settings64.bat" & goto :ready
)
for %%V in (2024.2 2024.1 2023.2 2023.1) do (
  if exist "C:\Xilinx\Vivado\%%V\settings64.bat" (
    call "C:\Xilinx\Vivado\%%V\settings64.bat"
    goto :ready
  )
)
echo ERROR: Vivado settings64.bat not found.
exit /b 1

:ready
vivado -mode batch -source "%SCRIPT_DIR%program.tcl" %*
exit /b %ERRORLEVEL%
