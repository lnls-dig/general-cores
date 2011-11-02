#include "inttypes.h"
#include "uart.h"

#define CPU_CLOCK 1000000
#define UART_BAUDRATE 10000
#define BASE_UART 0x20000000

#include "wb_uart.h"

#define CALC_BAUD(baudrate) (((((unsigned long long)baudrate*8ULL)<<(16-7))+(CPU_CLOCK>>8))/(CPU_CLOCK>>7))
 
static volatile struct UART_WB *uart = (volatile struct UART_WB *) BASE_UART;

void uart_init()
{
	uart->BCR = CALC_BAUD(UART_BAUDRATE);
}

void uart_write_byte(unsigned char x)
{
	while( uart->SR & UART_SR_TX_BUSY);

	uart->TDR = x;
	if(x == '\n')
		uart_write_byte('\r');
}

int uart_poll()
{
 	return uart->SR & UART_SR_RX_RDY;
}

int uart_read_byte()
{
 	return uart ->RDR & 0xff;
}