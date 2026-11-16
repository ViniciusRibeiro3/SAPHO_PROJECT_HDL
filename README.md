# SAPHO_PROJECT_HDL

Projeto-modelo para rodar processadores **SAPHO** na placa **DE10-Nano** (Cyclone V SoC),
com o processador **ARM** da própria placa fazendo o papel do mundo externo:

- o ARM **fornece o sinal de entrada** ao FPGA, amostra por amostra, a partir de um arquivo;
- o FPGA processa o sinal em **dois processadores SAPHO ligados por uma FIFO**;
- o ARM **coleta os resultados** e grava um arquivo `.csv`.

Com isso dá para testar na placa qualquer processador SAPHO, com sinais longos e
repetíveis, sem conversor A/D e sem instrumentação externa. O mesmo HDL roda na simulação
(Verilator, pelo AURORA) e na placa, então o resultado da placa pode ser comparado com o da
simulação.

> **Estado (16/11/2026):** simulação validada contra o modelo em Python e projeto compilado
> no Quartus 23.1 (0 erros, folgas de tempo positivas). O teste na placa deste exemplo ainda
> está em andamento; a infraestrutura (anel do ARM, ADC virtual, FIFO, buffer duplo) é a mesma
> já validada na placa no projeto do TCC.

O projeto nasceu do TCC *Implementação em FPGA de algoritmo para estimação de fasores
harmônicos* (Vinicius Ribeiro da Silva, UFJF, 2026), em que essa infraestrutura levou um
estimador de fasores harmônicos com dois processadores SAPHO para a placa. Aqui ela vem com
dois processadores pequenos de exemplo, para serem trocados pelos seus.

## Como funciona

```
                    FPGA (10 MHz)
 ARM (Linux)  ┌──────────────────────────────────────────────────────────────┐
 ┌─────────┐  │ sinal_arm_  ADC       proc_      FIFO     proc_    maq_ctrl_ │
 │ sinal_  │──┼▶ reader  ─▶ virtual ─▶ entrada ─▶ (1024) ─▶ saida ─▶ mem_linux┼──┐
 │ arm.txt │  │ (anel)     (taxa de   (laço          │     (inter-   (buffer   │  │
 └─────────┘  │             amostr.)   livre)    maq_estados  rupção)  duplo)   │  │
 dados.csv ◀──┼──────────────────────────────────────────────────────────────┼──┘
              └──────────────────────────────────────────────────────────────┘
```

| Bloco | Arquivo | O que faz |
|---|---|---|
| Anel de entrada | `quartus/sinal_arm_reader.v` + `arm/main.c` | O ARM escreve as amostras numa memória de 16 384 palavras usada como anel e a mantém sempre à frente do consumo; o FPGA lê uma amostra por vez. O arquivo de sinal pode ser maior que a memória e pode ser repetido em laço. |
| ADC virtual | `hdl/top/adc_virtual.v` | Entrega as amostras na **taxa de amostragem** (padrão 15 360 por segundo, de um relógio de 10 MHz), como um conversor A/D. O `proc_entrada` espera a amostra chegar. |
| Processador de entrada | `firmware/proc_entrada/proc_entrada.cmm` | Exemplo: média móvel de 4 amostras. Roda em laço livre e escreve uma palavra na FIFO por amostra. |
| FIFO + handshake | `hdl/top/top_level.v`, `hdl/top/maq_estados.v` | A FIFO desacopla os dois processadores; a máquina de estados dispara o `proc_saida` quando há dado na FIFO e ele está livre. |
| Processador de saída | `firmware/proc_saida/proc_saida.cmm` | Exemplo: a cada 256 amostras, um **reporte** de 5 palavras (índice do bloco, média, potência média, máximo e mínimo). Roda por interrupção (`#PRACA`), uma amostra por disparo. |
| Saída para o ARM | `quartus/maq_ctrl_mem_linux.v` + `arm/main.c` | Grava cada reporte numa memória de 256 palavras com **buffer duplo**; o ARM copia e grava uma linha do `dados.csv` por reporte. |
| Diagnóstico | palavra seguinte ao reporte | Maior ocupação de cada FIFO e **amostras perdidas** (tem de ser 0). |

Mais detalhes em [`docs/funcionamento.md`](docs/funcionamento.md).

## O que é preciso

| Ferramenta | Para quê | Versão usada |
|---|---|---|
| AURORA (ambiente do SAPHO, com o compilador YANC) | compilar os processadores e simular | aurora 1.0.0 / YANC 9.1 |
| Quartus Prime Lite | compilar o FPGA | 23.1std |
| Intel SoC FPGA EDS (vem com o Quartus 17.1) | compilar o programa do ARM | 17.1 |
| Python 3 com numpy | gerar o sinal e conferir os resultados | 3.10 ou mais nova |
| DE10-Nano com o Linux da Terasic no cartão SD | rodar na placa | — |

Os scripts são em PowerShell (Windows). Os caminhos padrão das ferramentas estão no início de
cada script e podem ser trocados por parâmetro.

## Passo a passo

### 1. Simular

```powershell
cd firmware
.\criar_projeto.ps1        # uma vez por clone: cria o projeto do AURORA (template.spf)
.\simular.ps1              # gera o sinal, compila os processadores, simula e confere
```

O `simular.ps1` termina com a comparação contra um modelo em Python dos dois processadores
(`python/verificar.py`):

```
amostras entregues pela fonte: 16384
FIFO de entrada (ADC virtual): ocupacao maxima 1 de 63; amostras perdidas 0
FIFO entre os processadores: ocupacao maxima 1; amostras perdidas 0
64 reportes, blocos 0 a 63; indices consecutivos: sim
  bloco    : maior diferenca 0
  media    : maior diferenca 1.0 (tolerancia 2 a 2)
  potencia : maior diferenca 1.2 (tolerancia 3 a 3)
  maximo   : maior diferenca 1
  minimo   : maior diferenca 1
OK: os reportes batem com o modelo
```

### 2. Compilar para a placa

```powershell
cd quartus
.\compilar.ps1             # processadores -> sistema do ARM (Platform Designer) -> Quartus
cd ..\arm
.\compilar.ps1             # programa do ARM
```

Saem `binarios/projeto.sof` (FPGA) e `binarios/sapho_arm` (ARM). A compilação do Quartus leva
de 15 a 25 minutos.

### 3. Rodar na placa

Com a placa ligada (Linux no ar, acesso por ssh como root) e o cabo USB-Blaster conectado:

```powershell
# grava o FPGA (a gravação se perde ao desligar a placa: grave de novo a cada vez)
& C:\intelFPGA_lite\23.1std\quartus\bin64\quartus_pgm.exe -c "DE-SoC [USB-1]" -m jtag -o "p;binarios\projeto.sof@2"

# envia o programa e o sinal, roda, traz o dados.csv e confere contra o modelo
python python\capturar.py <IP da placa>
```

Cada linha do `dados.csv` tem as 5 palavras do reporte, o intervalo desde a consulta anterior
da flag (µs), um indicador de leitura misturada e o diagnóstico.

## Para usar os seus processadores

Resumo (o passo a passo está em [`docs/adaptar.md`](docs/adaptar.md)):

1. Troque o cálculo em `firmware/proc_entrada/proc_entrada.cmm` e/ou
   `firmware/proc_saida/proc_saida.cmm`, mantendo as **regras de interface**:
   - `proc_entrada`: o laço de espera do `in(0)` (o processador SAPHO não espera o dado) e
     **uma** escrita em `out(0)` por amostra (cada escrita vai para a FIFO);
   - `proc_saida`: `out(1,1)` no início da rotina `#PRACA` e `out(1,0)` no fim (é assim que a
     máquina de estados sabe que ele está livre), e **NPAL** escritas em `out(0)` por reporte.
2. Se mudar o número de palavras do reporte, ajuste **NPAL** nos três lugares: `NPAL` do
   `firmware/tb/top_level_tb.v`, parâmetro `NPAL` do `quartus/toplevel_placa.v` e `#define NPAL`
   do `arm/main.c`.
3. Ajuste o modelo em `python/verificar.py` para o seu cálculo (ou troque a verificação).
4. Simule, compile e rode como acima.

## Cuidados que custaram caro (e já estão resolvidos aqui)

- **A `myFIFO` só funciona com profundidade potência de 2.** Com outra profundidade (por
  exemplo, 24 576), parte dos endereços não existe e o dado lido é lixo, periodicamente.
- **O processador SAPHO não espera no `in()`.** Ele lê o que estiver no barramento no ciclo do
  pedido. Por isso o ADC virtual devolve um valor sentinela (−2³¹) quando não há amostra, e o
  `proc_entrada` pede de novo.
- **Escrever numa FIFO cheia perde o dado sem aviso.** Sem uma taxa de amostragem fixa, o
  primeiro processador pode produzir mais rápido do que o segundo consome. Os contadores de
  amostras perdidas existem para isso: se não forem 0, o processador não acompanha a taxa.
- **O dado do barramento `out` do SAPHO só vale no ciclo do `out_en`.** A FIFO grava nesse
  ciclo; a máquina de saída, que lê a saída registrada, grava um ciclo depois.
- **O reset tem de sair de forma síncrona.** O sinal que liga o projeto vem do ARM, em outro
  domínio de relógio; o `toplevel_placa.v` o sincroniza.
- **Evite gravar todas as formas de onda na simulação.** Uma simulação longa com o registro
  completo de sinais gera arquivos de dezenas de gigabytes e fica muito mais lenta. O
  `simular.ps1` usa o modo `--fast` do AURORA, que não grava formas de onda.

## Estrutura

```
firmware/           processadores (.cmm), testbench e scripts do AURORA
hdl/top/            HDL do projeto (o mesmo na simulação e na placa)
hdl/sapho/          núcleo do processador SAPHO (YANC 9.1)
hdl/processadores/  Verilog e memórias gerados dos processadores (copiados pelo compilar.ps1)
quartus/            projeto da DE10-Nano (topo da Terasic + Platform Designer + toplevel_placa)
arm/                programa do ARM
python/             gerar o sinal, capturar na placa e conferir
docs/               documentação
binarios/           .sof e programa do ARM prontos
```

## Créditos

- Processador SAPHO e compilador YANC: desenvolvidos no laboratório da UFJF onde este projeto
  foi feito; o núcleo em `hdl/sapho/` está incluído com a autorização dos desenvolvedores.
- Topo da placa e sistema do ARM (`quartus/DE10_NANO_SoC_GHRD.v`, `soc_system.qsys`): baseados
  no *Golden Hardware Reference Design* da Terasic para a DE10-Nano.
- Infraestrutura de entrada e saída pelo ARM, ADC virtual e exemplo: Vinicius Ribeiro da Silva.
