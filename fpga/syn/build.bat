@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =============================================================================
REM Open Spec — one-shot Windows build
REM   1) Ensure Digilent vivado-library is present (clone if missing)
REM   2) Generate VHDL source list from fpga\src
REM   3) Run Vivado batch synth / impl / bitstream
REM
REM Usage:
REM   build.bat              Incremental build (reuse BD / PS / OOC)
REM   build.bat skip_impl    Stop after synthesis
REM   build.bat clean        Wipe project then full rebuild
REM   build.bat clean skip_impl
REM
REM Optional env overrides:
REM   DIGILENT_IP_REPO   Path to an existing Digilent vivado-library checkout
REM   XILINX_VIVADO      Vivado install root (contains settings64.bat)
REM =============================================================================

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

set "FPGA_DIR=%SCRIPT_DIR%.."
for %%I in ("%FPGA_DIR%") do set "FPGA_DIR=%%~fI"

set "DEFAULT_IP_REPO=%FPGA_DIR%\deps\vivado-library"
set "DIGILENT_GIT_URL=https://github.com/Digilent/vivado-library.git"

echo ============================================================
echo  Open Spec full build
echo ============================================================

REM -----------------------------------------------------------------------------
REM 1) Digilent IP library
REM -----------------------------------------------------------------------------
if not defined DIGILENT_IP_REPO set "DIGILENT_IP_REPO=%DEFAULT_IP_REPO%"

echo.
echo [1/3] Checking Digilent vivado-library ...
call :ensure_digilent_repo
if errorlevel 1 exit /b 1
echo [OK] Digilent IP repo: %DIGILENT_IP_REPO%

echo       Patching Digilent rgb2dvi/dvi2rgb (entity work -> xil_defaultlib)...
python "%SCRIPT_DIR%patch_digilent_ip.py" --repo "%DIGILENT_IP_REPO%" --project "%SCRIPT_DIR%build\open_spec"
if errorlevel 1 (
  echo ERROR: Digilent IP patch failed.
  exit /b 1
)

REM -----------------------------------------------------------------------------
REM 2) Tool checks + VHDL list
REM -----------------------------------------------------------------------------
where python >nul 2>&1
if errorlevel 1 (
  echo ERROR: python not found on PATH.
  exit /b 1
)

call :setup_vivado
if errorlevel 1 exit /b 1
echo [OK] Vivado ready

echo.
echo [2/3] Generating VHDL sources from fpga\src ...
python "%SCRIPT_DIR%gen_vhdl_sources.py" --src "%FPGA_DIR%\src" --out "%SCRIPT_DIR%vhdl_sources.tcl"
if errorlevel 1 (
  echo ERROR: VHDL source generation failed.
  exit /b 1
)
echo [OK] Wrote %SCRIPT_DIR%vhdl_sources.tcl

REM -----------------------------------------------------------------------------
REM 3) Vivado build
REM -----------------------------------------------------------------------------
echo.
echo [3/3] Running Vivado batch build ...
REM Do NOT use -nolog/-nojournal: OOC IP runs inherit that and write broken
REM rundef.js (empty -log/-source), then fail with Coretcl 2-1982 ("Provided: Vivado").
vivado -mode batch -source "%SCRIPT_DIR%build.tcl" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo BUILD FAILED ^(exit %RC%^)
  exit /b %RC%
)

echo.
echo ============================================================
echo  BUILD COMPLETE
echo  Bitstream: "%SCRIPT_DIR%build\hdmi_in.bit"
echo  Program:   program.bat
echo ============================================================
exit /b 0

REM =============================================================================
REM Subroutines
REM =============================================================================

:ensure_digilent_repo
if exist "%DIGILENT_IP_REPO%\ip\" (
  call :check_required_ips
  exit /b %ERRORLEVEL%
)

if exist "%DIGILENT_IP_REPO%\" (
  echo ERROR: %DIGILENT_IP_REPO% exists but does not look like vivado-library
  echo        ^(expected an ip\ folder containing dvi2rgb, rgb2dvi, axi_dynclk^).
  exit /b 1
)

echo       Not found — cloning into:
echo       %DIGILENT_IP_REPO%

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: git not found on PATH. Install Git for Windows, or clone manually:
  echo   git clone %DIGILENT_GIT_URL% "%DIGILENT_IP_REPO%"
  exit /b 1
)

for %%I in ("%DIGILENT_IP_REPO%") do set "IP_PARENT=%%~dpI"
if not exist "%IP_PARENT%" mkdir "%IP_PARENT%"
if errorlevel 1 (
  echo ERROR: could not create parent folder: %IP_PARENT%
  exit /b 1
)

git clone --depth 1 "%DIGILENT_GIT_URL%" "%DIGILENT_IP_REPO%"
if errorlevel 1 (
  echo ERROR: git clone failed.
  exit /b 1
)

if not exist "%DIGILENT_IP_REPO%\ip\" (
  echo ERROR: clone succeeded but ip\ folder is missing.
  exit /b 1
)

call :check_required_ips
exit /b %ERRORLEVEL%

:check_required_ips
set "MISSING="
if not exist "%DIGILENT_IP_REPO%\ip\dvi2rgb\" set "MISSING=!MISSING! dvi2rgb"
if not exist "%DIGILENT_IP_REPO%\ip\rgb2dvi\" set "MISSING=!MISSING! rgb2dvi"
if not exist "%DIGILENT_IP_REPO%\ip\axi_dynclk\" set "MISSING=!MISSING! axi_dynclk"
if defined MISSING (
  echo ERROR: Digilent repo is missing required IP folder^(s^):!MISSING!
  echo        Repo: %DIGILENT_IP_REPO%
  exit /b 1
)
exit /b 0

:setup_vivado
if defined XILINX_VIVADO (
  if exist "%XILINX_VIVADO%\settings64.bat" (
    call "%XILINX_VIVADO%\settings64.bat"
    exit /b 0
  )
)

for %%V in (2024.2 2024.1 2023.2 2023.1) do (
  if exist "C:\Xilinx\Vivado\%%V\settings64.bat" (
    echo Using C:\Xilinx\Vivado\%%V\settings64.bat
    call "C:\Xilinx\Vivado\%%V\settings64.bat"
    exit /b 0
  )
)

echo ERROR: Could not find Vivado settings64.bat
echo Install Vivado 2024.2 ^(required by hdmi_in.tcl^) or set XILINX_VIVADO.
exit /b 1
