import logging

if target == "xilinx":
    files = ["wb_xc7_fw_update_regs.vhd",
             "xwb_xc7_fw_update.vhd",
             "xwb_xc7_fw_update_v2.vhd",
    ]
else:
    logging.info("Library component wb_xc7_fw_update targets only xilinx devices")
