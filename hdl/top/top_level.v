// ============================================================================
// top_level -- dois processadores SAPHO ligados por uma FIFO
// ----------------------------------------------------------------------------
// E o MESMO arquivo na simulacao (firmware/tb/top_level_tb.v) e na placa
// (quartus/toplevel_placa.v). Cadeia:
//
//   fonte -> adc_virtual -> proc_entrada -> FIFO -> proc_saida -> reportes
//   (anel do ARM   (taxa de      (laco livre)   (myFIFO)  (interrupcao)  (maq_ctrl_mem_linux
//    ou arquivo)    amostragem)                                            -> memoria do ARM)
//
// - adc_virtual: entrega uma amostra da fonte a cada 1/FS (FS = 10 MHz * NUM/DEN,
//   por padrao 15 360 Hz) numa FIFO pequena que o proc_entrada le. Com ADC_VIRTUAL = 0
//   a fonte avanca a cada pedido do proc_entrada (sem ritmo de tempo real).
// - FIFO entre os processadores: o proc_entrada escreve com out(0); o proc_saida le
//   com in(0). A myFIFO SO FUNCIONA COM PROFUNDIDADE POTENCIA DE 2.
// - maq_estados: dispara o proc_saida (pulso na entrada de interrupcao) quando ha
//   amostra na FIFO e ele esta livre (bit 0 do out(1) do proc_saida = 0).
//
// Diagnostico: maior ocupacao de cada FIFO e amostras perdidas (pulso do ADC com a
// FIFO de entrada cheia, ou escrita do proc_entrada com a FIFO do meio cheia). Os dois
// contadores de perda tem de ficar em 0; se nao, o processador nao acompanha a taxa.
// ============================================================================
module top_level #(
	parameter ADC_VIRTUAL = 1,       // 1: taxa de amostragem fixa; 0: livre
	parameter NUM         = 24,      // FS = 10 MHz * NUM / DEN = 15 360 Hz
	parameter DEN         = 15625,
	parameter LEN_FIFO    = 1024     // FIFO entre os processadores (potencia de 2)
)(
	input                clk,
	input                rst_geral,
	input  signed [31:0] amostra,          // proxima amostra da fonte
	output               avanca,           // pulso: a fonte entregou 'amostra' e avanca
	output signed [31:0] out0_saida,       // reporte do proc_saida (registrado)
	output               out_en_saida0,    // uma palavra do reporte (out0_saida vale no ciclo seguinte)
	output        [15:0] adc_ocup_max,     // diagnostico
	output        [15:0] adc_perdidas,
	output reg    [15:0] fifo_ocup_max,
	output reg    [15:0] fifo_perdidas
);

// ---------------- entrada no ritmo da taxa de amostragem ----------------
wire               req_in_entrada;
wire signed [31:0] dado_entrada;

adc_virtual #(.ATIVO(ADC_VIRTUAL), .NUM(NUM), .DEN(DEN), .LEN(64)) adc_virtual_inst (
	.clk      (clk),
	.rst      (rst_geral),
	.amostra  (amostra),
	.avanca   (avanca),
	.req_in   (req_in_entrada),
	.dado     (dado_entrada),
	.ocup_max (adc_ocup_max),
	.perdidas (adc_perdidas)
);

// ---------------- processador de entrada ----------------
wire signed [31:0] bus_entrada;       // barramento de saida: vale no ciclo do out_en
wire        [0:0]  out_en_entrada;

top_proc_entrada top_proc_entrada_inst (
	.clk     (clk),
	.rst     (rst_geral),
	.in0     (dado_entrada),
	.req_in  (req_in_entrada),
	.out_bus (bus_entrada),
	.out_en  (out_en_entrada)
);

// ---------------- FIFO entre os processadores ----------------
wire               req_in_saida;
wire signed [31:0] dado_fifo;
wire               fifo_cheia;
wire [$clog2(LEN_FIFO)-1:0] usedw;

myFIFO #(.WORD(32), .LENGTH(LEN_FIFO), .ALMOST(2)) fifo_meio (
	.clk          (clk),
	.data         (bus_entrada),          // o dado vale no ciclo do out_en
	.rdreq        (req_in_saida),
	.sclr         (rst_geral),
	.wrreq        (out_en_entrada[0]),
	.almost_empty (),
	.empty        (),
	.full         (fifo_cheia),
	.q            (dado_fifo),
	.usedw        (usedw)
);

always @(posedge clk or posedge rst_geral) begin
	if (rst_geral) begin
		fifo_ocup_max <= 16'd0;
		fifo_perdidas <= 16'd0;
	end else begin
		if ({{(16-$clog2(LEN_FIFO)){1'b0}}, usedw} > fifo_ocup_max)
			fifo_ocup_max <= {{(16-$clog2(LEN_FIFO)){1'b0}}, usedw};
		if (out_en_entrada[0] & fifo_cheia & (fifo_perdidas != 16'hFFFF))
			fifo_perdidas <= fifo_perdidas + 16'd1;
	end
end

// ---------------- disparo do processador de saida ----------------
wire signed [31:0] out1_saida;        // bit 0: 1 = ocupado, 0 = livre
wire               itr_saida;

maq_estados maq_estados_inst (
	.clk       (clk),
	.rst_geral (rst_geral),
	.ocupado   (out1_saida[0]),
	.tem_dado  (usedw != 0),
	.disparo   (itr_saida)
);

// ---------------- processador de saida ----------------
wire [1:0] out_en_saida;

top_proc_saida top_proc_saida_inst (
	.clk    (clk),
	.rst    (rst_geral),
	.itr    (itr_saida),
	.in0    (dado_fifo),
	.req_in (req_in_saida),
	.out0   (out0_saida),
	.out1   (out1_saida),
	.out_en (out_en_saida)
);

assign out_en_saida0 = out_en_saida[0];

endmodule
