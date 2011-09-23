module jtag_tap(
  output tck,
  output tdi,
  input tdo,
  output capture,
  output shift,
  output e1dr,
  output update,
  output reset
);

assign reset = 0;
wire nil1, nil2, nil3, nil4;

sld_virtual_jtag altera_jtag(
  .ir_in       		(),
  .ir_out		(),
  .tck			(tck),
  .tdo			(tdo),
  .tdi			(tdi),
  .virtual_state_cdr	(capture), // capture DR -> load shift register
  .virtual_state_sdr	(shift),   // shift      -> shift register from TDI to TDO
  .virtual_state_e1dr	(e1dr),    // done shift -> ignore (might shift more yet)
  .virtual_state_pdr	(nil1),    // paused     -> ignore
  .virtual_state_e2dr	(nil2),    // done pause -> ignore
  .virtual_state_udr	(update),  // update DR  -> load state from shift
  .virtual_state_cir	(nil3),    // capture IR -> write ir_out
  .virtual_state_uir	(nil4)     // update IR  -> read  ir_in
  // synopsys translate_off
  ,
  .jtag_state_cdr	(),
  .jtag_state_cir	(),
  .jtag_state_e1dr	(),
  .jtag_state_e1ir	(),
  .jtag_state_e2dr	(),
  .jtag_state_e2ir	(),
  .jtag_state_pdr	(),
  .jtag_state_pir	(),
  .jtag_state_rti	(),
  .jtag_state_sdr	(),
  .jtag_state_sdrs	(),
  .jtag_state_sir	(),
  .jtag_state_sirs	(),
  .jtag_state_tlr	(), // test logic reset
  .jtag_state_udr	(),
  .jtag_state_uir	(),
  .tms			()
  // synopsys translate_on
  );

defparam
   altera_jtag.sld_auto_instance_index = "YES",
   altera_jtag.sld_instance_index = 0,
   altera_jtag.sld_ir_width = 1,
   altera_jtag.sld_sim_action = "",
   altera_jtag.sld_sim_n_scan = 0,
   altera_jtag.sld_sim_total_length = 0;

endmodule
