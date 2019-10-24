/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Copyright (c) 2016 CERN
 * Author: Federico Vaga <federico.vaga@cern.ch>
 */

#ifndef __HTVIC_H__
#define __HTVIC_H__

#include <linux/debugfs.h>
#include "htvic_regs.h"

#define VIC_MAX_VECTORS 32

#define VIC_SDB_VENDOR 0xce42
#define VIC_SDB_DEVICE 0x0013
#define VIC_IRQ_BASE_NUMBER 0

enum htvic_versions {
	HTVIC_VER_SPEC = 0,
	HTVIC_VER_SVEC,
	HTVIC_VER_WRSWI,
};

enum htvic_mem_resources {
	HTVIC_MEM_BASE = 0,
};

struct htvic_data {
	uint32_t is_edge; /* 1 edge, 0 level */
	uint32_t is_raising; /* 1 raising, 0 falling */
	uint32_t pulse_len;
};

struct memory_ops {
	u32 (*read)(void *addr);
	void (*write)(u32 value, void *addr);
};

struct htvic_device {
	struct platform_device *pdev;
	struct irq_domain *domain;
	unsigned int hwid[VIC_MAX_VECTORS]; /**> original ID from FPGA */
	struct htvic_data *data;
	void __iomem *kernel_va;
	struct memory_ops memop;
	int irq;

	irq_flow_handler_t platform_handle_irq;
	void *platform_handler_data;

	struct dentry *dbg_dir;
#define HTVIC_DBG_INFO_NAME "info"
	struct dentry *dbg_info;
#define HTVIC_DBG_REG_NAME "reg"
	struct dentry *dbg_reg;
#define HTVIC_DBG_SWIRQ_NAME "swirq"
	struct dentry *dbg_swirq;
};


static inline u32 htvic_ioread(struct htvic_device *htvic, void __iomem *addr)
{
	return htvic->memop.read(addr);
}

static inline void htvic_iowrite(struct htvic_device *htvic,
				u32 value, void __iomem *addr)
{
	return htvic->memop.write(value, addr);
}


static inline u32 __htvic_ioread32(void *addr)
{
	return ioread32(addr);
}

static inline u32 __htvic_ioread32be(void *addr)
{
	return ioread32be(addr);
}

static inline void __htvic_iowrite32(u32 value,void __iomem *addr)
{
	iowrite32(value, addr);
}

static inline void  __htvic_iowrite32be(u32 value, void __iomem *addr)
{
	iowrite32be(value, addr);
}

#endif
