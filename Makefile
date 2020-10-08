ROOTDIR := $(shell pwd)
BUILDDIR := $(ROOTDIR)/.build
ARMBIANDIR := $(BUILDDIR)/armbian

KERNELFAMILY := sunxi
KERNELBRANCH := next
KERNELVERSION := 5.4.69
BOARD := orangepizero

IMAGEDEB := $(ARMBIANDIR)/output/debs/linux-image-next-sunxi_20.11.0-trunk_armhf.deb
DTBDEB := $(ARMBIANDIR)/output/debs/linux-dtb-next-sunxi_20.11.0-trunk_armhf.deb
DEBS := $(IMAGEDEB) $(DTBDEB)

UROOT := $(BUILDDIR)/bin/u-root

BNLOCALWORKER := $(ROOTDIR)/../LocalWorker/bin/linux/arm/bnLocalWorker

OUTPUTDIR := $(ROOTDIR)/output
KERNELIMAGE := $(OUTPUTDIR)/zImage
INITFSIMAGEBLW := $(OUTPUTDIR)/uInitrd-blw
INITFSIMAGEK3S := $(OUTPUTDIR)/uInitrd-k3s
DTBIMAGE := $(OUTPUTDIR)/$(KERNELFAMILY)-$(BOARD).dtb
BOOTSCR := $(OUTPUTDIR)/boot.scr.uimg
OUTPUTIMAGES := $(KERNELIMAGE) $(INITFSIMAGEBLW) $(INITFSIMAGEK3S) $(DTBIMAGE) $(BOOTSCR)

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

$(BUILDDIR)/k3os-root.cpio:
	mkdir -p $(BUILDDIR)/k3os
	cd $(BUILDDIR) && wget https://github.com/rancher/k3os/releases/download/v0.11.1/k3os-rootfs-arm.tar.gz
	tar zxvf $(BUILDDIR)/k3os-rootfs-arm.tar.gz -C $(BUILDDIR)/k3os --strip-components=1
	cd $(BUILDDIR)/k3os && find . print | cpio -ocv --owner=root.root > $(BUILDDIR)/k3os-root.cpio

$(INITFSIMAGEBLW): $(UROOT) $(BNLOCALWORKER)
	mkdir -p $(BUILDDIR)/uroot
	cd $(BUILDDIR)/src/github.com/u-root/u-root && GOPATH=$(BUILDDIR) GOARCH=arm $(UROOT) \
		-format=cpio -build=bb -o $(BUILDDIR)/uroot/uroot.cpio \
		-files=$(BNLOCALWORKER):bin/bnLocalWorker \
		-defaultsh=/bin/bnLocalWorker \
		-initcmd=/bin/bnLocalWorker \
		./cmds/*
	mkimage -A arm -O linux -T ramdisk -d $(BUILDDIR)/uroot/uroot.cpio $(INITFSIMAGEBLW)

$(INITFSIMAGEK3S): $(UROOT) $(BNLOCALWORKER) $(BUILDDIR)/k3os/k3os/system/k3os/current/k3os
	mkdir -p $(BUILDDIR)/uroot
	cd $(BUILDDIR)/src/github.com/u-root/u-root && GOPATH=$(BUILDDIR) GOARCH=arm $(UROOT) \
		-format=cpio -build=bb -o $(BUILDDIR)/k3os/uroot.cpio \
		-files=$(BUILDDIR)/k3os/k3os/system/k3os/current/k3os:sbin/k3os \
		-defaultsh="" \
		-uinitcmd=/sbin/k3os \
		./cmds/*
	mkimage -A arm -O linux -T ramdisk -d $(BUILDDIR)/k3os/uroot.cpio $(INITFSIMAGEK3S)

$(BOOTSCR): $(ROOTDIR)/boot/boot.cmd
	mkimage -C none -A arm -T script -d $(ROOTDIR)/boot/boot.cmd $(BOOTSCR)
