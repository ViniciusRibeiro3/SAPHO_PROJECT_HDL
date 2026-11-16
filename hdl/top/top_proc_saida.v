// ============================================================================
// top_proc_saida -- casca do processador de saida (interrupcao)
// ----------------------------------------------------------------------------
// itr: um pulso executa a rotina #PRACA do processador uma vez (vem da maq_estados).
// As saidas sao registradas no ciclo do out_en: out0/out1 passam a valer no ciclo
// SEGUINTE ao out_en (por isso a maq_ctrl_mem_linux grava um ciclo depois).
//   out0: reporte (NPAL palavras por reporte)
//   out1: bit 0 = ocupado (out(1,1) no inicio da rotina, out(1,0) no fim)
// ============================================================================
module top_proc_saida (
	input                    clk,
	input                    rst,
	input                    itr,
	input  signed [31:0]     in0,
	output        [0:0]      req_in,
	output reg signed [31:0] out0,
	output reg signed [31:0] out1,
	output        [1:0]      out_en
);

// multiplexador das entradas (um canal so: in(0) = in0)
reg signed [31:0] in_proc;
always @(*) begin
	case (req_in)
		1'b1:    in_proc = in0;
		default: in_proc = 32'sd0;
	endcase
end

wire signed [31:0] out_proc;

proc_saida proc_saida_inst (
	.clk    (clk),
	.rst    (rst),
	.in     (in_proc),
	.out    (out_proc),
	.req_in (req_in),
	.out_en (out_en),
	.itr    (itr)
);

always @(posedge clk) begin
	if (rst) begin
		out0 <= 32'sd0;
		out1 <= 32'sd0;
	end else begin
		if (out_en[0]) out0 <= out_proc;
		if (out_en[1]) out1 <= out_proc;
	end
end

endmodule
