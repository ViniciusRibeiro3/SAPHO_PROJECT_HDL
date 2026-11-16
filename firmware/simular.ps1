# Simula o projeto: gera o sinal de teste, compila os processadores (o AURORA faz isso
# sozinho quando um .cmm muda), roda o testbench no Verilator e confere o resultado contra
# o modelo em Python.
#
# Uso (PowerShell, nesta pasta, depois do .\criar_projeto.ps1):
#     .\simular.ps1                    (sinal padrao: 16 384 amostras de 60 Hz)
#     .\simular.ps1 -sinal meu.txt     (outro arquivo, um inteiro de 16 bits por linha)
param([string]$sinal = "")
$ErrorActionPreference = "Stop"
$aqui = $PSScriptRoot
$raiz = Split-Path $aqui
$aurora = "$env:LOCALAPPDATA\Programs\AURORA\bin\aurora.exe"

New-Item -ItemType Directory -Force "$aqui\sim_io" | Out-Null
if ($sinal) { Copy-Item $sinal "$aqui\sim_io\sinal_teste.txt" -Force }
else        { python "$raiz\python\gerar_sinal.py" "$aqui\sim_io\sinal_teste.txt" }
Remove-Item "$aqui\sim_io\saida.txt" -ErrorAction SilentlyContinue

Push-Location $aqui
try {
    & $aurora sim tb\top_level_tb.v --fast -C $aqui
    if ($LASTEXITCODE -ne 0) { throw "a simulacao falhou (codigo $LASTEXITCODE)" }
} finally { Pop-Location }

Get-Content "$aqui\sim_io\diagnostico.txt"
python "$raiz\python\verificar.py" "$aqui\sim_io\sinal_teste.txt" "$aqui\sim_io\saida.txt"
