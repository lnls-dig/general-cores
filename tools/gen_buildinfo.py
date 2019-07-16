# Script to generate the buildinfo_pkg.vhd file

with open("buildinfo_pkg.vhd", "w") as f:
  import subprocess
  import time
  commitid = subprocess.check_output(
      ["git", "log", "-1", "--format=%H"]).decode().strip()
  userid = subprocess.check_output(
      ["git", "config", "--get", "user.name"]).decode().strip()
  f.write("-- Buildinfo for project {}\n".format(syn_top))
  f.write("--\n")
  f.write("-- This file was automatically generated; do not edit\n")
  f.write("\n")
  f.write("package buildinfo_pkg is\n")
  f.write("  constant buildinfo : string :=\n")
  f.write('       "buildinfo:1" & LF\n')
  f.write('     & "module:{}" & LF\n'.format(syn_top))
  f.write('     & "commit:{}" & LF\n'.format(commitid))
  f.write('     & "syntool:{}" & LF\n'.format(syn_tool))
  f.write('     & "syndate:{}" & LF\n'.format(
      time.strftime("%A, %B %d %Y", time.localtime())))
  f.write('     & "synauth:{}" & LF;\n'.format(userid))
  f.write('end buildinfo_pkg;\n')
