// ============================================================================
// adc_virtual -- entrada do estimador no ritmo de um conversor A/D real
// ----------------------------------------------------------------------------
// Antes, a fonte (o anel do ARM na placa, o arquivo na simulacao) entregava uma
// amostra a cada pedido do interpolador (req_in): o estimador rodava tao rapido
// quanto o interpolador conseguia, mais rapido que o tempo real.
//
// Aqui um contador fracionario gera um pulso exatamente a FS:
//     clk * NUM/DEN = 10 MHz * 24/15625 = 15 360 Hz   (sem erro acumulado;
//     o intervalo entre pulsos e 651 ou 652 ciclos, media 651,04)
// A cada pulso a fonte entrega uma amostra ('avanca'), que vai para uma FIFO
// pequena. O interpolador le dessa FIFO; quando ela esta vazia, in(0) devolve
// VAZIO (-2^31, fora da faixa de 16 bits) e o interpolador.cmm pede de novo.
// E o mesmo esquema que um ADC de verdade vai usar: so muda quem escreve na FIFO.
//
// Diagnostico (lido pelo testbench e, na placa, gravado na memoria de saida):
//   ocup_max : maior ocupacao da FIFO (folga do interpolador contra o ritmo real)
//   perdidas : pulsos com a FIFO cheia (amostra perdida = o interpolador nao
//              acompanhou o tempo real; tem de ser 0)
//
// ATIVO = 0 volta ao comportamento antigo (a fonte avanca a cada req_in), para
// comparar os dois modos com o mesmo HDL.
// ============================================================================
module adc_virtual #(
    parameter ATIVO = 1,
    parameter NUM   = 24,            // pulsos ...
    parameter DEN   = 15625,         // ... a cada DEN ciclos de clk
    parameter LEN   = 64             // profundidade da FIFO (potencia de 2: myFIFO)
)(
    input                       clk,
    input                       rst,
    input  signed [31:0]        amostra,   // amostra da fonte (a proxima a ser consumida)
    output                      avanca,    // pulso: a fonte entrega 'amostra' e avanca
    input                       req_in,    // pedido do interpolador (in(0))
    output signed [31:0]        dado,      // para o interpolador: amostra ou VAZIO
    output reg [15:0]           ocup_max,
    output reg [15:0]           perdidas
);

localparam signed [31:0] VAZIO = 32'sh80000000;

generate
if (ATIVO) begin : g_adc

    // ---- relogio de amostragem: NUM pulsos a cada DEN ciclos ----
    reg [31:0] acc;
    reg        tick;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc  <= 32'd0;
            tick <= 1'b0;
        end else if (acc + NUM >= DEN) begin
            acc  <= acc + NUM - DEN;
            tick <= 1'b1;
        end else begin
            acc  <= acc + NUM;
            tick <= 1'b0;
        end
    end
    assign avanca = tick;

    // ---- FIFO de entrada: escrita no pulso, lida pelo interpolador ----
    wire        vazia, cheia;
    wire [$clog2(LEN)-1:0] usedw;
    wire signed [31:0] q;
    myFIFO #(.WORD(32), .LENGTH(LEN), .ALMOST(2)) fifo_adc (
        .clk          (clk),
        .data         (amostra),
        .rdreq        (req_in),
        .sclr         (rst),
        .wrreq        (tick),
        .almost_empty (),
        .empty        (vazia),
        .full         (cheia),
        .q            (q),
        .usedw        (usedw)
    );
    assign dado = vazia ? VAZIO : q;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ocup_max <= 16'd0;
            perdidas <= 16'd0;
        end else begin
            if ({{(16-$clog2(LEN)){1'b0}}, usedw} > ocup_max)
                ocup_max <= {{(16-$clog2(LEN)){1'b0}}, usedw};
            if (tick & cheia & (perdidas != 16'hFFFF))
                perdidas <= perdidas + 16'd1;
        end
    end

end else begin : g_livre

    // comportamento antigo: uma amostra por pedido do interpolador
    assign avanca = req_in;
    assign dado   = amostra;
    always @(posedge clk) begin
        ocup_max <= 16'd0;
        perdidas <= 16'd0;
    end

end
endgenerate

endmodule
