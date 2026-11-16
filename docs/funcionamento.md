# Como o projeto funciona

## Relógios e reset

- A placa tem um relógio de 50 MHz. O PLL do `toplevel_placa.v` gera **10 MHz** (`clk_sapho`)
  para os processadores, as FIFOs e as máquinas de estado.
- O ARM liga e desliga o projeto pelo **bit 6 do `led_pio`** (`status_linux`): `0x00` = reset,
  `0x40` = rodando. O reset entra a qualquer momento e sai sincronizado com `clk_sapho`, 3
  ciclos depois de o ARM liberar e de o PLL travar.

## Entrada: o anel do ARM

Memória `onchip_memory2_1` (Platform Designer), 16 384 palavras de 32 bits, de porta dupla:

| Palavra | Quem escreve | Conteúdo |
|---|---|---|
| 0 | FPGA (`sinal_arm_reader.v`) | total de amostras já consumidas |
| 1 a 16 383 | ARM (`main.c`) | anel de amostras (16 bits nos bits baixos) |

- O ARM vê a memória no offset `0x10000` da ponte leve (lightweight HPS-to-FPGA), pela porta
  `s1`; o FPGA, pela porta `s2`, no relógio de 10 MHz. Cada lado usa uma porta, então a própria
  memória faz a passagem entre os domínios de relógio.
- A amostra `k` do arquivo vai para a palavra `1 + (k mod 16 383)`. O ARM lê o contador da
  palavra 0 e completa o anel, deixando até 16 382 amostras à frente do consumo.
- A cada pulso `avanca`, a leitora entrega a amostra atual e avança o ponteiro. A amostra fica
  registrada, para não mudar no ciclo em que a leitora escreve o contador.

## Taxa de amostragem: o ADC virtual

`hdl/top/adc_virtual.v` gera um pulso a cada `DEN/NUM` ciclos: com `NUM = 24` e
`DEN = 15625`, são exatamente 15 360 pulsos por segundo a 10 MHz (651 ou 652 ciclos entre
pulsos, sem erro acumulado). Para outra taxa `FS`, escolha `NUM/DEN = FS / 10 MHz`.

A cada pulso, a amostra da fonte entra numa FIFO de 64 posições, que o `proc_entrada` lê. Com
ela vazia, o `in(0)` devolve `-2^31` e o processador pede de novo. Com `ADC_VIRTUAL = 0`, a fonte
avança a cada pedido do processador, sem ritmo de tempo real (útil para depurar, mas aí a FIFO
do meio pode encher; veja abaixo).

## Entre os processadores: FIFO e máquina de estados

- **FIFO** (`myFIFO`, 1024 posições, potência de 2): o `proc_entrada` escreve com `out(0)`, no
  ciclo do `out_en`; o `proc_saida` lê com `in(0)`.
- **Máquina de estados** (`maq_estados.v`): o `proc_saida` roda por interrupção. Cada pulso
  na entrada `itr` executa a rotina `#PRACA` uma vez. A máquina só manda o pulso quando o
  processador está livre (bit 0 do `out(1)` = 0) e há dado na FIFO, e espera ele confirmar que
  começou (bit 0 = 1) antes de voltar ao início.
- **Folga**: o `proc_saida` precisa consumir uma amostra em menos tempo do que o intervalo de
  amostragem, em média; a FIFO absorve as rajadas, como o cálculo do reporte a cada 256
  amostras. O diagnóstico mostra a maior ocupação da FIFO e quantas escritas foram perdidas
  com ela cheia.

## Saída: buffer duplo para o ARM

Memória `onchip_memory2_0`, 256 palavras, offset `0x0` da ponte leve. Duas áreas, usadas
alternadamente:

| Área 0 | Área 1 | Conteúdo |
|---|---|---|
| 0 | 128 | flag: 1 = reporte pronto (escrita por último pelo FPGA, zerada pelo ARM) |
| 1 a NPAL | 129 a 128+NPAL | reporte (as NPAL palavras de `out(0)` do `proc_saida`) |
| NPAL+1 | 128+NPAL+1 | diagnóstico |

Diagnóstico: `[31:24]` maior ocupação da FIFO do ADC virtual, `[23:16]` amostras perdidas nas
duas FIFOs (saturado em 255), `[15:0]` maior ocupação da FIFO entre os processadores.

Como a flag é escrita por último, quando o ARM a encontra em 1 o reporte inteiro já está na
memória. O ARM copia a área de uma vez, zera a flag e passa para a outra área; uma área só é
reescrita dois reportes depois. No exemplo (um reporte a cada 256 amostras a 15 360 por
segundo, 60 reportes por segundo), isso dá ao ARM cerca de 16 ms para ler cada reporte.

## Programa do ARM

`arm/main.c`, depois de compilado, é o `sapho_arm`:

1. lê o arquivo `sinal_arm.txt` inteiro para a memória DDR;
2. enche o anel de entrada, coloca o projeto em reset, zera a memória de saída e libera o projeto;
3. em laço: completa o anel e, se a flag da área da vez estiver em 1, copia o reporte, zera a
   flag e grava uma linha no `dados.csv`;
4. no fim, imprime a taxa de consumo medida (deve dar a taxa de amostragem), o diagnóstico e
   os indicadores de leitura.

Cada linha do `dados.csv`: `palavra1, ..., palavraNPAL, intervalo_us, misturada, diagnostico`.
`intervalo_us` acima de alguns milissegundos indica que o Linux interrompeu o programa por
muito tempo; `misturada = 1` indica que a área foi reescrita durante a cópia. Nos dois casos,
vale repetir a captura.
