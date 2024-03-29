# Script to generate the buildinfo_pkg.vhd file

with open("buildinfo_pkg.vhd", "w") as f:
  import subprocess
  import time

  # Extract current commit id.
  try:
    commitid = subprocess.check_output(
      ["git", "log", "-1", "--format=%H"]).decode().strip()
  except:
    commitid = "unknown"

  # Extract current tag + dirty indicator.
  # It is not sure if the definition of dirty is stable across all git versions.
  try:
    tag = subprocess.check_output(
      ["git", "describe", "--dirty", "--always"]).decode().strip()
    if tag.endswith('-dirty'):
      dirty = '-dirty'
    else:
      dirty = ''
  except:
    tag = 'unknown'
    dirty = "-??"

  try:
    userid = subprocess.check_output(
      ["git", "config", "--get", "user.name"]).decode().strip()
  except:
    userid = "unknown"
  if action == "simulation":
      top = sim_top
      tool = sim_tool
  else:
      top = syn_top
      tool = syn_tool
  f.write("-- Buildinfo for project {}\n".format(top))
  f.write("--\n")
  f.write("-- This file was automatically generated; do not edit\n")
  f.write("\n")
  f.write("package buildinfo_pkg is\n")
  f.write("  constant buildinfo : string :=\n")
  f.write('       "buildinfo:1" & LF\n')
  f.write('     & "module:{}" & LF\n'.format(top))
  f.write('     & "commit:{}" & LF\n'.format(commitid + dirty))
  f.write('     & "tag:{}" & LF\n'.format(tag))
  f.write('     & "syntool:{}" & LF\n'.format(tool))
  f.write('     & "syndate:{}" & LF\n'.format(
      time.strftime("%F, %H:%M %Z", time.localtime())))
  f.write('     & "synauth:{}" & LF;\n'.format(userid))
  f.write('end buildinfo_pkg;\n')
