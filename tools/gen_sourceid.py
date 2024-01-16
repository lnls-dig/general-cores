# Script to generate the sourceid_<project>_pkg.vhd file
# Local parameter: project

# Note: this script differs from the (similar) gen_buildinfo.py in that it produces std_logic
# vectors with versioning info to be embedded in the metadata, while buildinfo produces a string
# that focuses more on when/how/who built the bitstream.

with open("sourceid_{}_pkg.vhd".format(project), "w") as f:
  import subprocess
  import time
  import re

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

  try:
    version = re.search("\d+\.\d+\.\d+", tag)
    major,minor,patch = [int(x) for x in version.group().split('.')]
  except:
    major = minor = patch = 0

  if dirty:
      #  There is no room for a dirty flag, just erase half of the bytes, so
      #  that's obvious it's not a real sha1, and still leaves enough to
      #  find the sha1 in the project.
      sourceid = sourceid[:16] + (16 * '0')

  f.write("-- Sourceid for project {}\n".format(project))
  f.write("--\n")
  f.write("-- This file was automatically generated; do not edit\n")
  f.write("\n")
  f.write("library ieee;\n")
  f.write("use ieee.std_logic_1164.all;\n")
  f.write("\n")
  f.write("package sourceid_{}_pkg is\n".format(project))
  f.write("  constant sourceid : std_logic_vector(127 downto 0) :=\n")
  f.write('       x"{}";\n'.format(sourceid))
  f.write("  constant version : std_logic_vector(31 downto 0) := ")
  f.write('x"{:02x}{:02x}{:04x}";\n'.format(major & 0xff, minor & 0xff, patch & 0xffff))
  f.write('end sourceid_{}_pkg;\n'.format(project))
