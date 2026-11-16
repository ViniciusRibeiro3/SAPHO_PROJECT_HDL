# Compila o programa do ARM (main.c) para o Linux da DE10-Nano.
#
# Usa o compilador cruzado arm-linux-gnueabihf-gcc e a hwlib que vem com o Intel SoC FPGA
# Embedded Development Suite (SoC EDS), instalado junto com o Quartus 17.1 em
# C:\intelFPGA\17.1\embedded. O Quartus mais novo (23.1) nao traz mais o SoC EDS;
# basta instalar o 17.1 so para isso (o FPGA continua sendo compilado no 23.1).
#
# Uso (PowerShell, nesta pasta):  .\compilar.ps1  [-eds C:\intelFPGA\17.1\embedded]
# Saida: ..\binarios\sapho_arm
param([string]$eds = "C:\intelFPGA\17.1\embedded")
$ErrorActionPreference = "Stop"
$aqui = $PSScriptRoot
$gcc = "$eds\ds-5\sw\gcc\bin\arm-linux-gnueabihf-gcc.exe"
$hw  = "$eds\ip\altera\hps\altera_hps\hwlib"
if (-not (Test-Path $gcc)) { throw "compilador nao encontrado: $gcc (instale o SoC EDS 17.1)" }
New-Item -ItemType Directory -Force "$aqui\..\binarios" | Out-Null
& $gcc -O2 -Wall -Dsoc_cv_av "-I$hw\include\soc_cv_av" "-I$hw\include" -I"$aqui" "$aqui\main.c" -o "$aqui\..\binarios\sapho_arm"
if ($LASTEXITCODE -ne 0) { throw "a compilacao falhou" }
Write-Output "Pronto: binarios\sapho_arm"
