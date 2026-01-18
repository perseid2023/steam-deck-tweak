do not use this tweak ! it will make your steam deck slow and crash often !  

- configure zram
- add an 8GB swap file
- set swappiness to 1
- set cpu governor to performance
- enable MGLRU
- configure memlock limits to 2GB
- enable ntsync kernel module 
- disable cpu security mitigations (optional)
- disable transparent huge pages

check if swap and zram enabled : `swapon --show`  
check zram : `zramctl`  
check swappiness : `sysctl vm.swappiness`  
check if ntsync kernel module is loaded : `lsmod | grep ntsync`  
check if a game is using ntsync : `lsof /dev/ntsync`
