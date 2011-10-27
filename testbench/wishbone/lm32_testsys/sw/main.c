#include <stdio.h>
//#include <stdint.h>

#include "gpio.h"

void _irq_entry(){}

int main(void)
{
	uart_init();
	uart_write_byte('U');
	uart_write_byte('U');
	uart_write_byte('U');
	uart_write_byte('U');
	uart_write_byte('U');
	uart_write_byte('U');
	uart_write_byte('U');
	uart_write_byte('U');

/*	gpio_dir(1,1);
	for(;;)
	{
		gpio_out(1,0);
		delay(10);
		gpio_out(1,1);
		delay(10);
	}*/
}



