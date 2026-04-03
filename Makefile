ROOTDIR := $(shell pwd)
BUILDDIR := $(ROOTDIR)/.build
ARMBIANDIR := $(BUILDDIR)/armbian
KERNELDIR := $(ARMBIANDIR)/cache/sources/linux-kernel-worktree/6.12__sunxi__armhf

KERNELFAMILY := sunxi
KERNELBRANCH := current
KERNELVERSION := 6.12.80
ARMBIAN_COMMIT := v26.2.1
ARMBIAN_BOARD := orangepizero
ARMBIAN_BRANCH := current
ARMBIAN_RELEASE := jammy

DEBSUFFIX := sunxi_26.02.0-trunk_armhf__6.12.80-S00d7-Da8d3-P7ecf-Cae6c-H9b8e-HK01ba-V014b-Bcbc7-R448a
IMAGEDEB := $(ARMBIANDIR)/output/debs/linux-image-current-$(DEBSUFFIX).deb
DTBDEB := $(ARMBIANDIR)/output/debs/linux-dtb-current-$(DEBSUFFIX).deb
DEBS := $(IMAGEDEB) $(DTBDEB)

UROOT := $(BUILDDIR)/bin/u-root

BNLOCALWORKER := $(ROOTDIR)/../LocalWorker/bin/linux/arm/bnLocalWorker

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

$(ARMBIANDIR):
	git clone https://github.com/armbian/build $(ARMBIANDIR)
	cd $(ARMBIANDIR) ; git checkout $(ARMBIAN_COMMIT)

$(UROOT):
	GOPATH=$(BUILDDIR) go get github.com/u-root/u-root

$(DEBS): $(ARMBIANDIR) $(ROOTDIR)/kernel/config/sun8i.config
	# Prepare custom DTS
	mkdir -p $(ARMBIANDIR)/userpatches/kernel/$(KERNELFAMILY)-$(KERNELBRANCH)/
	cp $(ROOTDIR)/kernel/dts/binky-dcc-orangepi-zero.* $(ARMBIANDIR)/userpatches/kernel/$(KERNELFAMILY)-$(KERNELBRANCH)/
	# Prepare kernel config
	cp $(ROOTDIR)/kernel/config/sun8i.config $(ARMBIANDIR)/userpatches/linux-$(KERNELFAMILY)-$(KERNELBRANCH).config
	# Compile kernel
	$(ARMBIANDIR)/compile.sh kernel \
		BOARD=$(ARMBIAN_BOARD) BRANCH=$(ARMBIAN_BRANCH) RELEASE=$(ARMBIAN_RELEASE) \
		BUILD_MINIMAL=yes \
		KERNEL_CONFIGURE=no KERNEL_KEEP_CONFIG=no \
		INSTALL_HEADERS=no BUILD_DESKTOP=no EXTERNAL_DTS_NAME=binky-dcc-orangepi-zero

$(KERNELIMAGE): $(DEBS)
	rm -Rf $(BUILDDIR)/unpacked/image
	mkdir -p $(BUILDDIR)/unpacked/image
	dpkg-deb -R $(IMAGEDEB) $(BUILDDIR)/unpacked/image
	mkdir -p $(OUTPUTDIR)
	cp $(BUILDDIR)/unpacked/image/boot/vmlinuz-$(KERNELVERSION)-$(KERNELBRANCH)-sunxi $(KERNELIMAGE)

$(DTBIMAGE): $(DEBS)
	rm -Rf $(BUILDDIR)/unpacked/dtb
	mkdir -p $(BUILDDIR)/unpacked/dtb
	dpkg-deb -R $(DTBDEB) $(BUILDDIR)/unpacked/dtb
	mkdir -p $(OUTPUTDIR)
	cp $(BUILDDIR)/unpacked/dtb/boot/dtb-$(KERNELVERSION)-$(KERNELBRANCH)-sunxi/binky-dcc-orangepi-zero.dtb $(DTBIMAGE)
	#mkdir -p $(OUTPUTDIR)
	#dtc -I dts -O dtb -o $(DTBIMAGE) $(ROOTDIR)/kernel/dts/sun8i-h2-plus-orangepi-zero.dts

$(BOOTSCR): $(ROOTDIR)/boot/boot.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot.cmd $(BOOTSCR)

$(BOOTDCCSCR): $(ROOTDIR)/boot/boot-dcc.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot-dcc.cmd $(BOOTDCCSCR)

$(TGZFILE): $(OUTPUTIMAGES)
	tar zcvf $(TGZFILE) -C $(OUTPUTDIR) -P --transform='s!^$(OUTPUTDIR)/!!' --show-transformed $(OUTPUTIMAGES)
