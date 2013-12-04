#ifndef _DISPLAY_H_
#define _DISPLAY_H_

extern volatile unsigned int* display;
extern const unsigned int MODE_REG;
extern const unsigned int RST_REG;
extern const unsigned int UART_REG;
extern const unsigned int CHAR_REG;
extern const unsigned int RAW_REG;

extern const char MODE_RAW;
extern const char MODE_UART;
extern const char MODE_CHAR;
extern const char MODE_IDLE;
extern const char ROW_LEN;

void disp_put_c(char ascii);
void disp_put_int(int number);
void disp_put_str(const char *sPtr);
void disp_put_line(const char *sPtr, unsigned char row);

void disp_reset();

void disp_loc_c(char ascii, unsigned char row, unsigned char col);
void disp_put_raw(char pixcol, unsigned int address, char color);

unsigned int get_pixcol_addr(unsigned char x_in, unsigned char y_in);

unsigned int get_pixcol_val(unsigned char y_in);


#endif 
