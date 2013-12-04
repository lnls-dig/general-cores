/** @file irq.h
 *  @brief Header file for MSI capable IRQ handler for the LM32
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Usage:
 * 
 *  void <an ISR>(void) { <evaluate global_msi and do something useful> }
 *  ...
 *  void _irq_entry(void) {irq_process();}
 *  ...
 *  void main(void) {
 *
 *    isr_table_clr();
 *    isr_ptr_table[0]= <an ISR>;
 *    isr_ptr_table[1]= ...
 *    ...   
 *    irq_set_mask(0x03); //Enable used IRQs ...
 *    irq_enable(); 
 *    ...
 *  }
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

#ifndef __IRQ_H_
#define __IRQ_H_

typedef struct
{
   unsigned int  msg;
   unsigned int  src;
   unsigned int  sel;
} msi; 

//ISR function pointer table
typedef void (*isr_ptr_t)(void);
isr_ptr_t isr_ptr_table[32]; 

//Global containing last processed MSI message
volatile msi global_msi;

inline void irq_pop_msi( unsigned int irq_no);

inline  unsigned int  irq_get_mask(void);

inline void irq_set_mask( unsigned int im);

inline void irq_disable(void);

inline void irq_enable(void);

inline void irq_clear( unsigned int mask);

inline void isr_table_clr(void);

inline void irq_process(void);

#endif
