ROOTDIR := $(shell pwd)
BUILDDIR := $(ROOTDIR)/.build
ARMBIANDIR := $(BUILDDIR)/armbian

KERNELFAMILY := sunxi
KERNELBRANCH := next
KERNELVERSION := 4.14.85
BOARD := orangepizero

IMAGEDEB := $(ARMBIANDIR)/output/debs/linux-image-next-sunxi_20.11.0-trunk_armhf.deb
DTBDEB := $(ARMBIANDIR)/output/debs/linux-dtb-next-sunxi_20.11.0-trunk_armhf.deb
DEBS := $(IMAGEDEB) $(DTBDEB)

UROOT := $(BUILDDIR)/bin/u-root

BNLOCALWORKER := $(ROOTDIR)/../LocalWorker/bnLocalWorker

OUTPUTDIR := $(ROOTDIR)/output
KERNELIMAGE := $(OUTPUTDIR)/zImage
INITFSIMAGE := $(OUTPUTDIR)/uInitrd
DTBIMAGE := $(OUTPUTDIR)/$(KERNELFAMILY)-$(BOARD).dtb
BOOTSCR := $(OUTPUTDIR)/boot.scr.uimg
OUTPUTIMAGES := $(KERNELIMAGE) $(INITFSIMAGE) $(DTBIMAGE) $(BOOTSCR)

.PHONY: all
all: $(OUTPUTIMAGES)

.PHONY: clean
clean:
	sudo rm -Rf $(BUILDDIR)

$(ARMBIANDIR):
	git clone --depth 1 https://github.com/armbian/build $(ARMBIANDIR)

$(UROOT):
	GOPATH=$(BUILDDIR) go get github.com/u-root/u-root

$(DEBS): $(ARMBIANDIR) $(ROOTDIR)/kernel/config/sun8i.config
	mkdir -p $(ARMBIANDIR)/userpatches
	#mkdir -p $(ARMBIANDIR)/userpatches/kernel/$(KERNELFAMILY)-$(KERNELBRANCH)/
	#cp $(ROOTDIR)/kernel/patches/* $(ARMBIANDIR)/userpatches/kernel/$(KERNELFAMILY)-$(KERNELBRANCH)/
	cp $(ROOTDIR)/kernel/config/sun8i.config $(ARMBIANDIR)/userpatches/linux-$(KERNELFAMILY)-$(KERNELBRANCH).config
	$(ARMBIANDIR)/compile.sh docker BOARD=$(BOARD) BRANCH=next RELEASE=xenial \
		KERNEL_ONLY=yes KERNEL_CONFIGURE=no KERNEL_KEEP_CONFIG=no \
		INSTALL_HEADERS=no BUILD_DESKTOP=no \

$(KERNELIMAGE): $(DEBS)
	rm -Rf $(BUILDDIR)/unpacked/image
	mkdir -p $(BUILDDIR)/unpacked/image
	dpkg-deb -R $(IMAGEDEB) $(BUILDDIR)/unpacked/image
	mkdir -p $(OUTPUTDIR)
	cp $(BUILDDIR)/unpacked/image/boot/vmlinuz-$(KERNELVERSION)-sunxi $(KERNELIMAGE)

$(DTBIMAGE): $(ROOTDIR)/kernel/dts/sun8i-h2-plus-orangepi-zero.dts
	mkdir -p $(OUTPUTDIR)
	dtc -I dts -O dtb -o $(DTBIMAGE) kernel/dts/sun8i-h2-plus-orangepi-zero.dts

$(INITFSIMAGE): $(UROOT) $(BNLOCALWORKER)
	mkdir -p $(BUILDDIR)/uroot
	cd $(BUILDDIR)/src/github.com/u-root/u-root && GOPATH=$(BUILDDIR) GOARCH=arm $(UROOT) \
		-format=cpio -build=bb -o $(BUILDDIR)/uroot/uroot.cpio \
		-files=$(BNLOCALWORKER):bin/bnLocalWorker \
		-defaultsh=/bin/bnLocalWorker \
		./cmds/*
	mkimage -A arm -O linux -T ramdisk -d $(BUILDDIR)/uroot/uroot.cpio $(INITFSIMAGE)

$(BOOTSCR): $(ROOTDIR)/boot/boot.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot.cmd $(BOOTSCR)
