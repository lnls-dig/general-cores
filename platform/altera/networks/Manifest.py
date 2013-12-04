def __helper():
  files = [ "altera_networks_pkg.vhd" ]
  if syn_device[:1] == "5":      files.extend(["arria5_networks.qip"])
  if syn_device[:6] == "ep2agx": files.extend(["arria2gx_networks.qip"])
  return files
  
files = __helper()
