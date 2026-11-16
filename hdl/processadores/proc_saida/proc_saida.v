module proc_saida (

input  clk, rst,
input  signed [31:0] in ,
output signed [31:0] out,
output [0:0] req_in,
output [1:0] out_en,
input  itr);

/* verilator tracing_off */

wire cheguei;
wire [0:0] lk_toma, lk_cade, lk_valeu, lk_taqui;
wire [31:0] lk_cade_dado;
wire [31:0] lk_toma_dado;
assign lk_valeu[0] = 1'b0;
assign lk_taqui[0] = 1'b0;
assign lk_cade_dado[31:0] = 0;
wire proc_req_in, proc_out_en;
wire [0:0] addr_in;
wire [0:0] addr_out;

`ifdef __ICARUS__
 `ifndef YANC_SIM_VIS
  `define YANC_SIM_VIS
 `endif
`endif
`ifdef YANC_TRACE
 `ifndef YANC_SIM_VIS
  `define YANC_SIM_VIS
 `endif
`endif

`ifdef YANC_SIM_VIS
wire mem_wr;
wire [3:0] mem_addr_wr;
wire [6:0] pc_sim_val;
`endif

processor#(.NUBITS(32),
.NBMANT(23),
.NBEXPO(8),
.NBOPER(7),
.NUGAIN(128),
.MDATAS(15),
.MINSTS(92),
.SDEPTH(10),
.DDEPTH(10),
.NBIOIN(1),
.NBIOOU(1),
.FFTSIZ(3),
.FROUND(2),
.ITRADD(20),
.LOD(1),
.SET(1),
.OUT(1),
.INN(1),
.I2F_M(1),
.P_LOD(1),
.SF_DIV(1),
.F_DIV(1),
.F_ADD(1),
.F_MLT(1),
.EQU(1),
.JIZ(1),
.GRE(1),
.LES(1),
.ADD(1),
.SF_MLT(1),
.F2I(1),
.DFILE("proc_saida_data.mif"),
.IFILE("proc_saida_inst.mif"))

`ifdef YANC_SIM_VIS
p_proc_saida (clk, rst, in, out, addr_in, addr_out, proc_req_in, proc_out_en, itr, cheguei, lk_toma, lk_cade, lk_valeu, lk_taqui, lk_cade_dado, lk_toma_dado, mem_wr, mem_addr_wr,pc_sim_val);
`else
p_proc_saida (clk, rst, in, out, addr_in, addr_out, proc_req_in, proc_out_en, itr, cheguei, lk_toma, lk_cade, lk_valeu, lk_taqui, lk_cade_dado, lk_toma_dado);
`endif

assign req_in = proc_req_in;
addr_dec #(2) dec_out(proc_out_en, addr_out, out_en);

/* verilator tracing_on */

// ----------------------------------------------------------------------------
// Simulation -----------------------------------------------------------------
// ----------------------------------------------------------------------------

`ifdef YANC_SIM_VIS

// I/O ------------------------------------------------------------------------

reg signed [31:0] in_sim_0 = 0;
reg req_in_sim_0 = 0;

reg signed [31:0] out_sig_0 = 0;
reg out_en_sim_0 = 0;
reg signed [31:0] out_sig_1 = 0;
reg out_en_sim_1 = 0;

always @ (posedge clk) begin
   if (req_in[0]) in_sim_0 <= in;
end
always @ (*) begin
   req_in_sim_0 = req_in[0];
end

always @ (posedge clk) begin
   if (out_en[0]) out_sig_0 <= out;
   if (out_en[1]) out_sig_1 <= out;
end
always @ (*) begin
   out_en_sim_0 = out_en[0];
   out_en_sim_1 = out_en[1];
end

// variables ------------------------------------------------------------------

/* verilator tracing_off */  // float decode helpers (not traced)
reg signed [23:0] sm_me2; always @ (*) sm_me2 = (out[31]) ? -$signed({1'b0, out[22:0]}) : $signed({1'b0, out[22:0]});
reg signed [7:0] e_me2; always @ (*)  e_me2 = $signed(out[30:23]);
/* verilator tracing_on */

reg [31:0] me1_f_main_v_N_e_ = 0;
reg [31:0] me1_f_main_v_n_e_ = 0;
reg [31:0] me1_f_main_v_bloco_e_ = 0;
reg [31:0] me1_f_main_v_x_e_ = 0;
reg [31:0] me1_f_main_v_xmax_e_ = 0;
reg [31:0] me1_f_main_v_xmin_e_ = 0;
real me2_f_main_v_xf_e_ = 0.0;
real me2_f_main_v_soma_e_ = 0.0;
real me2_f_main_v_soma2_e_ = 0.0;

always @ (posedge clk) begin
   if (mem_addr_wr == 1 && mem_wr) me1_f_main_v_N_e_ <= out;
   if (mem_addr_wr == 3 && mem_wr) me1_f_main_v_n_e_ <= out;
   if (mem_addr_wr == 4 && mem_wr) me1_f_main_v_bloco_e_ <= out;
   if (mem_addr_wr == 5 && mem_wr) me1_f_main_v_x_e_ <= out;
   if (mem_addr_wr == 6 && mem_wr) me1_f_main_v_xmax_e_ <= out;
   if (mem_addr_wr == 7 && mem_wr) me1_f_main_v_xmin_e_ <= out;
   if (mem_addr_wr == 9 && mem_wr) me2_f_main_v_xf_e_ <= sm_me2*$pow(2.0,e_me2);
   if (mem_addr_wr == 10 && mem_wr) me2_f_main_v_soma_e_ <= sm_me2*$pow(2.0,e_me2);
   if (mem_addr_wr == 11 && mem_wr) me2_f_main_v_soma2_e_ <= sm_me2*$pow(2.0,e_me2);
end

// instructions ---------------------------------------------------------------

reg [31:0] valr2=0;
/* verilator tracing_off */
reg [31:0] valr1 /* verilator public_flat */=0;
reg [31:0] valr3 /* verilator public_flat */=0;
reg [31:0] valr4 /* verilator public_flat */=0;
reg [31:0] valr5 /* verilator public_flat */=0;
reg [31:0] valr6 /* verilator public_flat */=0;
reg [31:0] valr7 /* verilator public_flat */=0;
reg [31:0] valr8 /* verilator public_flat */=0;
reg [31:0] valr9 /* verilator public_flat */=0;
reg [31:0] valr10 /* verilator public_flat */=0;
/* verilator tracing_on */

reg [19:0] min [0:92-1];

/* verilator tracing_off */ reg signed [19:0] linetab /* verilator public_flat */ =-1; /* verilator tracing_on */
reg signed [19:0] linetabs=-1;

initial	$readmemb("pc_proc_saida_mem.txt",min);

always @ (posedge clk) begin
if (pc_sim_val < 92) linetab <= min[pc_sim_val];
linetabs <= linetab;   
valr1    <= {{(25){1'b0}}, pc_sim_val};
valr2    <= valr1;
valr3    <= valr2;
valr4    <= valr3;
valr5    <= valr4;
valr6    <= valr5;
valr7    <= valr6;
valr8    <= valr7;
valr9    <= valr8;
valr10   <= valr9;
end

`endif

endmodule