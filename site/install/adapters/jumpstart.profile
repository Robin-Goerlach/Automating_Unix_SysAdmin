# SASD candidate Solaris JumpStart profile; validate against the selected Solaris release.
install_type initial_install
system_type standalone
cluster SUNWCuser
partitioning explicit
filesys rootdisk.s0 free /
filesys rootdisk.s1 512 swap
network_interface PRIMARY hostname=HOSTNAME ip=IP netmask=NETMASK protocol_ipv6=no
boot_device rootdisk.s0 update
# finish script and installation source remain operator-selected fields.
