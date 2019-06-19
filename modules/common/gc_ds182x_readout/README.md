## gc_ds182x_readout

The gc_ds182x_readout core provides a direct interface to the high-precision 1-wire digital termometer DS1820 chip.

The temperature is read every second.  The read process is either triggered by the `pps_p_i` input or started automatically from the clock if the generic `g_USE_INTERNAL_PPS` is set to True.  Note that the DS18B20 chip needs up to 750ms to read the temperature.

It is important to correctly set the frequency as the 1-wire protocol is time based.

When using the DS18B20 (like on the SPEC), the temperature is in 1/16 degrees.