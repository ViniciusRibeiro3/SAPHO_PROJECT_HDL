// ============================================================================
// maq_estados -- dispara o processador de saida, uma amostra por vez
// ----------------------------------------------------------------------------
// O proc_saida roda por interrupcao (#PRACA): cada pulso em 'disparo' executa a
// rotina uma vez, e ela consome uma amostra da FIFO. A rotina sinaliza ocupado com
// fout(1,1) no inicio e livre com fout(1,0) no fim (bit 0 do out(1) = 'ocupado').
//
//   S0: espera o processador ficar livre (ocupado = 0)
//   S1: espera haver amostra na FIFO (tem_dado = 1)
//   S2: pulso de 1 ciclo em 'disparo'
//   S3: espera o processador confirmar que comecou (ocupado = 1), e volta para S0
//
// O S3 impede um segundo pulso antes de a rotina comecar.
// ============================================================================
module maq_estados (
	input      clk,
	input      rst_geral,
	input      ocupado,
	input      tem_dado,
	output reg disparo
);

localparam S0 = 2'd0, S1 = 2'd1, S2 = 2'd2, S3 = 2'd3;
(* syn_encoding = "safe" *) reg [1:0] estado;

always @(*) disparo = (estado == S2);

always @(posedge clk or posedge rst_geral) begin
	if (rst_geral)
		estado <= S0;
	else
		case (estado)
			S0: if (!ocupado)  estado <= S1;
			S1: if (tem_dado)  estado <= S2;
			S2:                estado <= S3;
			S3: if (ocupado)   estado <= S0;
		endcase
end

endmodule
