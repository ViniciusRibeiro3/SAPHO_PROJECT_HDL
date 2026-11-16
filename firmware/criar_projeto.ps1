# Cria o projeto do AURORA (firmware\template.spf) nesta pasta.
#
# O .spf guarda caminhos absolutos da maquina, entao nao vai para o git: cada clone roda
# este script uma vez. Os processadores sao as pastas proc_entrada e proc_saida; o HDL de
# topo e o MESMO que vai para a placa (..\hdl\top) e o testbench e tb\top_level_tb.v.
#
# Uso (PowerShell, nesta pasta):  .\criar_projeto.ps1
$ErrorActionPreference = "Stop"
$aqui = $PSScriptRoot
$spf = @{
    metadata  = @{ projectName = "template"; appVersion = "aurora 1.0.0"; projectPath = $aqui }
    structure = @{
        basePath   = $aqui
        processors = @(
            @{ name = "proc_entrada"; exists = $true },
            @{ name = "proc_saida";   exists = $true }
        )
        folders            = @()
        topLevelFile       = "..\hdl\top\top_level.v"
        testbenchFile      = "tb\top_level_tb.v"
        synthesizableFiles = @(
            @{ name = "top_level.v";        path = "..\hdl\top\top_level.v";        isTopLevel = $true },
            @{ name = "adc_virtual.v";      path = "..\hdl\top\adc_virtual.v";      isTopLevel = $false },
            @{ name = "maq_estados.v";      path = "..\hdl\top\maq_estados.v";      isTopLevel = $false },
            @{ name = "top_proc_entrada.v"; path = "..\hdl\top\top_proc_entrada.v"; isTopLevel = $false },
            @{ name = "top_proc_saida.v";   path = "..\hdl\top\top_proc_saida.v";   isTopLevel = $false },
            @{ name = "proc_entrada.v";     path = "proc_entrada\proc_entrada\proc_entrada.v"; isTopLevel = $false },
            @{ name = "proc_saida.v";       path = "proc_saida\proc_saida\proc_saida.v";       isTopLevel = $false }
        )
        testbenchFiles = @(
            @{ name = "top_level_tb.v"; path = "tb\top_level_tb.v"; isTopLevel = $true }
        )
    }
}
$json = $spf | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText("$aqui\template.spf", $json, (New-Object System.Text.UTF8Encoding $false))
New-Item -ItemType Directory -Force "$aqui\sim_io" | Out-Null
Write-Output "Projeto criado: $aqui\template.spf"
$aurora = "$env:LOCALAPPDATA\Programs\AURORA\bin\aurora.exe"
if (Test-Path $aurora) { & $aurora status -C $aqui } else { Write-Output "aurora.exe nao encontrado em $aurora (instale o AURORA IDE)" }
