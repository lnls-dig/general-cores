def __helper():
  dirs = [
    "wb_async_bridge",
    "wb_onewire_master",
    "wb_i2c_master",
    "wb_bus_fanout",
    "wb_dpram",
    "wb_gpio_port",
    "wb_simple_timer",
    "wb_uart",
    "wb_vic",
    "wb_spi",
    "wb_crossbar",
    "wb_lm32",
    "wb_slave_adapter",
    "wb_xilinx_fpga_loader",
    "wb_clock_crossing",
    "wb_dma",
    "wb_serial_lcd",
		"wb_simple_pwm",
    "wbgen2"
    ]
  if (target == "altera"): dirs.extend(["wb_pcie"]);
  return dirs

modules =  { "local" : __helper() };

files = ["wishbone_pkg.vhd"];
