# Binky Local Worker Image Builder

## Dependencies

- sudo apt install gcc-arm-linux-gnueabi
- sudo apt install u-boot-tools

## U-Boot dependencies

On host machine:

```bash
sudo apt install binutils-arm-none-eabi gcc-arm-none-eabi swig python-dev libusb-dev libusb-1.0 zlib1g-dev
```

## Building U-Boot

On host machine:

```bash
git clone git@github.com:u-boot/u-boot.git
cd u-boot
export ARCH=arm
export CROSS_COMPILE=arm-none-eabi-
make orangepi_zero_defconfig
make
```

## Install U-Boot to OrangePI Zero

On host machine:

```bash
git clone https://github.com/linux-sunxi/sunxi-tools.git
cd sunxi-tools
make tools
sudo make install-tools
cd ../u-boot
# Connect USB cable to OrangePi Zero and insert into host machine
sudo sunxi-fel -p spiflash-write 0 u-boot-sunxi-with-spl.bin
```

Now unplug OrangePI Zero, connect network cable and boot it.
