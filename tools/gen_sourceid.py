# Script to generate the buildinfo_pkg.vhd file
# Local parameter: project

with open("sourceid_{}_pkg.vhd".format(project), "w") as f:
  import subprocess
  import time

  # Extract current commit id.
  try:
    sourceid = subprocess.check_output(
      ["git", "log", "-1", "--format=%H"]).decode().strip()
    sourceid = sourceid[0:32]
  except:
    sourceid = 16 * "00"

  # Extract current tag + dirty indicator.
  # It is not sure if the definition of dirty is stable across all git versions.
  try:
    tag = subprocess.check_output(
      ["git", "describe", "--dirty", "--always"]).decode().strip()
    dirty = tag.endswith('-dirty')
  except:
    dirty = True

  if dirty:
      #  There is no room for a dirty flag, just erase half of the bytes, so
      #  that's obvious it's not a real sha1, and still leaves enough to
      #  find the sha1 in the project.
      sourceid = sourceid[:16] + (16 * '0')

  f.write("-- Sourceid for project {}\n".format(project))
  f.write("--\n")
  f.write("-- This file was automatically generated; do not edit\n")
  f.write("\n")
  f.write("library ieee;")
  f.write("use ieee.std_logic_1164.all;")
  f.write("\n")
  f.write("package sourceid_{}_pkg is\n".format(project))
  f.write("  constant sourceid : std_logic_vector(127 downto 0) :=\n")
  f.write('       x"{}";\n'.format(sourceid))
  f.write('end sourceid_{}_pkg;\n'.format(project))
