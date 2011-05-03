#############################
## Xilinx Coregen stuff
#############################
import os as __os
import shutil as __shutil

files = ["genram_pkg.vhd"]

def __copy_vhdls(cg_dir, dest_dir):
	f = open(cg_dir+"/analyze_order.txt","r")
	text = f.readlines();
	f.close()
	flist = [];
	for fname in text:
		f = fname.rstrip('\n')
		__shutil.copy(cg_dir+"/"+f, dest_dir)
		flist.append(f.split('/').pop())
	return flist
	
def __import_coregen_files():
	coregen_path = __os.getenv("XILINX") + "/ISE/coregen/ip/xilinx/primary/com/xilinx/ip/"
	work_dir = __manifest + "/coregen_ip";


	if __os.path.isdir(work_dir):
		return
		
	__os.mkdir(work_dir);

	print("[genrams] creating workdir " + work_dir)
	print("[genrams] copying ISE files...")	
	flist = []
	flist.extend(__copy_vhdls(coregen_path+"blk_mem_gen_v6_1", work_dir))
	flist.extend(__copy_vhdls(coregen_path+"fifo_generator_v6_1", work_dir))
	
	f=open(work_dir+"/Manifest.py","w")

	f.write("files = [\n")						
	first=True
	for fname in flist:
		if not first:
			f.write(",\n")
		else:
			first = False
		f.write("\""+fname+"\"")

	f.write("]\n");
	f.close()

##############################
## "Normal" manifest        ##
##############################
if (target == "altera"):
	modules = {"local" : "altera"}
elif (target == "xilinx"):
	__import_coregen_files()
	modules = {"local" : ["xilinx", "coregen_ip"]}
else:
	modules = {"local" : "altera"}