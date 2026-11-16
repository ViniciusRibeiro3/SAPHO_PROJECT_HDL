// ============================================================================
// sinal_arm_reader -- leitora da RAM de entrada alimentada pelo ARM (STREAMING)
// ----------------------------------------------------------------------------
// A entrada do interpolador vem da RAM onchip_memory2_1 (porta s2), que o ARM
// alimenta em tempo de execucao. Suporta sinais MAIORES que a RAM (ex: rampa de
// 537600 amostras) via BUFFER CIRCULAR: o ARM vai enchendo a frente do que o FPGA
// consome.
//
// Layout da RAM (16384 palavras de 32 bits):
//   palavra 0        : read_count  (esta FSM ESCREVE -> o ARM le p/ saber o ritmo)
//   palavras 1..16383: buffer circular de amostras (RING_SIZE = 16383)
//
// A cada req_in (sampling): avanca ring_ptr (da a volta em RING_SIZE), incrementa
// read_count, e serve ring[ring_ptr] ao interpolador (amostra nos 16 bits baixos).
// Logo APOS cada req_in, rouba 1 ciclo do s2 pra escrever read_count na palavra 0
// (req_in e lento -> sobra banda). A amostra vai registrada (sample_reg) p/ ficar
// estavel durante esse ciclo roubado.
//
// DETECCAO DE UNDERRUN: fica no ARM (compara read_count lido vs quantas amostras
// ja escreveu). Se a FSM consumir mais do que o ARM escreveu, o ARM detecta e
// repete a corrida. O core SAPHO nao espera no in(), por isso o ARM tem que manter
// o buffer sempre a frente (ver sapho-arm-input-streaming).
//
// Para OFF-NOMINAL (sinal de 16384 que faz loop), o ARM simplesmente re-alimenta
// o arquivo em loop -> a mesma FSM serve os dois casos.
// ============================================================================
module sinal_arm_reader #(
    parameter ADDR_WIDTH = 14,     // 16384 palavras
    parameter DATA_WIDTH = 16,     // amostra de 16 bits
    parameter RING_BASE  = 1,      // palavra 0 = read_count; ring a partir de 1
    parameter RING_SIZE  = 16383   // 16384 - 1
) (
    input  clk,
    input  rst_geral,
    input  sampling,                            // = req_in do interpolador

    // Interface Avalon s2 (le o ring e ESCREVE read_count na palavra 0)
    output reg [ADDR_WIDTH-1:0] s2_address,
    output                      s2_chipselect,
    output                      s2_clken,
    output reg                  s2_write,
    output reg [31:0]           s2_writedata,
    output [3:0]                s2_byteenable,
    input  [31:0]               s2_readdata,

    // amostra para o interpolador
    output signed [DATA_WIDTH-1:0] signal
);
    assign s2_chipselect = 1'b1;
    assign s2_clken      = 1'b1;
    assign s2_byteenable = 4'b1111;

    reg [ADDR_WIDTH-1:0] ring_ptr;      // 0..RING_SIZE-1
    reg [31:0]           read_count;    // total de amostras consumidas
    reg                  samp_d;        // req_in atrasado 1 ciclo
    reg                  wrote_d;       // s2_write atrasado 1 ciclo (guarda contra latch pos-escrita)
    reg signed [DATA_WIDTH-1:0] sample_reg;

    wire [ADDR_WIDTH-1:0] ring_addr = RING_BASE[ADDR_WIDTH-1:0] + ring_ptr;

    assign signal = sample_reg;   // amostra registrada (estavel durante o ciclo roubado)

    always @(posedge clk or posedge rst_geral) begin
        if (rst_geral) begin
            ring_ptr     <= {ADDR_WIDTH{1'b0}};
            read_count   <= 32'd0;
            samp_d       <= 1'b0;
            wrote_d      <= 1'b0;
            sample_reg   <= {DATA_WIDTH{1'b0}};
            s2_address   <= RING_BASE[ADDR_WIDTH-1:0];
            s2_write     <= 1'b0;
            s2_writedata <= 32'd0;
        end else begin
            samp_d  <= sampling;
            wrote_d <= s2_write;

            // avanca ponteiro/contador no req_in
            if (sampling) begin
                ring_ptr   <= (ring_ptr == RING_SIZE-1) ? {ADDR_WIDTH{1'b0}} : ring_ptr + {{(ADDR_WIDTH-1){1'b0}},1'b1};
                read_count <= read_count + 32'd1;
            end

            if (samp_d) begin
                // 1 ciclo apos o req_in: escreve read_count na palavra 0 (rouba 1 ciclo do s2)
                s2_address   <= {ADDR_WIDTH{1'b0}};   // palavra 0
                s2_write     <= 1'b1;
                s2_writedata <= read_count;
            end else begin
                // serve o ring e registra a amostra (evita latch logo apos uma escrita)
                s2_address <= ring_addr;
                s2_write   <= 1'b0;
                if (!wrote_d)
                    sample_reg <= s2_readdata[DATA_WIDTH-1:0];
            end
        end
    end
endmodule
