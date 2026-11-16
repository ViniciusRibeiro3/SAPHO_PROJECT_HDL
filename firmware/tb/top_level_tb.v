`timescale 1ns/1ps
// ============================================================================
// Testbench do template: o MESMO hdl/top/top_level.v que vai para a placa.
//
// Entrada : sim_io/sinal_teste.txt, um inteiro de 16 bits por linha. A proxima amostra e
//           lida a cada pulso 'avanca' do top_level (a taxa de amostragem do ADC virtual,
//           15 360 amostras/s de um clock de 10 MHz), como a leitora do anel faz na placa.
// Saida   : sim_io/saida.txt, uma linha por reporte do proc_saida (NPAL palavras),
//           no mesmo formato das primeiras colunas do dados.csv da placa.
//           sim_io/diagnostico.txt, a ocupacao das FIFOs e as amostras perdidas.
// Fim     : quando o arquivo de entrada acaba (mais FIM_CICLOS para esvaziar a fila).
//
// O periodo do clock (4 ns) so define a escala de tempo da simulacao; o que importa sao
// os ciclos: o ADC virtual conta 651,04 ciclos por amostra, como na placa a 10 MHz.
// Outro arquivo de entrada: +sinal=<arquivo> na linha do simulador.
// ============================================================================
module top_level_tb();

localparam NPAL       = 5;              // palavras por reporte (proc_saida)
localparam FIM_CICLOS = 200000;         // depois do fim do arquivo (o ultimo reporte sai antes disso)

reg clk = 1'b0, rst_geral = 1'b1;
always #2 clk <= ~clk;
initial #40 rst_geral <= 1'b0;

reg  signed [31:0] amostra = 32'sd0;
wire               avanca, out_en_saida0;
wire signed [31:0] out0_saida;
wire        [15:0] adc_ocup_max, adc_perdidas, fifo_ocup_max, fifo_perdidas;

integer f_in, f_out, f_diag, lido;
reg [8*256-1:0] arq_sinal;
reg  fim_arquivo = 1'b0;
reg [63:0] n_amostras = 0;
initial begin
	if (!$value$plusargs("sinal=%s", arq_sinal)) arq_sinal = "sim_io/sinal_teste.txt";
	f_in   = $fopen(arq_sinal, "r");
	f_out  = $fopen("sim_io/saida.txt", "w");
	f_diag = $fopen("sim_io/diagnostico.txt", "w");
	if (f_in == 0) begin
		$display("ERRO: nao abriu %0s", arq_sinal);
		$finish;
	end
end

// a fonte entrega 'amostra' no ciclo do pulso 'avanca' e le a proxima (borda de descida)
always @(negedge clk)
	if (avanca & !fim_arquivo) begin
		lido = $fscanf(f_in, "%d", amostra);
		if (lido != 1) fim_arquivo = 1'b1;
		else           n_amostras  = n_amostras + 1;
	end

// out0_saida vale no ciclo SEGUINTE ao out_en (saida registrada): grava um ciclo depois
reg pend = 1'b0;
integer k = 0;
always @(posedge clk) begin
	pend <= out_en_saida0;
	if (pend) begin
		$fwrite(f_out, "%0d", out0_saida);
		k = k + 1;
		if (k == NPAL) begin
			$fwrite(f_out, "\n");
			k = 0;
		end else
			$fwrite(f_out, ",");
	end
end

reg [63:0] conta_fim = 0;
always @(posedge clk)
	if (fim_arquivo) begin
		conta_fim <= conta_fim + 1;
		if (conta_fim == FIM_CICLOS) begin
			$fdisplay(f_diag, "amostras entregues pela fonte: %0d", n_amostras);
			$fdisplay(f_diag, "FIFO de entrada (ADC virtual): ocupacao maxima %0d de 63; amostras perdidas %0d", adc_ocup_max, adc_perdidas);
			$fdisplay(f_diag, "FIFO entre os processadores: ocupacao maxima %0d; amostras perdidas %0d", fifo_ocup_max, fifo_perdidas);
			$fclose(f_diag);
			$fclose(f_out);
			$finish;
		end
	end

top_level top_level_inst (
	.clk           (clk),
	.rst_geral     (rst_geral),
	.amostra       (amostra),
	.avanca        (avanca),
	.out0_saida    (out0_saida),
	.out_en_saida0 (out_en_saida0),
	.adc_ocup_max  (adc_ocup_max),
	.adc_perdidas  (adc_perdidas),
	.fifo_ocup_max (fifo_ocup_max),
	.fifo_perdidas (fifo_perdidas)
);

endmodule
