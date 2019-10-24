// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (c) 2016 CERN
 * Author: Federico Vaga <federico.vaga@cern.ch>
 *
 * Driver for the HT-VIC IRQ controller
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/version.h>
#include <linux/irqdomain.h>
#include <linux/irq.h>
#include <linux/interrupt.h>
#include <linux/slab.h>
#include <linux/platform_device.h>
#include <linux/io.h>

#include "htvic.h"

static int htvic_dbg_info(struct seq_file *s, void *offset)
{
	struct htvic_device *htvic = s->private;
	int i;

	seq_printf(s, "%s:\n",dev_name(&htvic->pdev->dev));

	seq_printf(s, "  redirect: %d\n", platform_get_irq(htvic->pdev, 0));
	seq_printf(s, "  irq-mapping:\n");
	for (i = 0; i < VIC_MAX_VECTORS; ++i) {
		seq_printf(s, "    - hardware: %d\n", i);
		seq_printf(s, "      linux: %d\n",
			   irq_find_mapping(htvic->domain, i));
	}

	return 0;
}

static int htvic_dbg_info_open(struct inode *inode, struct file *file)
{
	struct htvic_device *htvic = inode->i_private;

	return single_open(file, htvic_dbg_info, htvic);
}

static const struct file_operations htvic_dbg_info_ops = {
	.owner = THIS_MODULE,
	.open  = htvic_dbg_info_open,
	.read = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
};

static int htvic_dbg_reg(struct seq_file *s, void *offset)
{
	struct htvic_device *htvic = s->private;
	uint32_t val;
	void *addr;
	int i;

#define VIC_REG_N 8
	for (i = 0, addr = htvic->kernel_va; i < VIC_REG_N ; ++i, addr +=4) {
		val = htvic_ioread(htvic, addr);
		seq_printf(s, "%p = 0x%08x\n", addr, val);
	}

	for (i = 0, addr = htvic->kernel_va + VIC_IVT_RAM_BASE;
	     i < VIC_MAX_VECTORS; ++i, addr +=4) {
		val = htvic_ioread(htvic, addr);
		seq_printf(s, "%p = 0x%08x\n", addr, val);
	}

	return 0;
}

static int htvic_dbg_reg_open(struct inode *inode, struct file *file)
{
	struct htvic_device *htvic = inode->i_private;

	return single_open(file, htvic_dbg_reg, htvic);
}

static const struct file_operations htvic_dbg_reg_ops = {
	.owner = THIS_MODULE,
	.open  = htvic_dbg_reg_open,
	.read = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
};

static ssize_t htvic_dbg_swirq_write(struct file *file,
				     const char __user *buf,
				     size_t count, loff_t *ppos)
{
	struct htvic_device *vic = file->private_data;

	htvic_iowrite(vic, 1, vic->kernel_va + VIC_REG_SWIR);

	return count;
}

static int htvic_dbg_swirq_open(struct inode *inode, struct file *file)
{
	struct htvic_device *htvic = inode->i_private;

	file->private_data = htvic;

	return 0;
}

static const struct file_operations htvic_dbg_swirq_ops = {
	.owner = THIS_MODULE,
	.open  = htvic_dbg_swirq_open,
	.write = htvic_dbg_swirq_write,
};

/**
 * It initializes the debugfs interface
 * @htvic: IRQ controler instance
 *
 * Return: 0 on success, otherwise a negative error number
 */
static int htvic_debug_init(struct htvic_device *htvic)
{
	htvic->dbg_dir = debugfs_create_dir(dev_name(&htvic->pdev->dev), NULL);
	if (IS_ERR_OR_NULL(htvic->dbg_dir)) {
		dev_err(&htvic->pdev->dev,
			"Cannot create debugfs directory (%ld)\n",
			PTR_ERR(htvic->dbg_dir));
		return PTR_ERR(htvic->dbg_dir);
	}

	htvic->dbg_info = debugfs_create_file(HTVIC_DBG_INFO_NAME, 0444,
					     htvic->dbg_dir, htvic,
					     &htvic_dbg_info_ops);
	if (IS_ERR_OR_NULL(htvic->dbg_info)) {
		dev_err(&htvic->pdev->dev,
			"Cannot create debugfs file \"%s\" (%ld)\n",
			HTVIC_DBG_INFO_NAME, PTR_ERR(htvic->dbg_info));
		return PTR_ERR(htvic->dbg_info);
	}

	htvic->dbg_reg = debugfs_create_file(HTVIC_DBG_REG_NAME, 0444,
					     htvic->dbg_dir, htvic,
					     &htvic_dbg_reg_ops);
	if (IS_ERR_OR_NULL(htvic->dbg_reg)) {
		dev_err(&htvic->pdev->dev,
			"Cannot create debugfs file \"%s\" (%ld)\n",
			HTVIC_DBG_REG_NAME, PTR_ERR(htvic->dbg_reg));
		return PTR_ERR(htvic->dbg_reg);
	}

	htvic->dbg_swirq = debugfs_create_file(HTVIC_DBG_SWIRQ_NAME, 0200,
					       htvic->dbg_dir, htvic,
					       &htvic_dbg_swirq_ops);
	if (IS_ERR_OR_NULL(htvic->dbg_swirq)) {
		dev_err(&htvic->pdev->dev,
			"Cannot create debugfs file \"%s\" (%ld)\n",
			HTVIC_DBG_SWIRQ_NAME, PTR_ERR(htvic->dbg_swirq));
		return PTR_ERR(htvic->dbg_reg);
	}

	return 0;
}

/**
 * It removes the debugfs interface
 * @htvic: IRQ controler instance
 */
static void htvic_debug_exit(struct htvic_device *htvic)
{
	if (htvic->dbg_dir)
		debugfs_remove_recursive(htvic->dbg_dir);
}

/**
 * End of interrupt for the VIC. In case of level interrupt,
 * there is no way to delegate this to the kernel
 */
static void htvic_eoi(struct irq_data *d)
{
	struct htvic_device *vic = irq_data_get_irq_chip_data(d);
	/*
	 * Any write operation acknowledges the pending interrupt.
	 * Then, VIC advances to another pending interrupt(s) or
	 * releases the master interrupt output.
	 */
	htvic_iowrite(vic, 1, vic->kernel_va + VIC_REG_EOIR);
}


static void htvic_mask_disable_reg(struct irq_data *d)
{
	struct htvic_device *htvic = irq_data_get_irq_chip_data(d);

	htvic_iowrite(htvic, 1 << d->hwirq,
		      htvic->kernel_va + VIC_REG_IDR);
}


static void htvic_unmask_enable_reg(struct irq_data *d)
{
	struct htvic_device *htvic = irq_data_get_irq_chip_data(d);

	htvic_iowrite(htvic, 1 << d->hwirq,
		      htvic->kernel_va + VIC_REG_IER);
}

static void htvic_irq_ack(struct irq_data *d)
{
}


/**
 *
 */
static unsigned int htvic_irq_startup(struct irq_data *d)
{
	struct htvic_device *vic = irq_data_get_irq_chip_data(d);
	int ret;

	ret = try_module_get(vic->pdev->dev.driver->owner);
	if (ret == 0) { /* 0 fail, 1 success */
		dev_err(&vic->pdev->dev,
			"Cannot pin the \"%s\" driver. Something really wrong is going on\n",
			vic->pdev->dev.driver->name);
		return 1;
	}

	htvic_unmask_enable_reg(d);
	return 0;
}


/**
 * Executed when a driver does `free_irq()`.
 */
static void htvic_irq_shutdown(struct irq_data *d)
{
	struct htvic_device *vic = irq_data_get_irq_chip_data(d);

	htvic_mask_disable_reg(d);
	module_put(vic->pdev->dev.driver->owner);
}

static int htvic_irq_set_type(struct irq_data *d, unsigned int flow_type)
{
	struct htvic_device *vic = irq_data_get_irq_chip_data(d);

	/* We support only levels */
	if (!(flow_type & IRQ_TYPE_LEVEL_MASK)) {
		dev_err(&vic->pdev->dev,
		       "%s: unsopported type 0x%x\n", __func__, flow_type);
		return -EINVAL;
	}

	return IRQ_SET_MASK_OK;
}

static struct irq_chip htvic_chip = {
	.name = "HT-VIC",
	.irq_startup = htvic_irq_startup,
	.irq_shutdown = htvic_irq_shutdown,
	.irq_ack  = htvic_irq_ack,
	.irq_eoi = htvic_eoi,
	.irq_mask_ack = htvic_mask_disable_reg,
	.irq_mask = htvic_mask_disable_reg,
	.irq_unmask = htvic_unmask_enable_reg,
	.irq_set_type = htvic_irq_set_type,
};

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4,7,0)
static int htvic_irq_domain_select(struct irq_domain *d, struct irq_fwspec *fwspec,
		      enum irq_domain_bus_token bus_token)
{
	struct htvic_device *htvic = d->host_data;
	/*
	 * FIXME this should point to htvic->pdev->dev.parent. Today it is not
	 * a problem for CERN-like installations, so we leave it like this
	 * so that the WR-stating kit works.
	 */
	struct device *dev = &htvic->pdev->dev;
	struct device *req_dev;

	if(fwspec->param_count != 2)
		return 0;

	req_dev = (struct device *) ((((unsigned long) fwspec->param[0]) << 32) |
		(((unsigned long) fwspec->param[1]) & 0xFFFFFFFF));

	return (dev == req_dev);
}
#endif

/**
 * Given the hardware IRQ and the Linux IRQ number (virtirq), configure the
 * Linux IRQ number in order to handle properly the incoming interrupts
 * on the hardware IRQ line.
 */
static int htvic_irq_domain_map(struct irq_domain *h,
				unsigned int virtirq,
				irq_hw_number_t hwirq)
{
	struct htvic_device *htvic = h->host_data;

	irq_set_chip_data(virtirq, htvic);
	irq_set_chip(virtirq, &htvic_chip);
	irq_set_handler(virtirq, handle_level_irq); /* not really used now */
	/* all handlers are directly nested */
	irq_set_nested_thread(virtirq, 1);

	/*
	 * It MUST be no-thread because the VIC EOI must occur AFTER
	 * the device handler ack its signal. Any way the interrupt from
	 * the carrier is already threaded (most likely, if not we will
	 * see problems)
	 */

	return 0;
}


static struct irq_domain_ops htvic_irq_domain_ops = {
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4,7,0)
	.select = htvic_irq_domain_select,
#endif
	.map = htvic_irq_domain_map,
};


/**
 * Mapping of HTVIC irqs to Linux irqs using linear IRQ domain
 */
static int htvic_irq_mapping(struct htvic_device *htvic)
{
	int i, irq;

	htvic->domain = irq_domain_add_linear((void *)&htvic->pdev->dev,
					      VIC_MAX_VECTORS,
					      &htvic_irq_domain_ops, htvic);
	if (!htvic->domain)
		return -ENOMEM;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(3,11,0)
	htvic->domain->name = kasprintf(GFP_KERNEL, "%s",
					dev_name(&htvic->pdev->dev));
#endif

	/* Create the mapping between HW irq and virtual IRQ number */
	for (i = 0; i < VIC_MAX_VECTORS; ++i) {
		htvic->hwid[i] = htvic_ioread(htvic, htvic->kernel_va +
					      VIC_IVT_RAM_BASE + 4 * i);
		htvic_iowrite(htvic, i,
			      htvic->kernel_va + VIC_IVT_RAM_BASE + 4 * i);

		irq = irq_create_mapping(htvic->domain, i);
		if (irq <= 0)
			goto out;
	}


	return 0;

out:
	irq_domain_remove(htvic->domain);
	return -EPERM;
}

/**
 * Check if the platform is providing all the necessary information
 * for the HTVIC to work properly.
 *
 * The HTVIC needs the following informations:
 * - a Linux IRQ number where it should attach itself
 * - a virtual address where to find the component
 */
static int htvic_validation(struct platform_device *pdev)
{
	struct resource *r;

	r = platform_get_resource(pdev, IORESOURCE_IRQ, 0);
	if (!r) {
		dev_err(&pdev->dev, "Carrier IRQ number is missing\n");
		return -EINVAL;
	}

	if (!(r->flags & (IORESOURCE_IRQ_HIGHEDGE |
			  IORESOURCE_IRQ_LOWEDGE |
			  IORESOURCE_IRQ_HIGHLEVEL |
			  IORESOURCE_IRQ_LOWLEVEL))) {
		dev_err(&pdev->dev,
			"Edge/Level High/Low information missing\n");
		return -EINVAL;
	}

	r = platform_get_resource(pdev, IORESOURCE_MEM, HTVIC_MEM_BASE);
	if (!r) {
		dev_err(&pdev->dev, "VIC base address is missing\n");
		return -EINVAL;
	}

	return 0;
}


/**
 * It acks any pending interrupt in order to avoid to bring the HTVIC
 * to a stable status (possibly)
 */
static inline void htvic_ack_pending(struct htvic_device *htvic)
{
	while (htvic_ioread(htvic, htvic->kernel_va + VIC_REG_RISR))
		htvic_iowrite(htvic, 1, htvic->kernel_va + VIC_REG_EOIR);
}


/**
 * This is the place to re-route interrupts to the proper handler
 */
static irqreturn_t htvic_handler(int irq, void *arg)
{
	struct htvic_device *htvic = arg;
	u32 risr;

	risr = htvic_ioread(htvic, htvic->kernel_va + VIC_REG_RISR);
	if (!risr) /* Nothing to do - not for us */
		return IRQ_NONE;

	do {
		unsigned int cascade_irq;
		uint32_t vect;

		vect = htvic_ioread(htvic, htvic->kernel_va + VIC_REG_VAR) & 0xFF;
		if (WARN(vect >= VIC_MAX_VECTORS,
			 "Invalid vector number %d\n", vect))
			return IRQ_HANDLED;

		cascade_irq = irq_find_mapping(htvic->domain, vect);
		dev_dbg(&htvic->pdev->dev, "Raw: 0x%x Vect: 0x%x, IRQ: %d\n",
			risr, vect, cascade_irq);
		risr &= ~(1 << vect);
		/*
		 * Ok, now we execute the handler for the given IRQ. Please
		 * note that this is not the action requested by the device driver
		 * but it is the handler defined during the IRQ mapping
		 */
		handle_nested_irq(cascade_irq);

		/**
		 * ATTENTION here the ack is actually an EOI.The kernel
		 * does not export the handle_edge_eoi_irq() handler which
		 * is the one we need here. The kernel offers us the
		 * handle_edge_irq() which use only the ack() function.
		 * So what actually we need to to is to call the ack
		 * function but not the eoi function.
		 */
		htvic_eoi(irq_get_irq_data(cascade_irq));
		/*
		 * Read the RISR register again (it could be any other
		 * register) to introduce a delay equivalent to the time
		 * necessary for the VIC to propagate the IRQ status line
		 * to the processor.
		 */
		htvic_ioread(htvic, htvic->kernel_va + VIC_REG_RISR);
	} while(risr);

	return IRQ_HANDLED;
}


/**
 * Create a new instance for this driver.
 */
static int htvic_probe(struct platform_device *pdev)
{
	struct htvic_device *htvic;
	const struct resource *r;
	unsigned long irq_flags = 0;
	uint32_t ctl;
	int ret;

	ret = htvic_validation(pdev);
	if (ret)
		return ret;

	htvic = kzalloc(sizeof(struct htvic_device), GFP_KERNEL);
	if (!htvic)
		return -ENOMEM;
	dev_set_drvdata(&pdev->dev, htvic);
	htvic->pdev = pdev;

	/*
	 * TODO theoretically speaking all the confguration should come
	 * from a platform_data structure. Since we do not have it yet,
	 * we proceed this way
	 */
	switch(pdev->id_entry->driver_data) {
	case HTVIC_VER_SPEC:
	case HTVIC_VER_WRSWI:
		htvic->memop.read = __htvic_ioread32;
		htvic->memop.write = __htvic_iowrite32;
		break;
	case HTVIC_VER_SVEC:
		htvic->memop.read = __htvic_ioread32be;
		htvic->memop.write = __htvic_iowrite32be;
		break;
	default:
		dev_err(&pdev->dev, "Can't identify memory operations\n");
		ret = -EINVAL;
		goto out_memop;
	}

	r = platform_get_resource(pdev, IORESOURCE_MEM, HTVIC_MEM_BASE);
	htvic->kernel_va = ioremap(r->start, resource_size(r));

	/* Disable the VIC during the configuration */
	htvic_iowrite(htvic, 0, htvic->kernel_va + VIC_REG_CTL);
	/* Disable also all interrupt lines */
	htvic_iowrite(htvic, ~0, htvic->kernel_va + VIC_REG_IDR);
	/* Ack any pending interrupt */
	htvic_ack_pending(htvic);

	ret = htvic_irq_mapping(htvic);
	if (ret)
		goto out_map;

	/* VIC configuration */
	ctl = 0;
	ctl |= VIC_CTL_ENABLE;
	irq_flags |= IRQF_SHARED;
	switch (pdev->id_entry->driver_data) {
	case HTVIC_VER_SPEC:	
		ctl |= VIC_CTL_POL;
		ctl |= VIC_CTL_EMU_EDGE;
		ctl |= VIC_CTL_EMU_LEN_W(250);
		irq_flags |= IRQF_TRIGGER_HIGH;
		break;
	case HTVIC_VER_SVEC:
		ctl |= VIC_CTL_POL;
		irq_flags |= IRQF_TRIGGER_HIGH;
		/* TODO what if we want and edge using the edge emulator? */
		break;
	case HTVIC_VER_WRSWI:
		break;
	default:
		goto out_ctl;
	}

	/*
	 * It depends on the platform and on the IRQ on which we are connecting
	 * but most likely our interrupt handler will be a thread
	 */
	htvic->irq = platform_get_irq(htvic->pdev, 0);
	ret = request_any_context_irq(htvic->irq,
				      htvic_handler, irq_flags,
				      dev_name(&pdev->dev),
				      htvic);
	if (ret < 0) {
		dev_err(&pdev->dev, "Can't request IRQ %d (%d)\n",
			platform_get_irq(htvic->pdev, 0), ret);
		goto out_req;
	}

	htvic_debug_init(htvic);
	htvic_iowrite(htvic, ctl, htvic->kernel_va + VIC_REG_CTL);

	return 0;

out_req:
out_ctl:
out_map:
out_memop:
	dev_set_drvdata(&pdev->dev, NULL);
	kfree(htvic);
	return ret;
}

/**
 * Unload the htvic driver from the platform
 */
static int htvic_remove(struct platform_device *pdev)
{
	struct htvic_device *htvic = dev_get_drvdata(&pdev->dev);
	/* struct irq_desc *desc = irq_to_desc(platform_get_irq(htvic->pdev, 0)); */
	int i;

	if (!htvic)
		return 0;

	htvic_debug_exit(htvic);

	/*
	 * Disable all interrupts to prevent spurious interrupt
	 * Disable also the HTVIC component for the very same reason,
	 * but this way on next instance even if we enable the VIC
	 * no interrupt will come unless configured.
	 */
	htvic_iowrite(htvic, ~0, htvic->kernel_va + VIC_REG_IDR);
	htvic_iowrite(htvic, 0, htvic->kernel_va + VIC_REG_CTL);

	/*
	 * Restore HTVIC vector table with it's original content
	 * Release Linux IRQ number
	 */
	for (i = 0; i < VIC_MAX_VECTORS; i++) {
		htvic_iowrite(htvic, htvic->hwid[i], htvic->kernel_va + VIC_IVT_RAM_BASE + 4 * i);
		irq_dispose_mapping(irq_find_mapping(htvic->domain, i));
	}


	free_irq(htvic->irq, htvic);

	/*
	 * Clear the memory and restore flags when needed
	 */
	irq_domain_remove(htvic->domain);
	kfree(htvic);
	dev_set_drvdata(&pdev->dev, NULL);

	return 0;
}


/**
 * List of supported platform
 */
static const struct platform_device_id htvic_id_table[] = {
	{	/* SPEC compatible */
		.name = "htvic-spec",
		.driver_data = HTVIC_VER_SPEC,
	}, {	/* SVEC compatible */
		.name = "htvic-svec",
		.driver_data = HTVIC_VER_SVEC,
	}, {
		.name = "htvic-wr-swi",
		.driver_data = HTVIC_VER_WRSWI,
	},
	{},
};


static struct platform_driver htvic_driver = {
	.driver = {
		.name = "htvic",
		.owner = THIS_MODULE,
	},
	.id_table = htvic_id_table,
	.probe = htvic_probe,
	.remove = htvic_remove,
};
module_platform_driver(htvic_driver);

MODULE_AUTHOR("Federico Vaga <federico.vaga@cern.ch>");
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("CERN BECOHT VHDL Vector Interrupt Controller - HTVIC");
MODULE_DEVICE_TABLE(platform, htvic_id_table);

ADDITIONAL_VERSIONS;
