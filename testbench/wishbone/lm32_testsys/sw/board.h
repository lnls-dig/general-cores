#ifndef __BOARD_H
#define __BOARD_H

#define BASE_GPIO 	0x20000000

static inline int delay(int x)
{
  while(x--) asm volatile("nop");
}
  
#endif
