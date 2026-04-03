ROOTDIR := $(shell pwd)
BUILDDIR := $(ROOTDIR)/.build
KERNELDIR := $(BUILDDIR)/kernel

OUTPUTDIR := $(ROOTDIR)/output
KERNELIMAGE := $(OUTPUTDIR)/zImage
DTBIMAGE := $(OUTPUTDIR)/binky-dcc-orangepi-zero.dtb
BOOTSCR := $(OUTPUTDIR)/boot.scr.uimg
BOOTDCCSCR := $(OUTPUTDIR)/boot-dcc.scr.uimg
OUTPUTIMAGES := $(KERNELIMAGE) $(DTBIMAGE) $(BOOTSCR) $(BOOTDCCSCR)
TGZFILE := $(OUTPUTDIR)/blw.tgz

.PHONY: all
all: $(TGZFILE)

.PHONY: clean
clean:
	sudo rm -Rf $(BUILDDIR)

bootstrap:
	sudo apt update
	sudo apt install gcc-arm-linux-gnueabihf build-essential bison flex libssl-dev bc

$(KERNELDIR):
	git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git $(KERNELDIR)

compile: $(KERNELDIR)
	cp $(ROOTDIR)/kernel/config/sun8i.config $(KERNELDIR)/.config
	cp $(ROOTDIR)/kernel/dts/binky-dcc-orangepi-zero.dts $(KERNELDIR)/arch/arm/boot/dts/sun8i-h2-plus-custom.dts
	cd $(KERNELDIR) ; make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- oldconfig
	cd $(KERNELDIR) ; make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules

$(KERNELIMAGE): compile
	cp $(KERNELDIR)/arch/arm/boot/zImage $(KERNELIMAGE)

$(DTBIMAGE): compile
	cp $(KERNELDIR)/arch/arm/boot/dts/sun8i-h2-plus-custom.dtb $(DTBIMAGE)

$(BOOTSCR): $(ROOTDIR)/boot/boot.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot.cmd $(BOOTSCR)

$(BOOTDCCSCR): $(ROOTDIR)/boot/boot-dcc.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot-dcc.cmd $(BOOTDCCSCR)

$(TGZFILE): $(OUTPUTIMAGES)
	tar zcvf $(TGZFILE) -C $(OUTPUTDIR) -P --transform='s!^$(OUTPUTDIR)/!!' --show-transformed $(OUTPUTIMAGES)
