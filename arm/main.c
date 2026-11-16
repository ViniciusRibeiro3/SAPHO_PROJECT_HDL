/*
 * Programa do ARM (HPS) do template: alimenta o sinal de entrada do FPGA e grava os
 * reportes do proc_saida em dados.csv.
 *
 * ENTRADA (onchip_memory2_1, offset 0x10000 na ponte leve, 16384 palavras de 32 bits):
 *   palavra 0         = amostras ja consumidas pelo FPGA (escrita pela sinal_arm_reader)
 *   palavras 1..16383 = anel de amostras (RING_SIZE = 16383)
 * O ARM mantem o anel cheio A FRENTE do que o FPGA consumiu. O arquivo de sinal pode
 * ser maior que a memoria; com loop = 1 ele e repetido sem fim.
 *
 * SAIDA (onchip_memory2_0, offset 0x0, 256 palavras de 32 bits), BUFFER DUPLO:
 *   area 0: palavra   0 = flag, 1..NPAL       = reporte, NPAL+1     = diagnostico
 *   area 1: palavra 128 = flag, 129..128+NPAL = reporte, 128+NPAL+1 = diagnostico
 * O FPGA escreve a flag por ultimo; o ARM copia a area da vez, zera a flag e passa para
 * a outra. Uma area so e reescrita dois reportes depois.
 *
 * Cada linha do dados.csv: as NPAL palavras do reporte, o intervalo (us) desde a
 * consulta anterior da flag, 1 se a area mudou durante a copia, e o diagnostico:
 *   [31:24] maior ocupacao da FIFO do ADC virtual, [23:16] amostras perdidas (tem de
 *   ser 0), [15:0] maior ocupacao da FIFO entre os processadores.
 *
 * Uso:  ./sapho_arm [num_reportes] [loop]
 *   num_reportes: quantos reportes capturar (padrao 600)
 *   loop        : 1 = repete o arquivo de sinal (padrao); 0 = alimenta uma vez so
 *
 * PARA O SEU PROJETO: ajuste NPAL (palavras por reporte) para o mesmo valor do
 * proc_saida.cmm e do parametro NPAL do toplevel_placa.v.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/time.h>
#include "hwlib.h"
#include "socal/socal.h"
#include "socal/hps.h"
#include "socal/alt_gpio.h"
#include "hps_0.h"

#define NPAL         5                  // palavras por reporte (proc_saida)
#define DIAG_WORD    ( NPAL + 1 )       // diagnostico, logo depois do reporte
#define AREA_1       128                // inicio da 2a area da memoria de saida
#define OMEM_WORDS   256
#define DEFAULT_REPORTES 600
#define ONCHIP_MEMORY2_1_BASE 0x10000   // memoria de entrada (offset na ponte leve)
#define RING_BASE    1                  // palavra 0 = amostras consumidas
#define RING_SIZE    16383
#define MAX_SAMPLES  2000000            // tamanho maximo do arquivo de sinal
#define SIGNAL_FILE  "sinal_arm.txt"    // um inteiro de 16 bits por linha

#define HW_REGS_BASE ( ALT_STM_OFST )
#define HW_REGS_SPAN ( 0x04000000 )
#define HW_REGS_MASK ( HW_REGS_SPAN - 1 )

static long agora_us( void ) {
	struct timeval tv;
	gettimeofday( &tv, NULL );
	return tv.tv_sec * 1000000L + tv.tv_usec;
}

int main( int argc, char **argv ) {
	void *virtual_base;
	int fd, i;
	uint32_t num_rep = DEFAULT_REPORTES;
	int do_loop = 1;

	if( argc > 1 ) { int n = atoi( argv[1] ); if( n > 0 ) num_rep = (uint32_t)n; }
	if( argc > 2 ) { do_loop = atoi( argv[2] ) ? 1 : 0; }

	if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ) {
		printf( "ERRO: nao abriu /dev/mem (rode como root)\n" ); return 1;
	}
	virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE );
	if( virtual_base == MAP_FAILED ) { printf( "ERRO: mmap\n" ); close( fd ); return 1; }

	volatile uint32_t *led  = (volatile uint32_t *)( virtual_base + ( ( unsigned long )( ALT_LWFPGASLVS_OFST + LED_PIO_BASE ) & HW_REGS_MASK ) );
	volatile uint32_t *omem = (volatile uint32_t *)( virtual_base + ( ( unsigned long )( ALT_LWFPGASLVS_OFST + ONCHIP_MEMORY2_0_BASE ) & HW_REGS_MASK ) );
	volatile uint32_t *iram = (volatile uint32_t *)( virtual_base + ( ( unsigned long )( ALT_LWFPGASLVS_OFST + ONCHIP_MEMORY2_1_BASE ) & HW_REGS_MASK ) );

	// ---- le o arquivo de sinal inteiro para a memoria DDR ----
	int *sig_buf = (int *)malloc( (size_t)MAX_SAMPLES * sizeof(int) );
	int n_file = 0;
	FILE *sig = fopen( SIGNAL_FILE, "r" );
	if( sig_buf == NULL || sig == NULL ) { printf( "ERRO: nao abriu %s\n", SIGNAL_FILE ); return 1; }
	while( n_file < MAX_SAMPLES && fscanf( sig, "%d", &sig_buf[n_file] ) == 1 ) n_file++;
	fclose( sig );
	if( n_file == 0 ) { printf( "ERRO: %s vazio\n", SIGNAL_FILE ); return 1; }
	printf( "INFO: %d amostras de %s | loop=%d | %u reportes\n", n_file, SIGNAL_FILE, do_loop, num_rep );

	FILE *csv = fopen( "dados.csv", "w" );
	if( csv == NULL ) { printf( "ERRO: dados.csv\n" ); return 1; }

	uint32_t written = 0;
	uint32_t max_feed = do_loop ? 0xFFFFFFFFu : (uint32_t)n_file;

	// ---- enche o anel antes de ligar o FPGA ----
	while( written < (RING_SIZE - 1) && written < max_feed ) {
		iram[ RING_BASE + ( written % RING_SIZE ) ] = (uint32_t)(int32_t)sig_buf[ written % n_file ];
		written++;
	}

	// ---- reset, limpa a memoria de saida e liga o projeto (bit 6 do led_pio) ----
	*led = 0x00;  usleep( 100000 );
	for( i = 0; i < OMEM_WORDS; i++ ) omem[i] = 0;
	// com o FPGA em reset ninguem escreve na palavra 0: sem zerar, ela guarda o total de
	// amostras da execucao anterior ate a 1a amostra desta, e o teste de underrun dispara a toa
	iram[0] = 0;
	*led = 0x40;
	long t0 = agora_us();

	uint32_t rep = 0, misturadas = 0, trocas = 0, diag = 0;
	int area = 0, underrun = 0;
	long t_ant = -1, gap_max = 0;
	int32_t linha[ NPAL + 1 ];

	while( rep < num_rep ) {
		uint32_t consumed = iram[0];
		if( written < max_feed && consumed > written ) underrun = 1;
		while( written < max_feed && ( written - consumed ) < (RING_SIZE - 1) ) {      // completa o anel
			iram[ RING_BASE + ( written % RING_SIZE ) ] = (uint32_t)(int32_t)sig_buf[ written % n_file ];
			written++;
		}

		long t = agora_us();
		long gap = ( t_ant < 0 ) ? 0 : ( t - t_ant );
		t_ant = t;
		int base = area ? AREA_1 : 0;
		if( omem[base] == 0 && omem[ area ? 0 : AREA_1 ] != 0 ) {   // perdeu a vez (nao deve acontecer)
			trocas++;
			area = !area;
			base = area ? AREA_1 : 0;
		}
		if( omem[base] != 0 ) {
			for( i = 1; i <= NPAL; i++ ) linha[i] = (int32_t)omem[base + i];   // copia de uma vez
			diag = omem[base + DIAG_WORD];
			int mudou = ( (int32_t)omem[base + 1] != linha[1] );
			omem[base] = 0;                                                       // devolve a area
			area = !area;
			if( mudou ) misturadas++;
			if( rep > 0 && gap > gap_max ) gap_max = gap;
			for( i = 1; i <= NPAL; i++ ) fprintf( csv, "%d,", linha[i] );
			fprintf( csv, "%ld,%d,%u\n", gap, mudou, diag );
			rep++;
			if( rep % 100 == 0 ) printf( "  %u/%u reportes\n", rep, num_rep );
		}
		if( !do_loop && written >= max_feed && iram[0] >= (uint32_t)n_file && rep > 0 ) {
			usleep( 200000 );                  // sinal acabou: espera os ultimos reportes
			if( omem[ area ? AREA_1 : 0 ] == 0 ) break;
		}
	}

	double dt = 1e-6 * ( agora_us() - t0 );
	uint32_t consumidas = iram[0];
	*led = 0x00;                               // desliga o projeto
	fclose( csv );
	printf( "INFO: %u amostras consumidas em %.2f s = %.1f amostras/s\n", consumidas, dt, dt > 0 ? consumidas / dt : 0.0 );
	printf( "INFO: FIFO do ADC: ocupacao maxima %u de 63 | amostras perdidas %u | FIFO entre os processadores: ocupacao maxima %u\n",
	        diag >> 24, ( diag >> 16 ) & 0xFF, diag & 0xFFFF );
	printf( "INFO: leitura: maior intervalo entre consultas da flag = %ld us; linhas misturadas = %u; "
	        "trocas de area fora da ordem = %u\n", gap_max, misturadas, trocas );
	printf( "INFO: %u reportes em dados.csv; underrun=%s\n", rep, underrun ? "SIM (repita)" : "nao" );

	free( sig_buf );
	munmap( virtual_base, HW_REGS_SPAN );
	close( fd );
	return 0;
}
