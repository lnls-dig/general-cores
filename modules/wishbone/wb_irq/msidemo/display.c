#include "display.h"

const unsigned int REG_MODE 	= 0x00000000;
const unsigned int REG_RST 	= 0x00000004;
const unsigned int REG_UART	= 0x00010000;
const unsigned int REG_CHAR	= 0x00020000;
const unsigned int REG_RAW	= 0x00030000;

const char MODE_RAW	= 0x03;
const char MODE_UART	= 0x01;
const char MODE_CHAR	= 0x02;
const char MODE_IDLE	= 0x00;

const char ROW_LEN = 11;

void disp_reset()
{
	*(display + REG_RST) = 1;
}




void disp_put_c(char ascii)
{

	*(display + (REG_MODE>>2)) = (unsigned int)MODE_UART;
	*(display + (REG_UART>>2)) = (unsigned int)ascii;
}


void disp_put_str(const char *sPtr)
{
	*(display + (REG_MODE>>2)) = (unsigned int)MODE_UART;
	while(*sPtr != '\0') *(display + (REG_UART>>2)) = (unsigned int)*sPtr++;
}

void disp_put_line(const char *sPtr, unsigned char row)
{
	unsigned char col, outp, pad;
	pad = 0;

	for(col=0; col<ROW_LEN; col++)
	{
		if(*(sPtr+col) == '\0') pad = 1;

		if(pad) outp = ' ';
		else 	outp = (unsigned int)*(sPtr+col);	
		
		disp_loc_c(outp, row, col);
	}
}

void disp_loc_c(char ascii, unsigned char row, unsigned char col)
{
	unsigned int rowcol;
	
	*(display + (REG_MODE>>2)) = (unsigned int)MODE_CHAR;
	rowcol = ((0x07 & (unsigned int)row)<<6) + ((0x0f & (unsigned int)col)<<2);
	*(display + ((REG_CHAR + rowcol)>>2)) = (unsigned int)ascii;

}

void disp_put_raw(char pixcol, unsigned int address, char color)
{
	char oldpixcol;

		
	*(display + (REG_MODE>>2)) = (unsigned int)MODE_RAW;
	oldpixcol = *(display + (REG_RAW>>2) + ((address & 0x3FFF))); //read out old memcontent
	
	if(color) // 1 -> White
		*(display + (REG_RAW>>2) + ((address & 0x3FFF))) = (unsigned int)(pixcol | oldpixcol);
	else
		*(display + (REG_RAW>>2) + ((address & 0x3FFF))) = (unsigned int)(~pixcol & oldpixcol);

	*(display + (REG_MODE>>2)) = (unsigned int)MODE_IDLE;

}

unsigned int get_pixcol_addr(unsigned char x_in, unsigned char y_in)
{
	unsigned int addr_base = 0x230;
	unsigned int x, y;
	
	x = x_in & 0x3F;
	if(y_in < 48) 	y = ((y_in>>3)<<8); //determine row. Shift by 8bit
	else 		y = (5<<8);	    //outside visible area, take start of bottom row instead

	return addr_base + y + x;
	
}

unsigned int get_pixcol_val(unsigned char y_in)
{
	
	return 1<<(y_in & 0x07); 

}
