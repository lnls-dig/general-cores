PLATFORM = lm32

OBJS_WRC = main.o uart.o target/lm32/crt0.o

CROSS_COMPILE ?= /opt/gcc-lm32/bin/lm32-elf-
CFLAGS_PLATFORM  = -mmultiply-enabled -mbarrel-shift-enabled  -I.
LDFLAGS_PLATFORM = -mmultiply-enabled -mbarrel-shift-enabled   -nostdlib -T target/lm32/ram.ld 

CC=$(CROSS_COMPILE)gcc
OBJCOPY=$(CROSS_COMPILE)objcopy
OBJDUMP=$(CROSS_COMPILE)objdump
CFLAGS= $(CFLAGS_PLATFORM) -ffunction-sections -fdata-sections -Os -Iinclude $(PTPD_CFLAGS) -Iptp-noposix/PTPWRd 
LDFLAGS= $(LDFLAGS_PLATFORM) -ffunction-sections -fdata-sections -Os -Iinclude 
SIZE = $(CROSS_COMPILE)size
OBJS=$(OBJS_PLATFORM) $(OBJS_WRC) $(OBJS_PTPD) $(OBJS_PTPD_FREE) 
OUTPUT=main

all: 		$(OBJS)
				$(SIZE) -t $(OBJS)
				${CC} -o $(OUTPUT).elf $(OBJS) $(LDFLAGS) 
				${OBJCOPY} -O binary $(OUTPUT).elf $(OUTPUT).bin
				${OBJDUMP} -d $(OUTPUT).elf > $(OUTPUT)_disasm.S
				./genraminit $(OUTPUT).bin 0 > $(OUTPUT).ram

clean:	
	rm -f $(OBJS) $(OUTPUT).elf $(OUTPUT).bin $(OUTPUT).ram

%.o:		%.c
				${CC} $(CFLAGS) $(PTPD_CFLAGS) $(INCLUDE_DIR) $(LIB_DIR) -c $^ -o $@

load:	all
		./tools/lm32-loader $(OUTPUT).bin

tools:
			make -C tools
		
fpga:
		- killall -9 vuart_console
		../loadfile ../spec_top.bin
		./tools/zpu-loader $(OUTPUT).bin
