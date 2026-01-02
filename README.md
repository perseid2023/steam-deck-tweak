do not use this tweak! it will make your steam deck slow and crash often !  

- change zram-size to `zram-size = ram`  
- add an 8GB disk swapfile as backup  
- change swappiness value to 200
- set cpu governor to performance
- enable MGLRU
- configure memlock limits to 2GB
- enable ntsync kernel module (kernel 6.15+)
- disable CPU security mitigations (optional)

check that ntsync kernel module is loaded : `lsmod | grep ntsync`  
check that a game is using ntsync : `lsof /dev/ntsync`
