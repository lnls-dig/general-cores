#ifndef __UART_H
#define __UART_H

int mprintf(char const *format, ...);

void uart_init();
void uart_write_byte(unsigned char x);
  
#endif
