ROOTDIR := $(shell pwd)
BUILDDIR := $(ROOTDIR)/.build
ARMBIANDIR := $(BUILDDIR)/armbian

KERNELFAMILY := sunxi
KERNELBRANCH := default
BOARD := orangepizero

IMAGEDEB := $(ARMBIANDIR)/output/debs/linux-image-next-sunxi_5.47_armhf.deb
DTBDEB := $(ARMBIANDIR)/output/debs/linux-dtb-next-sunxi_5.47_armhf.deb
DEBS := $(IMAGEDEB) $(DTBDEB)

UROOT := $(BUILDDIR)/bin/u-root

OUTPUTDIR := $(ROOTDIR)/output
KERNELIMAGE := $(OUTPUTDIR)/zImage
INITFSIMAGE := $(OUTPUTDIR)/uInitrd
DTBIMAGE := $(OUTPUTDIR)/$(KERNELFAMILY)-$(BOARD).dtd
BOOTSCR := $(OUTPUTDIR)/boot.scr.uimg
OUTPUTIMAGES := $(KERNELIMAGE) $(INITFSIMAGE) $(DTBIMAGE) $(BOOTSCR)

.PHONY: all
all: $(OUTPUTIMAGES)

.PHONY: clean
clean:
	rm -Rf $(BUILDDIR)

$(ARMBIANDIR):
	git clone --depth 1 https://github.com/armbian/build $(ARMBIANDIR)

$(UROOT):
	GOPATH=$(BUILDDIR) go get github.com/u-root/u-root

$(DEBS): $(ARMBIANDIR)
	mkdir -p $(ARMBIANDIR)/userpatches
	cp $(ROOTDIR)/kernel/config/sun8i.config $(ARMBIANDIR)/userpatches/linux-$(KERNELFAMILY)-$(KERNELBRANCH).config
	$(ARMBIANDIR)/compile.sh BOARD=$(BOARD) BRANCH=next RELEASE=xenial \
		KERNEL_ONLY=yes KERNEL_CONFIGURE=no KERNEL_KEEP_CONFIG=no \
		INSTALL_HEADERS=no BUILD_DESKTOP=no \

$(KERNELIMAGE): $(DEBS)
	rm -Rf $(BUILDDIR)/unpacked/image
	mkdir -p $(BUILDDIR)/unpacked/image
	dpkg-deb -R $(IMAGEDEB) $(BUILDDIR)/unpacked/image
	mkdir -p $(OUTPUTDIR)
	cp $(BUILDDIR)/unpacked/image/boot/vmlinuz-4.14.51-sunxi $(KERNELIMAGE)

$(DTBIMAGE): $(DEBS)
	rm -Rf $(BUILDDIR)/unpacked/dtb
	mkdir -p $(BUILDDIR)/unpacked/dtb
	dpkg-deb -R $(DTBDEB) $(BUILDDIR)/unpacked/dtb
	mkdir -p $(OUTPUTDIR)
	cp $(BUILDDIR)/unpacked/dtb/boot/dtb-4.14.51-sunxi/sun8i-h2-plus-orangepi-zero.dtb $(DTBIMAGE)

$(INITFSIMAGE): $(UROOT)
	mkdir -p $(BUILDDIR)/uroot
	cd $(BUILDDIR)/src/github.com/u-root/u-root && GOPATH=$(BUILDDIR) GOARCH=arm $(UROOT) -format=cpio -build=bb -o $(BUILDDIR)/uroot/uroot.cpio ./cmds/*
	mkimage -A arm -O linux -T ramdisk -d $(BUILDDIR)/uroot/uroot.cpio $(INITFSIMAGE)

$(BOOTSCR): $(ROOTDIR)/boot/boot.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot.cmd $(BOOTSCR)
