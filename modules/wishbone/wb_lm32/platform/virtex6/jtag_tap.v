
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

// Unfortunately the exit1 state for DR (e1dr) is mising
// We can simulate it by interpretting 'update' as e1dr and delaying 'update'
wire sel;
wire g_capture;
wire g_shift;
wire g_update;
reg update_delay;

assign capture = g_capture & sel;
assign shift = g_shift & sel;
assign e1dr = g_update & sel;
assign update = update_delay;

//BSCAN_SPARTAN6 #(
//    .JTAG_CHAIN(1)
//) bscan (
//    .CAPTURE(g_capture),
//    .DRCK(tck),
//    .RESET(reset),
//    .RUNTEST(),
//    .SEL(sel),
//    .SHIFT(g_shift),
//    .TCK(),
//    .TDI(tdi),
//    .TMS(),
//    .UPDATE(g_update),
//    .TDO(tdo)
//);

// Don't really know why tck was assined to DRCK.
BSCAN_VIRTEX6 #(
      //.DISABLE_JTAG("FALSE"),             // This attribute is unsupported. Please leave it at default.
      .JTAG_CHAIN(2)                        // Value for USER command. Possible values: (1,2,3 or 4).
  ) bscan (
      .CAPTURE(g_capture),                  // 1-bit output: CAPTURE output from TAP controller
      //.DRCK(tck),                           // 1-bit output: Data register output for USER functions
      .DRCK(),                           // 1-bit output: Data register output for USER functions
      .RESET(reset),                        // 1-bit output: Reset output for TAP controller
      .RUNTEST(),                           // 1-bit output: State output asserted when TAP controller is in Run Test Idle state.
      .SEL(sel),                            // 1-bit output: USER active output
      .SHIFT(g_shift),                      // 1-bit output: SHIFT output from TAP controller
      .TCK(tck),                            // 1-bit output: Scan Clock output. Fabric connection to TAP Clock pin.
      .TDI(tdi),                            // 1-bit output: TDI output from TAP controller
      .TMS(),                               // 1-bit output: Test Mode Select input. Fabric connection to TAP.
      .UPDATE(g_update),                    // 1-bit output: UPDATE output from TAP controller
      .TDO(tdo)                             // 1-bit input: Data input for USER function
   );

always@(posedge tck)
    update_delay <= g_update;

endmodule
