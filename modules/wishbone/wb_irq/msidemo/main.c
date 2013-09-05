#include <stdio.h>
#include "display.h"
#include "irq.h"

volatile unsigned int* display = (unsigned int*)0x02900000;
volatile unsigned int* irq_slave = (unsigned int*)0x02000d00;



char* mat_sprinthex(char* buffer, unsigned long val)
{
	unsigned char i,ascii;
	const unsigned long mask = 0x0000000F;

	for(i=0; i<8;i++)
	{
		ascii= (val>>(i<<2)) & mask;
		if(ascii > 9) ascii = ascii - 10 + 'A';
	 	else 	      ascii = ascii      + '0';
		buffer[7-i] = ascii;		
	}
	
	buffer[8] = 0x00;
	return buffer;	
}

void show_msi()
{
  char buffer[12];
  
  mat_sprinthex(buffer, global_msi.msg);
  disp_put_str("D ");
  disp_put_str(buffer);
  disp_put_c('\n');

  
  mat_sprinthex(buffer, global_msi.src);
  disp_put_str("A ");
  disp_put_str(buffer);
  disp_put_c('\n');

  
  mat_sprinthex(buffer, (unsigned long)global_msi.sel);
  disp_put_str("S ");
  disp_put_str(buffer);
  disp_put_c('\n');
}


void isr0()
{
  unsigned int j;
  
  disp_put_str("ISR0\n");
  show_msi();
 
 for (j = 0; j < 125000000; ++j) {
        asm("# noop"); /* no-op the compiler can't optimize away */
      }
 disp_put_c('\f');     
}

void isr1()
{
  unsigned int j;
  
  disp_put_str("ISR1\n");
  show_msi();

   for (j = 0; j < 125000000; ++j) {
        asm("# noop"); /* no-op the compiler can't optimize away */
      }
   disp_put_c('\f');   
}

void _irq_entry(void) {
  
  disp_put_c('\f');
  disp_put_str("IRQ_ENTRY\n");
  irq_process();

   
}

const char mytext[] = "Hallo Welt!...\n\n";

void main(void) {

  isr_table_clr();
  isr_ptr_table[0]= isr0;
  isr_ptr_table[1]= isr1;  
  irq_set_mask(0x03);
  irq_enable();

  
  int j, xinc, yinc, x, y;

unsigned int time = 0;


	unsigned int addr_raw_off;

	char color = 0xFF;

  

  disp_reset();	
  disp_put_c('\f');
  disp_put_str(mytext);






	x = 0;
	y = 9;
	yinc = -1;
 	xinc = 1;
	addr_raw_off = 0;
	
  while (1) {
    /* Rotate the LEDs */
    


  disp_put_raw( get_pixcol_val((unsigned char)y), get_pixcol_addr((unsigned char)x, (unsigned char)y), color);


	if(x == 63) xinc = -1;
	if(x == 0)  xinc = 1;

	if(y == 47) yinc = -1;
	if(y == 0)  yinc = 1;

	x += xinc;
	y += yinc;


	
	

      /* Each loop iteration takes 4 cycles.
       * It runs at 125MHz.
       * Sleep 0.2 second.
       */
      for (j = 0; j < 125000000/160; ++j) {
        asm("# noop"); /* no-op the compiler can't optimize away */
      }

	if(time++ > 500) {time = 0; color = ~color; }
	
    
  }
}
