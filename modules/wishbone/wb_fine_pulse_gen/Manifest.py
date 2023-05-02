import logging

if target == "xilinx":
    files = [
        "fine_pulse_gen_kintex7_shared.vhd",
        "fine_pulse_gen_kintexultrascale_shared.vhd",
        "fine_pulse_gen_kintex7.vhd",
        "fine_pulse_gen_kintexultrascale.vhd",
        "wb_fpgen_regs.vhd",
        "xwb_fine_pulse_gen.vhd"]
else:
    logging.info("Library component wb_fine_pulse_gen targets only xilinx devices")
