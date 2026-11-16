// ============================================================================
// top_proc_entrada -- casca do processador de entrada (laco livre)
// ----------------------------------------------------------------------------
// O processador gerado pelo SAPHO tem UM barramento de entrada (in) e UM de saida
// (out), compartilhados pelos canais: req_in[k] = 1 no ciclo do in(k) e out_en[k] = 1
// no ciclo do out(k). Com um canal so de entrada, in recebe in0 direto.
//
// out_bus e o barramento de saida cru: o dado vale SO no ciclo do out_en. E assim que
// a FIFO do top_level o grava (no mesmo ciclo do out_en).
// Para mais canais: troque o 'assign in_proc' por um multiplexador sobre req_in, como
// no top_proc_saida.v, e ajuste as larguras de req_in/out_en (#NUIOIN/#NUIOOU).
// ============================================================================
module top_proc_entrada (
	input                clk,
	input                rst,
	input  signed [31:0] in0,
	output        [0:0]  req_in,
	output signed [31:0] out_bus,
	output        [0:0]  out_en
);

wire signed [31:0] in_proc = in0;

proc_entrada proc_entrada_inst (
	.clk    (clk),
	.rst    (rst),
	.in     (in_proc),
	.out    (out_bus),
	.req_in (req_in),
	.out_en (out_en)
);

endmodule
