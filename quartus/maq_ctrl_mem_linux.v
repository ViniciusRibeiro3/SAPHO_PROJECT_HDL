// ============================================================================
// maq_ctrl_mem_linux -- grava os reportes na memoria que o ARM le (buffer duplo)
// ----------------------------------------------------------------------------
// Memoria de saida: onchip_memory2_0, 256 palavras de 32 bits, porta s2 (lado FPGA).
// O proc_saida emite cada reporte como NPAL palavras seguidas em out(0). Os reportes
// vao alternadamente para duas areas, para o ARM ter o tempo de um reporte inteiro
// para ler um enquanto o seguinte e escrito:
//   area 0: palavra   0 = flag, 1..NPAL       = reporte, NPAL+1     = diagnostico
//   area 1: palavra 128 = flag, 129..128+NPAL = reporte, 128+NPAL+1 = diagnostico
// A flag (1 = reporte pronto) e escrita POR ULTIMO: quando o ARM a encontra em 1, o
// reporte inteiro ja esta na memoria. O ARM copia a area, zera a flag e passa a outra.
// NPAL+1 tem de ser no maximo 127.
//
// Temporizacao: a casca do processador registra o dado no ciclo do out_en, entao
// out0 so vale no ciclo SEGUINTE -- por isso o 'pend'. Uma palavra por ciclo de
// out_en; depois da ultima, mais 2 ciclos (diagnostico e flag).
// ============================================================================
module maq_ctrl_mem_linux #(
	parameter NPAL = 5                     // palavras por reporte
)(
	input                    clk,
	input                    rst,
	input                    out_en,       // out_en[0] do proc_saida
	input  signed [31:0]     out0,         // dado (vale no ciclo seguinte ao out_en)
	input         [31:0]     in_diag,      // -> palavra NPAL+1
	output reg [9:0]         addr,
	output reg signed [31:0] data_mem,
	output reg               wr_en,
	output [2:0]             state_out     // para os LEDs (depuracao)
);

reg       area;     // 0: palavras 0..127; 1: palavras 128..255
reg [6:0] cont;     // palavras do reporte ja gravadas
reg       pend;     // houve out_en no ciclo anterior: gravar out0 agora
reg [1:0] fim;      // 0 = gravando o reporte; 1 = falta o diagnostico; 2 = falta a flag

assign state_out = {area, fim};

always @(posedge clk or posedge rst) begin
	if (rst) begin
		area     <= 1'b0;
		cont     <= 7'd0;
		pend     <= 1'b0;
		fim      <= 2'd0;
		wr_en    <= 1'b0;
		addr     <= 10'd0;
		data_mem <= 32'sd0;
	end else begin
		pend  <= out_en;
		wr_en <= 1'b0;
		if (pend) begin                                        // palavra 1..NPAL do reporte
			addr     <= {2'b00, area, cont + 7'd1};
			data_mem <= out0;
			wr_en    <= 1'b1;
			cont     <= cont + 7'd1;
			if (cont + 7'd1 == NPAL)
				fim <= 2'd1;
		end else if (fim == 2'd1) begin                        // palavra NPAL+1: diagnostico
			addr     <= {2'b00, area, NPAL[6:0] + 7'd1};
			data_mem <= in_diag;
			wr_en    <= 1'b1;
			fim      <= 2'd2;
		end else if (fim == 2'd2) begin                        // palavra 0 da area: flag
			addr     <= {2'b00, area, 7'd0};
			data_mem <= 32'sd1;
			wr_en    <= 1'b1;
			fim      <= 2'd0;
			cont     <= 7'd0;
			area     <= ~area;                                 // proximo reporte vai para a outra area
		end
	end
end

endmodule
