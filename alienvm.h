#ifndef ALIENVM_H
#define ALIENVM_H

#define AVM_MMIO_SERIAL_OUT_DESC_PTR			0xe0000000
#define AVM_MMIO_SERIAL_OUT_DESC_PTR_MASK		0xfffff000
#define AVM_MMIO_SERIAL_OUT_SETUP			0xe0000004
#define AVM_MMIO_SERIAL_OUT_SETUP_ENABLE		0x00000001
#define AVM_MMIO_SERIAL_OUT_SETUP_NPAGES_M1_MASK	0x0000ff00
#define AVM_MMIO_SERIAL_OUT_SETUP_NPAGES_M1_SHIFT	8
#define AVM_MMIO_SERIAL_OUT_SETUP_MASK			0x0000ff01
#define AVM_MMIO_SERIAL_OUT_NOTIFY			0xe0000008

#define AVM_SERIAL_OUT_DESC_BUFFER_PTR(i)		(0x000 + (i) * 4)
#define AVM_SERIAL_OUT_DESC_PUT				0x800
#define AVM_SERIAL_OUT_DESC_GET				0xc00

#define AVM_MMIO_SERIAL_IN_DESC_PTR			0xe0001000
#define AVM_MMIO_SERIAL_IN_DESC_PTR_MASK		0xfffff000
#define AVM_MMIO_SERIAL_IN_SETUP			0xe0001004
#define AVM_MMIO_SERIAL_IN_SETUP_ENABLE			0x00000001
#define AVM_MMIO_SERIAL_IN_SETUP_NPAGES_M1_MASK		0x0000ff00
#define AVM_MMIO_SERIAL_IN_SETUP_NPAGES_M1_SHIFT	8
#define AVM_MMIO_SERIAL_IN_SETUP_MASK			0x0000ff01
#define AVM_MMIO_SERIAL_IN_NOTIFY			0xe0001008

#define AVM_SERIAL_IN_DESC_BUFFER_PTR(i)		(0x000 + (i) * 4)
#define AVM_SERIAL_IN_DESC_GET				0x800
#define AVM_SERIAL_IN_DESC_PUT				0xc00

#define AVM_MMIO_BLOCK_DESC_PTR				0xe0002000
#define AVM_MMIO_BLOCK_DESC_PTR_MASK			0xfffff000
#define AVM_MMIO_BLOCK_SETUP				0xe0002004
#define AVM_MMIO_BLOCK_SETUP_ENABLE			0x00000001
#define AVM_MMIO_BLOCK_SETUP_NREQUESTS_M1_MASK		0x00007f00
#define AVM_MMIO_BLOCK_SETUP_NREQUESTS_M1_SHIFT		8
#define AVM_MMIO_BLOCK_SETUP_MASK			0x00007f01
#define AVM_MMIO_BLOCK_NOTIFY				0xe0002008
#define AVM_MMIO_BLOCK_CAPACITY				0xe000200c

#define AVM_BLOCK_DESC_REQ_BUFFER_PTR(i)		(0x000 + (i) * 0x10)
#define AVM_BLOCK_DESC_REQ_BLOCK_IDX(i)			(0x004 + (i) * 0x10)
#define AVM_BLOCK_DESC_REQ_TYPE(i)			(0x008 + (i) * 0x10)
#define AVM_BLOCK_DESC_REQ_TYPE_READ			0
#define AVM_BLOCK_DESC_REQ_TYPE_WRITE			1
#define AVM_BLOCK_DESC_REQ_STATUS(i)			(0x00c + (i) * 0x10)
#define AVM_BLOCK_DESC_REQ_STATUS_SUCCESS		0
#define AVM_BLOCK_DESC_REQ_STATUS_INVALID_IDX		1
#define AVM_BLOCK_DESC_REQ_STATUS_IO_ERROR		2
#define AVM_BLOCK_DESC_PUT				0x800
#define AVM_BLOCK_DESC_GET				0xc00

#define AVM_IRQ_SERIAL_OUT				3
#define AVM_IRQ_SERIAL_IN				4
#define AVM_IRQ_BLOCK					5

#define AVM_PORT_DEBUG_OUT				0x0800
#define AVM_PORT_SHUTDOWN				0x0900

#define AVM_PAGE_SIZE					0x1000
#define AVM_PAGE_SHIFT					12

#define AVM_RAM_BASE					0x00000000
#define AVM_RAM_SIZE					0x1000000
#define AVM_BIOS_BASE					0xffff0000
#define AVM_BIOS_SIZE					0x10000

#endif