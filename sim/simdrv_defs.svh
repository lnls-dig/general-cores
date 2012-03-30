`ifndef SIMDRV_DEFS_SV
 `define SIMDRV_DEFS_SV 1

typedef longint unsigned uint64_t;
typedef int unsigned uint32_t;
typedef shortint unsigned uint16_t;



typedef uint64_t u64_array_t[];
typedef byte byte_array_t[];




virtual class CBusAccessor;
   static int _null  = 0;
   
   pure virtual task writem(uint64_t addr[], uint64_t data[], input int size, ref int result);
   pure virtual task readm(uint64_t addr[], ref uint64_t data[], input int size, ref int result);

   virtual task read(uint64_t addr, ref uint64_t data, input int size = 4, ref int result = _null);
      int res;
      uint64_t aa[1], da[];

      da= new[1];
      
      aa[0]  = addr;
      readm(aa, da, size, res);
      data  = da[0];
   endtask


   virtual task write(uint64_t addr, uint64_t data, input int size = 4, ref int result = _null);
      uint64_t aa[1], da[1];
      aa[0]  = addr;
      da[0]  = data;
      writem(aa, da, size, result);
   endtask

endclass // CBusAccessor

class CSimUtils;
   
   static function automatic u64_array_t pack(byte x[], int size, int big_endian = 1);
      u64_array_t tmp;
      int i, j;
      int nwords, nbytes;

      nwords  = (x.size() + size - 1) / size;
      tmp     = new [nwords];

      for(i=0;i<nwords;i++)
        begin      
           uint64_t d;
           d         =0;
           nbytes    = (x.size() - i * nbytes > size ? size : x.size() - i*nbytes);
           
           for(j=0;j<nbytes;j++)
             begin
                if(big_endian)
                  d  = d | ((x[i*size+j] << (8*(size-1-j))));
                else
                  d  = d | ((x[i*size+j] << (8*j)));
             end

           
           tmp[i]    = d;
        end
      return tmp;
      endfunction // pack
   

   static function automatic byte_array_t unpack(u64_array_t x, int entry_size, int size, int big_endian = 1);
      byte_array_t tmp;
      int i, n;

      tmp  = new[size];
      n    = 0;
      i    = 0;
      
      
      while(n < size)
        begin
           tmp[n]  = x[i] >> (8*(entry_size-1 - (n % entry_size)));
           
           n++;
           if(n % entry_size == 0)
             i++;
        end

      return tmp;
   endfunction // unpack
   
  
   

endclass // CSimUtils

static CSimUtils SimUtils;



`endif