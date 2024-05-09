ROOTDIR := $(shell pwd)
BUILDDIR := $(ROOTDIR)/.build
ARMBIANDIR := $(BUILDDIR)/armbian

KERNELFAMILY := sunxi
KERNELBRANCH := current
KERNELVERSION := 6.1.63
ARMBIAN_BOARD := orangepizero
ARMBIAN_BRANCH := current
ARMBIAN_RELEASE := jammy

DEBSUFFIX := sunxi_23.11.0-trunk_armhf__6.1.63-S69e4-Df461-Paef8-Ccb92Hfe66-HK01ba-V014b-B1743-R448a
IMAGEDEB := $(ARMBIANDIR)/output/debs/linux-image-current-$(DEBSUFFIX).deb
DTBDEB := $(ARMBIANDIR)/output/debs/linux-dtb-current-$(DEBSUFFIX).deb
DEBS := $(IMAGEDEB) $(DTBDEB)

UROOT := $(BUILDDIR)/bin/u-root

BNLOCALWORKER := $(ROOTDIR)/../LocalWorker/bin/linux/arm/bnLocalWorker

OUTPUTDIR := $(ROOTDIR)/output
KERNELIMAGE := $(OUTPUTDIR)/zImage
DTBIMAGE := $(OUTPUTDIR)/$(KERNELFAMILY)-$(ARMBIAN_BOARD).dtb
BOOTSCR := $(OUTPUTDIR)/boot.scr.uimg
BOOTDCCSCR := $(OUTPUTDIR)/boot-dcc.scr.uimg
OUTPUTIMAGES := $(KERNELIMAGE) $(DTBIMAGE) $(BOOTSCR) $(BOOTDCCSCR)
TGZFILE := $(OUTPUTDIR)/blw.tgz

.PHONY: all
all: $(TGZFILE) 

.PHONY: clean
clean:
	sudo rm -Rf $(BUILDDIR)

$(ARMBIANDIR):
	git clone --depth 1 --branch=v23.11 https://github.com/armbian/build $(ARMBIANDIR)

$(UROOT):
	GOPATH=$(BUILDDIR) go get github.com/u-root/u-root

$(DEBS): $(ARMBIANDIR) $(ROOTDIR)/kernel/config/sun8i.config
	mkdir -p $(ARMBIANDIR)/userpatches
	#mkdir -p $(ARMBIANDIR)/userpatches/kernel/$(KERNELFAMILY)-$(KERNELBRANCH)/
	#cp $(ROOTDIR)/kernel/patches/* $(ARMBIANDIR)/userpatches/kernel/$(KERNELFAMILY)-$(KERNELBRANCH)/
	cp $(ROOTDIR)/kernel/config/sun8i.config $(ARMBIANDIR)/userpatches/linux-$(KERNELFAMILY)-$(KERNELBRANCH).config
	$(ARMBIANDIR)/compile.sh kernel \
		BOARD=$(ARMBIAN_BOARD) BRANCH=$(ARMBIAN_BRANCH) RELEASE=$(ARMBIAN_RELEASE) \
		BUILD_MINIMAL=yes \
		KERNEL_CONFIGURE=no KERNEL_KEEP_CONFIG=no \
		INSTALL_HEADERS=no BUILD_DESKTOP=no

$(KERNELIMAGE): $(DEBS)
	rm -Rf $(BUILDDIR)/unpacked/image
	mkdir -p $(BUILDDIR)/unpacked/image
	dpkg-deb -R $(IMAGEDEB) $(BUILDDIR)/unpacked/image
	mkdir -p $(OUTPUTDIR)
	cp $(BUILDDIR)/unpacked/image/boot/vmlinuz-$(KERNELVERSION)-$(KERNELBRANCH)-sunxi $(KERNELIMAGE)

$(DTBIMAGE): $(ROOTDIR)/kernel/dts/sun8i-h2-plus-orangepi-zero.dts
	mkdir -p $(OUTPUTDIR)
	dtc -I dts -O dtb -o $(DTBIMAGE) kernel/dts/sun8i-h2-plus-orangepi-zero.dts

$(BOOTSCR): $(ROOTDIR)/boot/boot.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot.cmd $(BOOTSCR)

$(BOOTDCCSCR): $(ROOTDIR)/boot/boot-dcc.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot-dcc.cmd $(BOOTDCCSCR)

$(TGZFILE): $(OUTPUTIMAGES)
	tar zcvf $(TGZFILE) -C $(OUTPUTDIR) --transform='s!^$(OUTPUTDIR)/!!' --show-transformed $(OUTPUTIMAGES)
