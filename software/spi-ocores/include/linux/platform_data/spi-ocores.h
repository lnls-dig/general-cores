// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Federico Vaga <federico.vaga@cern.ch>
 */

#ifndef __SPI_OCORES_PDATA_H__
#define __SPI_OCORES_PDATA_H__

#include <linux/spi/spi.h>

/**
 * struct spi_ocores_platform_data - OpenCores SPI data
 */
struct spi_ocores_platform_data {
	unsigned int big_endian;
	unsigned int clock_hz;
	unsigned int num_devices;
	struct spi_board_info *devices;
};

#endif
