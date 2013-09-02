/** @file irq.c
 *  @brief MSI capable IRQ handler for the LM32
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  @author Mathias Kreider <m.kreider@gsi.de>
 *
 *  @bug None!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */

#include "irq.h"

//#include "display.h" DEBUG

extern unsigned int* irq_slave;

const unsigned int IRQ_REG_RST 	= 0x00000000;
const unsigned int IRQ_REG_STAT = 0x00000004;
const unsigned int IRQ_REG_POP	= 0x00000008;
const unsigned int IRQ_OFFS_MSG = 0x00000000;
const unsigned int IRQ_OFFS_SRC = 0x00000004;
const unsigned int IRQ_OFFS_SEL	= 0x00000008;

inline void irq_pop_msi( unsigned int irq_no)
{
    unsigned int* msg_queue = (unsigned int*)(irq_slave + ((irq_no +1)<<2));
    
    global_msi.msg =  *(msg_queue+(IRQ_OFFS_MSG>>2));
    global_msi.src =  *(msg_queue+(IRQ_OFFS_SRC>>2)); 
    global_msi.sel =  *(msg_queue+(IRQ_OFFS_SEL>>2));
    *(irq_slave + (IRQ_REG_POP>>2)) = 1<<irq_no;   
    
    return; 
} 

inline void isr_table_clr(void)
{
  //set all ISR table entries to Null
  unsigned int i;
  for(i=0;i<32;i++)  isr_ptr_table[i] = 0; 
}

inline  unsigned int  irq_get_mask(void)
{
	 //read IRQ mask
	 unsigned int im;
	 asm volatile (	"rcsr %0, im": "=&r" (im));
	 return im;	             	
}

inline void irq_set_mask( unsigned int im)
{
	 //write IRQ mask
	 asm volatile (	"wcsr im, %0": "=&r" (im));
	 return;	             	
}

inline void irq_disable(void)
{
	 //globally disable interrupts
	  unsigned int ie;
	 asm volatile (	"rcsr %0, IE\n" \
			            "andi  %0, %0, 0xFFFE\n" \
			            "wcsr IE, %0" : "=&r" (ie));
	 return;		            
}

inline void irq_enable(void)
{
	 //globally enable interrupts
	  unsigned int  ie;
	 asm volatile (	"rcsr %0, IE\n" \
			            "ori  %0, %0, 1\n" \
			            "wcsr IE, %0" : "=&r" (ie));
	 return;			            
}

inline void irq_clear( unsigned int mask)
{
	 //clear pending interrupt flag(s)
	 unsigned int ip;
	 asm volatile (	"rcsr %0, ip\n" \
			            "and  %0, %0, %1\n" \
			            "wcsr ip, %0" : "=&r" (ip): "r" (mask) );
	 return;		            
}



inline void irq_process(void)
{
  char buffer[12];
   
  unsigned int ip;
  unsigned char irq_no = 0;
  
  //get pending flags
  asm volatile ("rcsr %0, ip": "=r"(ip));

  while(ip) //irqs pending ?
  {
    if(ip & 0x01) //check if irq with lowest number is pending
    {
      irq_pop_msi(irq_no);      //pop msg from msi queue into global_msi variable
      irq_clear(1<<irq_no);     //clear pending bit
      if((unsigned int)isr_ptr_table[irq_no]) isr_ptr_table[irq_no]();  //execute isr
      //else disp_put_str("No ISR\nptr found!\n"); DEBUG
    }  
    irq_no++; 
    ip = ip >> 1; //process next irq
  }
  return;
}  
