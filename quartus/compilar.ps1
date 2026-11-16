# Compila o projeto para a placa: processadores (YANC) -> sistema do ARM (Platform
# Designer) -> Quartus. O bitstream sai em ..\binarios\projeto.sof.
#
# Uso (PowerShell, nesta pasta):  .\compilar.ps1
#   -quartus <pasta>  instalacao do Quartus (padrao: C:\intelFPGA_lite\23.1std\quartus)
#   -sem_qsys         nao regenera o soc_system (mais rapido, se o .qsys nao mudou)
param(
    [string]$quartus = "C:\intelFPGA_lite\23.1std\quartus",
    [switch]$sem_qsys
)
$ErrorActionPreference = "Stop"
$aqui = $PSScriptRoot
$raiz = Split-Path $aqui
$aurora = "$env:LOCALAPPDATA\Programs\AURORA\bin\aurora.exe"

# 1) processadores: compila os .cmm e copia o Verilog e as memorias para hdl\processadores
Write-Output "== 1/3 processadores (YANC)"
& $aurora build -C "$raiz\firmware"
if ($LASTEXITCODE -ne 0) { throw "a compilacao dos processadores falhou" }
foreach ($p in Get-ChildItem "$raiz\firmware" -Directory | Where-Object { Test-Path "$($_.FullName)\$($_.Name).cmm" }) {
    $ger = "$($p.FullName)\$($p.Name)"
    New-Item -ItemType Directory -Force "$raiz\hdl\processadores\$($p.Name)" | Out-Null
    Copy-Item "$ger\$($p.Name).v", "$ger\$($p.Name)_inst.mif", "$ger\$($p.Name)_data.mif" "$raiz\hdl\processadores\$($p.Name)\" -Force
    Write-Output "   $($p.Name): copiado para hdl\processadores\$($p.Name)"
}

# 2) sistema do ARM (soc_system), gerado a partir do soc_system.qsys
if (-not $sem_qsys -or -not (Test-Path "$aqui\soc_system\synthesis\soc_system.qip")) {
    Write-Output "== 2/3 Platform Designer (soc_system)"
    Push-Location $aqui
    try {
        # pelo cmd: o PowerShell 5.1 trata a saida de erro das ferramentas como falha
        cmd /c "`"$quartus\sopc_builder\bin\qsys-generate.exe`" soc_system.qsys --synthesis=VERILOG --output-directory=soc_system > qsys_generate.log 2>&1"
        if ($LASTEXITCODE -ne 0) { throw "qsys-generate falhou (ver quartus\qsys_generate.log)" }
    } finally { Pop-Location }
}

# 3) Quartus
Write-Output "== 3/3 Quartus (uns 15 a 25 minutos)"
Push-Location $aqui
try {
    cmd /c "`"$quartus\bin64\quartus_sh.exe`" --flow compile DE10_NANO_SoC_GHRD > quartus_compile.log 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "o Quartus falhou (ver quartus\quartus_compile.log)" }
} finally { Pop-Location }
New-Item -ItemType Directory -Force "$raiz\binarios" | Out-Null
Copy-Item "$aqui\output_files\DE10_NANO_SoC_GHRD.sof" "$raiz\binarios\projeto.sof" -Force
Select-String "$aqui\output_files\DE10_NANO_SoC_GHRD.sta.summary" -Pattern "Slack" | Select-Object -First 4 | ForEach-Object { "   folga " + $_.Line.Trim() }
Write-Output "Pronto: $raiz\binarios\projeto.sof"
