setenv netretry yes
tftp ${kernel_addr_r} zImage
tftp ${fdt_addr_r} sun8i-h2-plus-custom.dtb
tftp ${ramdisk_addr_r} uInitrd
setenv bootargs loglevel=6 console=tty1 console=ttyS0,115200 root=/dev/root rootwait panic=2 ip=dhcp
bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
