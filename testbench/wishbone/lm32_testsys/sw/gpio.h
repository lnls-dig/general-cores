#ifndef __GPIO_H
#define __GPIO_H

#include "inttypes.h"

#include "board.h"

struct GPIO_WB
{
  uint32_t CODR;  /*Clear output register*/
  uint32_t SODR;  /*Set output register*/
  uint32_t DDR;   /*Data direction register (1 means out)*/
  uint32_t PSR;   /*Pin state register*/
};

static volatile struct GPIO_WB *__gpio = (volatile struct GPIO_WB *) BASE_GPIO;

static inline void gpio_out(int pin, int val)
{
  if(val)
    __gpio->SODR = (1<<pin);
  else
    __gpio->CODR = (1<<pin);
}

static inline void gpio_dir(int pin, int val)
{
  if(val)
    __gpio->DDR |= (1<<pin);
  else
    __gpio->DDR &= ~(1<<pin);
}

static inline int gpio_in(int pin)
{
  return __gpio->PSR & (1<<pin) ? 1: 0;
}

        
#endif
        
