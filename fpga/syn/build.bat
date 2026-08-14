@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =============================================================================
REM Open Spec — Windows build launcher
REM
REM Hardware stages (Vivado):
REM   build.bat synth        Synthesis only
REM   build.bat route        Synth + place/route (no bitstream)
REM   build.bat bitstream    Through write_bitstream (+ .bit copy)
REM   build.bat all          Bitstream + export .xsa + Vitis software  (default)
REM   build.bat full         Same as all
REM
REM Software only (needs existing build\hdmi_in.xsa):
REM   build.bat software
REM
REM Clean:
REM   build.bat clean              Wipe Vivado/Vitis build products, then full build
REM   build.bat clean synth        Wipe, then synth only
REM   build.bat clean_only         Wipe only (no rebuild)
REM
REM Optional env:
REM   DIGILENT_IP_REPO, XILINX_VIVADO, XILINX_VITIS
REM =============================================================================

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

set "FPGA_DIR=%SCRIPT_DIR%.."
for %%I in ("%FPGA_DIR%") do set "FPGA_DIR=%%~fI"

set "DEFAULT_IP_REPO=%FPGA_DIR%\deps\vivado-library"
set "DIGILENT_GIT_URL=https://github.com/Digilent/vivado-library.git"
set "SW_DIR=%FPGA_DIR%\z7_build\sw"
set "BUILD_DIR=%SCRIPT_DIR%build"
set "XSA_PATH=%BUILD_DIR%\hdmi_in.xsa"

REM ---- parse args ----
set "DO_CLEAN=0"
set "CLEAN_ONLY=0"
set "STAGE=all"
set "VIVADO_ARGS="

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="clean" (
  REM Wipe locally; do not pass "clean" to Vivado (project already gone)
  set "DO_CLEAN=1"
  shift & goto parse_args
)
if /i "%~1"=="clean_only" (
  set "CLEAN_ONLY=1"
  shift & goto parse_args
)
if /i "%~1"=="synth" (
  set "STAGE=synth"
  set "VIVADO_ARGS=!VIVADO_ARGS! synth"
  shift & goto parse_args
)
if /i "%~1"=="skip_impl" (
  set "STAGE=synth"
  set "VIVADO_ARGS=!VIVADO_ARGS! synth"
  shift & goto parse_args
)
if /i "%~1"=="route" (
  set "STAGE=route"
  set "VIVADO_ARGS=!VIVADO_ARGS! route"
  shift & goto parse_args
)
if /i "%~1"=="bitstream" (
  set "STAGE=bitstream"
  set "VIVADO_ARGS=!VIVADO_ARGS! bitstream"
  shift & goto parse_args
)
if /i "%~1"=="all" (
  set "STAGE=all"
  set "VIVADO_ARGS=!VIVADO_ARGS! all"
  shift & goto parse_args
)
if /i "%~1"=="full" (
  set "STAGE=all"
  set "VIVADO_ARGS=!VIVADO_ARGS! all"
  shift & goto parse_args
)
if /i "%~1"=="software" (
  set "STAGE=software"
  shift & goto parse_args
)
echo WARNING: unknown arg '%~1' ^(ignored^)
shift & goto parse_args
:args_done

if "%VIVADO_ARGS%"=="" if /i not "%STAGE%"=="software" set "VIVADO_ARGS=all"

echo ============================================================
echo  Open Spec build  stage=%STAGE%  clean=%DO_CLEAN%
echo ============================================================

if "%CLEAN_ONLY%"=="1" goto do_clean_only
if "%DO_CLEAN%"=="1" call :wipe_build_products

if /i "%STAGE%"=="software" goto software_only

REM -----------------------------------------------------------------------------
REM Digilent IP + Vivado
REM -----------------------------------------------------------------------------
if not defined DIGILENT_IP_REPO set "DIGILENT_IP_REPO=%DEFAULT_IP_REPO%"

echo.
echo [hw] Checking Digilent vivado-library ...
call :ensure_digilent_repo
if errorlevel 1 exit /b 1
echo [OK] Digilent IP repo: %DIGILENT_IP_REPO%

where python >nul 2>&1
if errorlevel 1 (
  echo ERROR: python not found on PATH.
  exit /b 1
)

echo       Patching Digilent rgb2dvi overlays ...
python "%SCRIPT_DIR%patch_digilent_ip.py" --repo "%DIGILENT_IP_REPO%" --project "%SCRIPT_DIR%build\open_spec"
if errorlevel 1 (
  echo ERROR: Digilent IP patch failed.
  exit /b 1
)

call :setup_vivado
if errorlevel 1 exit /b 1
echo [OK] Vivado ready

echo.
echo [hw] Generating VHDL sources ...
python "%SCRIPT_DIR%gen_vhdl_sources.py" --src "%FPGA_DIR%\src" --out "%SCRIPT_DIR%vhdl_sources.tcl"
if errorlevel 1 exit /b 1

echo.
echo [hw] Running Vivado stage=%STAGE% ...
vivado -mode batch -source "%SCRIPT_DIR%build.tcl" -tclargs %VIVADO_ARGS%
if errorlevel 1 (
  echo.
  echo VIVADO BUILD FAILED
  exit /b 1
)

if /i "%STAGE%"=="synth" goto hw_done
if /i "%STAGE%"=="route" goto hw_done
if /i "%STAGE%"=="bitstream" goto hw_done

REM STAGE=all -> continue to software
goto software_only

:hw_done
echo.
echo ============================================================
echo  HARDWARE STAGE COMPLETE ^(%STAGE%^)
echo  Project:   "%BUILD_DIR%\open_spec"
echo  Bitstream: "%BUILD_DIR%\hdmi_in.bit"   ^(if built^)
echo ============================================================
exit /b 0

REM -----------------------------------------------------------------------------
REM Vitis software
REM -----------------------------------------------------------------------------
:software_only
if not exist "%XSA_PATH%" (
  echo ERROR: XSA not found: %XSA_PATH%
  echo Run: build.bat all   ^(or build.bat bitstream then export via all^)
  echo Note: stage "bitstream" does not export XSA; use "all" for software.
  exit /b 1
)
if not exist "%SW_DIR%\" (
  echo ERROR: software sources not found: %SW_DIR%
  exit /b 1
)

call :setup_vitis
if errorlevel 1 exit /b 1
echo [OK] Vitis ready

echo.
echo [sw] Building Vitis app from %SW_DIR% ...
REM Args after -- are forwarded to the Python script
vitis -s "%SCRIPT_DIR%build_vitis.py" -- --xsa "%XSA_PATH%" --sw "%SW_DIR%" --workspace "%BUILD_DIR%\vitis_ws"
if errorlevel 1 (
  echo.
  echo VITIS BUILD FAILED
  exit /b 1
)

echo.
echo ============================================================
echo  BUILD COMPLETE
echo  Bitstream: "%BUILD_DIR%\hdmi_in.bit"
echo  XSA:       "%XSA_PATH%"
echo  ELF:       "%BUILD_DIR%\video_demo.elf"
echo  Vitis WS:  "%BUILD_DIR%\vitis_ws"
echo ============================================================
exit /b 0

:do_clean_only
call :wipe_build_products
echo Clean complete.
exit /b 0

REM =============================================================================
REM Subroutines
REM =============================================================================

:wipe_build_products
echo Wiping build products under "%BUILD_DIR%" ...
if exist "%BUILD_DIR%\" rmdir /s /q "%BUILD_DIR%"
del /q "%SCRIPT_DIR%vivado.log" 2>nul
del /q "%SCRIPT_DIR%vivado.jou" 2>nul
del /q "%SCRIPT_DIR%vhdl_sources.tcl" 2>nul
if exist "%SCRIPT_DIR%.Xil\" rmdir /s /q "%SCRIPT_DIR%.Xil"
exit /b 0

:ensure_digilent_repo
if exist "%DIGILENT_IP_REPO%\ip\" (
  call :check_required_ips
  exit /b %ERRORLEVEL%
)
if exist "%DIGILENT_IP_REPO%\" (
  echo ERROR: %DIGILENT_IP_REPO% exists but does not look like vivado-library
  exit /b 1
)
echo       Not found — cloning into: %DIGILENT_IP_REPO%
where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: git not found on PATH.
  exit /b 1
)
for %%I in ("%DIGILENT_IP_REPO%") do set "IP_PARENT=%%~dpI"
if not exist "%IP_PARENT%" mkdir "%IP_PARENT%"
git clone --depth 1 "%DIGILENT_GIT_URL%" "%DIGILENT_IP_REPO%"
if errorlevel 1 exit /b 1
call :check_required_ips
exit /b %ERRORLEVEL%

:check_required_ips
set "MISSING="
if not exist "%DIGILENT_IP_REPO%\ip\dvi2rgb\" set "MISSING=!MISSING! dvi2rgb"
if not exist "%DIGILENT_IP_REPO%\ip\rgb2dvi\" set "MISSING=!MISSING! rgb2dvi"
if not exist "%DIGILENT_IP_REPO%\ip\axi_dynclk\" set "MISSING=!MISSING! axi_dynclk"
if defined MISSING (
  echo ERROR: Digilent repo missing IP folder^(s^):!MISSING!
  exit /b 1
)
exit /b 0

:setup_vivado
if defined XILINX_VIVADO if exist "%XILINX_VIVADO%\settings64.bat" (
  call "%XILINX_VIVADO%\settings64.bat"
  exit /b 0
)
for %%V in (2024.2 2024.1 2023.2 2023.1) do (
  if exist "C:\Xilinx\Vivado\%%V\settings64.bat" (
    echo Using C:\Xilinx\Vivado\%%V\settings64.bat
    call "C:\Xilinx\Vivado\%%V\settings64.bat"
    exit /b 0
  )
)
echo ERROR: Vivado settings64.bat not found
exit /b 1

:setup_vitis
if defined XILINX_VITIS if exist "%XILINX_VITIS%\settings64.bat" (
  call "%XILINX_VITIS%\settings64.bat"
  exit /b 0
)
for %%V in (2024.2 2024.1 2023.2 2023.1) do (
  if exist "C:\Xilinx\Vitis\%%V\settings64.bat" (
    echo Using C:\Xilinx\Vitis\%%V\settings64.bat
    call "C:\Xilinx\Vitis\%%V\settings64.bat"
    exit /b 0
  )
)
echo ERROR: Vitis settings64.bat not found
exit /b 1
