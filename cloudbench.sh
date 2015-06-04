!/bin/bash

(
yum -y install fio git iperf gcc sysstat

EC2_nstancetype="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-type || die \"wget nstance-type has failed: $?\"`"
echo "AWS instance type: " $EC2_nstancetype

# Geekbench
echo -e "\n\nGeekbench - CPU / Memory bandwidth:"
wget http://geekbench.s3.amazonaws.com/Geekbench-3.1.2-Linux.tar.gz
tar -vxzf Geekbench-3.1.2-Linux.tar.gz
dist/Geekbench-3.1.2-Linux/geekbench_x86_64 -r zorang@gmail.com secret-key
dist/Geekbench-3.1.2-Linux/geekbench_x86_64 --upload


# Latency test
echo -e "\n\n==================================================================================================================\n\nLMbench L1 L2 L3 and Memory latency:\n\n"
git clone https://github.com/dmonakhov/lmbench.git
cd lmbench
make
bin/*/lat_mem_rd 512
cd ..

# Simple CPU test
echo -e "\n\n==================================================================================================================\n\nSimple CPU performance:\n\n"
dd if=/dev/zero bs=1M count=1024 | md5sum

# Network Bandwidth test
echo -e "\n\n==================================================================================================================\n\nGlobal network bandwidth:\n\n"
wget freevps.us/downloads/bench.sh -O - -o /dev/null|bash

# Network Bandwidth test to local Australian site
echo -e "\n\n==================================================================================================================\n\nAustralian network bandwidth:\n\n"
wget http://mirror.internode.on.net/pub/centos/7.1.1503/isos/x86_64/CentOS-7-x86_64-Minimal-1503-01.iso

# Sequential IO test
echo -e "\n\n==================================================================================================================\n\ndd Sequiential IO performance:\n\n"
d=`fdisk -l | grep Disk | grep -v identifier | tail -1 | cut -d' ' -f2 | cut -d':' -f1`
mkfs.ext4 -F $d
mount $d /mnt
cd /mnt
dd if=/dev/zero of=tempfile bs=1M count=10240 conv=fdatasync,notrunc
echo 3 > /proc/sys/vm/drop_caches
dd if=tempfile of=/dev/null bs=1M count=10240
cd /
umount /mnt

# fio IO test
echo -e "\n\n==================================================================================================================\n\nfio Random 8K 70/30 qd=16:\n\n"
fio --filename=$d --direct=1 --rw=randrw --refill_buffers --norandommap --randrepeat=0 --ioengine=libaio --bs=8k --rwmixread=70 --iodepth=16 --numjobs=16 --runtime=120 --ramp_time=5 --group_reporting --name=8k7030test

echo -e "\n\n==================================================================================================================\n\nfio Sequential read 1MB qd=16:\n\n"
fio --name=readbw --filename=$d --direct=1 --rw=read  --bs=1m --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

echo -e "\n\n==================================================================================================================\n\nfio Sequential write 1MB qd=16:\n\n"
fio --name=writebw --filename=$d --direct=1 --rw=write  --bs=1m --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

echo -e "\n\n==================================================================================================================\n\nfio Random read 8K qd=16:\n\n"
fio --name=readiops --filename=$d --direct=1 --rw=randread --bs=8k --numjobs=4 --iodepth=16 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

echo -e "\n\n==================================================================================================================\n\nfio Random write 8K qd=16:\n\n"
fio --name=writeiops --filename=$d --direct=1 --rw=randwrite --bs=8k --numjobs=4 --iodepth=16 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

echo -e "\n\n==================================================================================================================\n\nfio Write bandwidth - 1MB random write qd=32:\n\n"
fio --name=writebw --filename=$d --direct=1 --rw=randwrite --bs=1m --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

echo -e "\n\n==================================================================================================================\n\nfio Read Max IOPS - 512 random read qd=32:\n\n"
fio --name=readiops --filename=$d --direct=1 --rw=randread --bs=512 --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

echo -e "\n\n==================================================================================================================\n\nfio Raed bandwidth - 1MB random read qd=32:\n\n"
fio --name=readbw --filename=$d --direct=1 --rw=randread --bs=1m --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

echo -e "\n\n==================================================================================================================\n\nfio Max Write IOPS - 512 random write qd=32:\n\n"
fio --name=writeiops --filename=$d --direct=1 --rw=randwrite --bs=512 --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

) 2>&1  | tee cloudbench.out