// ============================================================================
// toplevel_placa -- o projeto SAPHO dentro da DE10-Nano
// ----------------------------------------------------------------------------
// Fica entre o topo da Terasic (DE10_NANO_SoC_GHRD.v, que liga o ARM e as memorias)
// e o top_level do projeto (hdl/top/top_level.v, o mesmo da simulacao).
//
//   - PLL: 50 MHz da placa -> 10 MHz dos processadores (clk_sapho)
//   - reset: o ARM liga e desliga o projeto pelo bit 6 do led_pio (status_linux)
//   - entrada: a amostra vem da leitora do anel (sinal_arm_reader.v), que avanca a
//     cada pulso 'avanca' (a taxa de amostragem do ADC virtual)
//   - saida: maq_ctrl_mem_linux grava cada reporte do proc_saida na memoria que o
//     ARM le (onchip_memory2_0), com buffer duplo
// ============================================================================
module toplevel_placa #(
	parameter NPAL = 5                      // palavras por reporte (igual ao proc_saida e ao main.c)
)(
	input                clk_50,
	input                rst_n,
	input                status_linux,      // bit 6 do led_pio: 1 = projeto rodando
	output               clk_sapho,
	output               locked_pll,
	output               rst_geral,
	output        [9:0]  addr,              // -> onchip_memory2_0 (porta s2)
	output signed [31:0] data_mem,
	output               wr_en,
	output        [2:0]  state_out,
	output               avanca,            // -> sinal_arm_reader: entrega a amostra e avanca
	input  signed [15:0] input_sample       // <- sinal_arm_reader
);

pll pll (
	.refclk   (clk_50),
	.rst      (~rst_n),
	.outclk_0 (clk_sapho),
	.locked   (locked_pll)
);

// ---------------------------------------------------------------------------
// Reset: entra de forma assincrona (a qualquer momento) e sai de forma sincrona,
// 3 ciclos de clk_sapho depois que o ARM liberou (status_linux = 1) e o PLL travou.
// status_linux vem do dominio do ARM, sem relacao de fase com clk_sapho; usa-lo direto
// faria cada registrador sair do reset num ciclo diferente.
// ---------------------------------------------------------------------------
wire async_reset_src = ~status_linux | ~locked_pll;
reg [2:0] rst_sync_chain;
always @(posedge clk_sapho) begin
	if (async_reset_src)
		rst_sync_chain <= 3'b111;
	else
		rst_sync_chain <= {rst_sync_chain[1:0], 1'b0};
end
assign rst_geral = rst_sync_chain[2];

// ---------------------------------------------------------------------------
// O projeto (o mesmo da simulacao)
// ---------------------------------------------------------------------------
wire signed [31:0] amostra = input_sample;          // estende o sinal de 16 para 32 bits
wire signed [31:0] out0_saida;
wire               out_en_saida0;
wire        [15:0] adc_ocup_max, adc_perdidas, fifo_ocup_max, fifo_perdidas;

top_level #(.ADC_VIRTUAL(1)) top_level (
	.clk           (clk_sapho),
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

// diagnostico (palavra NPAL+1 de cada area): [31:24] maior ocupacao da FIFO do ADC,
// [23:16] amostras perdidas nas duas FIFOs (saturado em 255; tem de ser 0),
// [15:0] maior ocupacao da FIFO entre os processadores
wire [16:0] perdidas = adc_perdidas + fifo_perdidas;
wire [31:0] diag = {adc_ocup_max[7:0], (perdidas > 17'd255) ? 8'd255 : perdidas[7:0], fifo_ocup_max};

maq_ctrl_mem_linux #(.NPAL(NPAL)) maq_ctrl_mem_linux (
	.clk        (clk_sapho),
	.rst        (rst_geral),
	.out_en     (out_en_saida0),
	.out0       (out0_saida),
	.in_diag    (diag),
	.addr       (addr),
	.data_mem   (data_mem),
	.wr_en      (wr_en),
	.state_out  (state_out)
);

endmodule
