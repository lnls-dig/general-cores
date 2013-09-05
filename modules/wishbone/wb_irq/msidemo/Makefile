LD      := lm32-elf-ld
CC      := lm32-elf-gcc
CFLAGS  := -Wall -mmultiply-enabled -mbarrel-shift-enabled -Os -ggdb -ffreestanding

msidemo.bin: msidemo.elf
	lm32-elf-objcopy -O binary $< $@

msidemo.elf: crt0.o display.o irq.o main.o
	$(CC) $(CFLAGS) -o $@ -nostdlib -T linker.ld $^


clean:
	rm -f *.o *.elf *.bin
