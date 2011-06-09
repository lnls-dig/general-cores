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
	
def __import_coregen_module(path, name, work_dir):
	__os.mkdir(work_dir+"/"+name);
	flist = __copy_vhdls(path+"/"+name, work_dir+"/"+name)

	f=open(work_dir+"/"+name+"/Manifest.py","w")

	f.write("files = [\n")						
	first=True
	for fname in flist:
		if not first:
			f.write(",\n")
		else:
			first = False
		f.write("\""+fname+"\"")

	f.write("]\n");
	f.write("library = \"" + name + "\"\n")
	f.close()

def __import_coregen_files():
	xilinx_dir =  __os.getenv("XILINX");
	if xilinx_dir == None:
		print("[genrams] FATAL ERROR: XILINX environment variable not set. Do you have ISE installed?")
		__os.exit(-1)

	coregen_path = xilinx_dir + "/ISE/coregen/ip/xilinx/primary/com/xilinx/ip/"
	work_dir = __manifest + "/coregen_ip";


	if __os.path.isdir(work_dir):
		return

	print("[genrams] creating workdir " + work_dir)
	__os.mkdir(work_dir);

	print("[genrams] copying ISE files...")			
	__import_coregen_module(coregen_path, "blk_mem_gen_v4_1", work_dir);
	__import_coregen_module(coregen_path, "fifo_generator_v6_1", work_dir);
	

##############################
## "Normal" manifest        ##
##############################

print ("[genrams] target = " + target)

if (target == "altera"):
	modules = {"local" : "altera"}
elif (target == "xilinx"):
	__import_coregen_files()
	modules = {"local" : ["xilinx", "coregen_ip/blk_mem_gen_v4_1", "coregen_ip/fifo_generator_v6_1"]}
else:
	modules = {"local" : "altera"}