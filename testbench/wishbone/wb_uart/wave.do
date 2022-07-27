onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/clk_sys_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rst_n_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_adr_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_dat_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_dat_o
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_cyc_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_sel_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_stb_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_we_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_ack_o
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_stall_o
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/int_o
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/uart_rxd_i
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/uart_txd_o
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_ready_reg
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_ready
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/uart_bcr
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rdr_rack
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/host_rack
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/baud_tick
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/baud_tick8
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/resized_addr
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_in
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/wb_out
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/regs_in
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/regs_out
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/vuart_fifo_empty
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/vuart_fifo_full
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/vuart_fifo_rd
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/vuart_fifo_wr
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/vuart_fifo_count
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/tx_fifo_empty
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/tx_fifo_full
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/tx_fifo_rd
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/tx_fifo_wr
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/tx_fifo_count
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/tx_fifo_reset_n
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_fifo_empty
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_fifo_full
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_fifo_overflow
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_fifo_rd
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_fifo_wr
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_fifo_count
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/rx_fifo_reset_n
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/phys_rx_ready
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/phys_tx_busy
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/phys_tx_start
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/phys_rx_data
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/phys_tx_data
add wave -noupdate -group UartFifo /main/DUT_FIFO/U_Wrapped_UART/tx_fifo_state
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/rst_n_i
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/clk_i
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/d_i
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/we_i
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/q_o
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/rd_i
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/empty_o
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/full_o
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/almost_empty_o
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/almost_full_o
add wave -noupdate -group TXFIFO /main/DUT_FIFO/U_Wrapped_UART/gen_phys_fifos/U_UART_TX_FIFO/count_o
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/clk_sys_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rst_n_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_adr_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_dat_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_dat_o
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_cyc_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_sel_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_stb_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_we_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_ack_o
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_stall_o
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/int_o
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/uart_rxd_i
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/uart_txd_o
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_ready_reg
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_ready
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/uart_bcr
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rdr_rack
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/host_rack
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/baud_tick
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/baud_tick8
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/resized_addr
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_in
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/wb_out
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/regs_in
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/regs_out
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/vuart_fifo_empty
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/vuart_fifo_full
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/vuart_fifo_rd
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/vuart_fifo_wr
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/vuart_fifo_count
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/tx_fifo_empty
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/tx_fifo_full
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/tx_fifo_rd
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/tx_fifo_wr
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/tx_fifo_count
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/tx_fifo_reset_n
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_fifo_empty
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_fifo_full
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_fifo_overflow
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_fifo_rd
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_fifo_wr
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_fifo_count
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/rx_fifo_reset_n
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/phys_rx_ready
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/phys_tx_busy
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/phys_tx_start
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/phys_rx_data
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/phys_tx_data
add wave -noupdate -expand -group UartNoFifo /main/DUT_NO_FIFO/U_Wrapped_UART/tx_fifo_state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {12968000000 fs} 0}
configure wave -namecolwidth 298
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 fs} {109552789280 fs}
