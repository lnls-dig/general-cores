#include <stdio.h>
#include <stdlib.h>

main(int argc, char *argv[])
{
	if(argc < 3) return -1;
	FILE *f = fopen(argv[1],"rb");
	if(!f) return -1;
	unsigned char x[4];
	int i=0;
	int n = atoi(argv[2]);
	
	while(!feof(f))
	{
		fread(x,1,4,f);
		printf("write %x %02X%02X%02X%02X\n", i++, x[0],x[1],x[2],x[3]);
	}
	
	for(;i<n;)
	{
		printf("write %x %02X%02X%02X%02X\n", i++, 0,0,0,0);	
	}
	fclose(f);
	return 0;
}