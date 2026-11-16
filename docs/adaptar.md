# Como colocar os seus processadores

## 1. O cálculo

Os dois exemplos estão em `firmware/proc_entrada/proc_entrada.cmm` e
`firmware/proc_saida/proc_saida.cmm`. Troque o cálculo e mantenha as regras de interface.

**`proc_entrada`** (laço livre, `while(1)`):

```c
x_in = in(0);
while (x_in < -40000)        // o SAPHO nao espera o dado: -2^31 = ainda nao chegou
{
    x_in = in(0);
}
// ... o seu calculo ...
out(0, resultado);           // UMA escrita por amostra: cada uma vai para a FIFO
```

**`proc_saida`** (interrupção):

```c
void main()
{
    // ... declaracoes e inicializacao ...
    return;
    #PRACA
        out(1, 1);           // ocupado: a maquina de estados espera por isto
        x = in(0);           // UMA leitura da FIFO por disparo
        // ... o seu calculo ...
        // quando houver resultado: NPAL escritas seguidas em out(0)
        out(1, 0);           // livre
}
```

## 2. Número de palavras do reporte (NPAL)

Se o seu reporte tiver outro tamanho, ajuste nos três lugares:

| Arquivo | O que mudar |
|---|---|
| `firmware/tb/top_level_tb.v` | `localparam NPAL` |
| `quartus/toplevel_placa.v` | `parameter NPAL` |
| `arm/main.c` | `#define NPAL` |

NPAL + 1 (o diagnóstico) tem de ser no máximo 127 (o tamanho de cada área).

## 3. Mais canais de entrada ou de saída

O processador gerado tem **um** barramento de entrada e **um** de saída, compartilhados por
todos os canais: `req_in[k]` vale 1 no ciclo do `in(k)` e `out_en[k]` vale 1 no ciclo do
`out(k)`. As larguras seguem `#NUIOIN` e `#NUIOOU` do `.cmm`.

- **Entrada**: no wrapper (`hdl/top/top_proc_*.v`), troque a ligação direta por um
  multiplexador sobre `req_in`, como o `top_proc_saida.v` faz.
- **Saída**: o barramento `out` só vale no ciclo do `out_en`. Para guardar o valor, registre
  no ciclo do `out_en[k]`, como o `top_proc_saida.v` faz com `out0` e `out1`; para gravar numa
  FIFO, ligue o barramento cru e use `out_en[k]` como `wrreq`, como o `top_level.v` faz.

## 4. Outra FIFO, outra taxa

- **Profundidade da FIFO**: parâmetro `LEN_FIFO` do `top_level.v`. **Tem de ser potência de 2**
  (limitação da `myFIFO`).
- **Taxa de amostragem**: parâmetros `NUM` e `DEN` do `top_level.v`, com
  `FS = 10 MHz × NUM / DEN`. Confira na simulação e na placa que as amostras perdidas ficam
  em 0: se não ficarem, o processador não acompanha a taxa.
- **Sem taxa fixa**: `ADC_VIRTUAL = 0` faz a fonte avançar a cada pedido do `proc_entrada`.
  Nesse modo, nada impede o primeiro processador de produzir mais rápido do que o segundo
  consome; garanta que o segundo é mais rápido ou acrescente controle de fluxo.

## 5. Arquivos novos de Verilog

Acrescente-os em dois lugares:

- no projeto do AURORA, em `firmware/criar_projeto.ps1` (`synthesizableFiles`), e rode o script
  de novo;
- no projeto do Quartus, em `quartus/DE10_NANO_SoC_GHRD.qsf` (`set_global_assignment -name
  VERILOG_FILE ...`).

Um processador novo também precisa entrar nos dois projetos. No AURORA: a pasta
`firmware/<nome>/<nome>.cmm` e a entrada em `processors` do `criar_projeto.ps1`. No Quartus: o
`.v` e os dois `.mif` de `hdl/processadores/<nome>/`, mais um `SEARCH_PATH` para essa pasta. O
`quartus/compilar.ps1` copia qualquer processador de `firmware/` para `hdl/processadores/`.

## 6. Conferir

1. **Simulação** (`firmware/simular.ps1`): adapte o modelo em `python/verificar.py`, ou compare
   a saída com o seu próprio modelo.
2. **Placa** (`python/capturar.py`): compare o `dados.csv` com a simulação, com o mesmo arquivo
   de sinal. Com o mesmo HDL e a mesma entrada, os dois devem coincidir.
