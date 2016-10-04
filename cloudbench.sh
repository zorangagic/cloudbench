#!/bin/bash
# Cloudbench - Server benchmark for RH/Centos/Amazon Linux
#
# Zoran Gagic - zorang at gmail.com
#
# Copyright (C) 2015  Zoran Gagic

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

(
sep ()
{
  echo -e "\n===========================================================================================\n\n"$1"\n\n"
}

usage ()
{
  echo "Usage : $0 " '[ -e <email> ] [ -k <geekbench key> ] [ -nounixbench ]'
  exit
}

while [ "$1" != "" ]
do
    case $1 in
        -e )           shift
                       email=$1
                       ;;
        -k )           shift
                       geekkey=$1
                       ;;
        -h|--help )    usage
                       exit 1
                       ;;
        -nounixbench ) nounixbench=1
                       ;;
         -*)
                       echo "Error: no such option $1"
                       usage
                       exit 1
    esac
    shift
done

rootcheck()
{
        if [[ $EUID -ne 0 ]]; then
                echo "This script must be run as root"
                echo "Ex. "sudo ./linux-bench.sh""
                exit 1
        fi
}

rootcheck
basedir=`pwd`
echo -e "Starting Cloudbench - `date`\n\nInstall required packages:" | tee cloudbench.install
(
yum -y install fio git iperf mail gcc sysstat libX11-devel mesa-libGL-devel perl-Time-HiRes redhat-lsb glibc.i686 libstdc++ libstdc++.i686 libstdc++44.i686 2>&1
mkdir nmon; cd nmon
wget http://sourceforge.net/projects/nmon/files/nmon16e_mr_nmon.tar.gz
tar -zxvf  nmon16e_mr_nmon.tar.gz
cp nmon16e_x86_rhel72 /bin
cd $basedir
) >> cloudbench.install 2>&1


sep 'System info:'
ec2=`wget -q -O /dev/null http://169.254.169.254/latest/meta-data && echo "EC2 instance" || echo "Non EC2 instance"`
if [ "$ec2" == "EC2 instance" ]
then
   EC2_instancetype="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-type || die \"wget nstance-type has failed: $?\"`"
   echo "AWS instance type: " $EC2_instancetype
   echo "User Data:"
   curl http://169.254.169.254/latest/user-data 2>/dev/null
   echo
fi
cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo )
cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
freq=$( awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo )
tram=$( free -m | awk 'NR==2 {print $2}' )
swap=$( free -m | awk 'NR==4 {print $2}' )
up=$(uptime|awk '{ $1=$2=$(NF-6)=$(NF-5)=$(NF-4)=$(NF-3)=$(NF-2)=$(NF-1)=$NF=""; print }')
version=$(cat /etc/issue)
kernel=$(uname -a)
echo "CPU model : $cname"
echo "Number of cores : $cores"
echo "CPU frequency : $freq MHz"
echo "Total amount of ram : $tram MB"
echo "Total amount of swap : $swap MB"
echo "System uptime : $up"
echo "System version: $version"
echo "System kernel: $kernel"
echo
lscpu
echo
free -tm
echo
df -h
echo
fdisk -l
echo
netstat -in
echo
ifconfig -a
echo
cat /etc/*-release
echo
lsb_release -a


# Geekbench
sep 'Geekbench - CPU / Memory bandwidth:' | tee -a cloudbench.install
(
wget http://cdn.primatelabs.com/Geekbench-3.3.2-Linux.tar.gz | tail -5
tar -vxzf Geekbench-3.3.2-Linux.tar.gz
) >> cloudbench.install 2>&1
if [ "$geekkey" == "" ]
then
     echo "Geekbench 32-bit:"
     dist/Geekbench-3.3.2-Linux/geekbench_x86_32 --upload
else
     echo "Geekbench 64-bit:"
     dist/Geekbench-3.3.2-Linux/geekbench_x86_64 -r $email $geekkey
     dist/Geekbench-3.3.2-Linux/geekbench_x86_64 --upload
fi

# UNIXbench
if [ "$nounixbench" == "" ]
then
     sep 'UNIXbench - CPU / Memory bandwidth:' | tee -a cloudbench.install
     (
     wget -c http://byte-unixbench.googlecode.com/files/unixbench-5.1.3.tgz | tail -15
     tar xvzf unixbench-5.1.3.tgz
     cd unixbench-5.1.3
     make 2>&1
     ) >> cloudbench.install 2>&1
     cd unixbench-5.1.3
     ./Run
     cd ..
fi

# Stream
sep 'Stream memory bandwidth:'  | tee -a cloudbench.install
(
wget http://www.cs.virginia.edu/stream/FTP/Code/Makefile
wget http://www.cs.virginia.edu/stream/FTP/Code/stream.c
wget http://www.cs.virginia.edu/stream/FTP/Code/mysecond.c
make stream_c.exe
) >> cloudbench.install 2>&1
./stream_c.exe

# 7zip CPU test
sep '7zip benchmark CPU performance (Multi thread):'  | tee -a cloudbench.install
(
wget http://sourceforge.net/projects/p7zip/files/p7zip/9.38.1/p7zip_9.38.1_x86_linux_bin.tar.bz2
bzip2 -d p7zip_9.38.1_x86_linux_bin.tar.bz2
tar xvf p7zip_9.38.1_x86_linux_bin.tar
) >> cloudbench.install 2>&1
p7zip_9.38.1/bin/7za b

# Latency test
sep 'LMbench L1 L2 L3 and Memory latency:' | tee -a cloudbench.install
(
git clone https://github.com/dmonakhov/lmbench.git
cd lmbench
make
cd ..
) >> cloudbench.install 2>&1
lmbench/bin/*/lat_mem_rd 512

# Simple CPU test
sep 'Simple CPU performance (Single thread):'
dd if=/dev/zero bs=1M count=1024 | md5sum

# ssl RSA test
sep 'SSL RSA speedtest:'
ssl speedtest RSA

# Network Bandwidth test
sep 'Global network bandwidth:'
ping -c 5 cachefly.cachefly.net
echo
echo
traceroute cachefly.cachefly.net
echo
cachefly=$( wget -O /dev/null http://cachefly.cachefly.net/100mb.test 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from CacheFly: $cachefly "
coloatatl=$( wget -O /dev/null http://speed.atl.coloat.com/100mb.test 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Coloat, Atlanta GA: $coloatatl "
sldltx=$( wget -O /dev/null http://speedtest.dal05.softlayer.com/downloads/test100.zip 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Softlayer, Dallas, TX: $sldltx "
linodejp=$( wget -O /dev/null http://speedtest.tokyo.linode.com/100MB-tokyo.bin 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Linode, Tokyo, JP: $linodejp "
i3d=$( wget -O /dev/null http://mirror.i3d.net/100mb.bin 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from i3d.net, Rotterdam, NL: $i3d"
linodeuk=$( wget -O /dev/null http://speedtest.london.linode.com/100MB-london.bin 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Linode, London, UK: $linodeuk "
leaseweb=$( wget -O /dev/null http://mirror.leaseweb.com/speedtest/100mb.bin 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Leaseweb, Haarlem, NL: $leaseweb "
slsg=$( wget -O /dev/null http://speedtest.sng01.softlayer.com/downloads/test100.zip 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Softlayer, Singapore: $slsg "
slwa=$( wget -O /dev/null http://speedtest.sea01.softlayer.com/downloads/test100.zip 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Softlayer, Seattle, WA: $slwa "
slsjc=$( wget -O /dev/null http://speedtest.sjc01.softlayer.com/downloads/test100.zip 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Softlayer, San Jose, CA: $slsjc "
slwdc=$( wget -O /dev/null http://speedtest.wdc01.softlayer.com/downloads/test100.zip 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}' )
echo "Download speed from Softlayer, Washington, DC: $slwdc "

sep 'Speedtest.net' | tee -a cloudbench.install
wget -O speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest_cli.py >> cloudbench.install 2>&1
chmod +x speedtest-cli
./speedtest-cli

# Sequential IO test
sep 'dd Sequential IO performance:'
d=`fdisk -l | grep Disk | grep -v identifier | tail -1 | cut -d' ' -f2 | cut -d':' -f1`
mkfs.ext4 -F $d
mount $d /mnt
cd /mnt
echo "dd Write performance:"
dd if=/dev/zero of=tempfile bs=1M count=10240 conv=fdatasync,notrunc
echo 3 > /proc/sys/vm/drop_caches
echo
echo "dd Read performance:"
dd if=tempfile of=/dev/null bs=1M count=10240
cd /
umount /mnt

# fio IO test
sep 'fio Random 8K 70/30 qd=16:'
fio --filename=$d --direct=1 --rw=randrw --refill_buffers --norandommap --ioengine=libaio --bs=8k --rwmixread=70 --iodepth=16 --numjobs=16 --runtime=120 --ramp_time=5 --group_reporting --name=8k7030test

sep 'fio Sequential read 1MB qd=32:'
fio --name=readbw --filename=$d --direct=1 --rw=read  --bs=1m --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

sep 'fio Sequential write 1MB qd=32:'
fio --name=writebw --filename=$d --direct=1 --rw=write  --bs=1m --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

sep 'fio Random read 8K qd=16:'
fio --name=readiops --filename=$d --direct=1 --rw=randread --bs=8k --numjobs=4 --iodepth=16 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

sep 'fio Random write 8K qd=16:'
fio --name=writeiops --filename=$d --direct=1 --rw=randwrite --bs=8k --numjobs=4 --iodepth=16 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

sep 'fio Write bandwidth - 1MB random write qd=32:'
fio --name=writebw --filename=$d --direct=1 --rw=randwrite --bs=1m --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

sep 'fio Read Max IOPS - 512 random read qd=32:'
fio --name=readiops --filename=$d --direct=1 --rw=randread --bs=512 --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

sep 'fio Raed bandwidth - 1MB random read qd=32:'
fio --name=readbw --filename=$d --direct=1 --rw=randread --bs=1m --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

sep 'fio Max Write IOPS - 512 random write qd=32:'
fio --name=writeiops --filename=$d --direct=1 --rw=randwrite --bs=512 --numjobs=4 --iodepth=32 --direct=1 --iodepth_batch=16 --iodepth_batch_complete=16 --runtime=120 --ramp_time=5 --norandommap --time_based --ioengine=libaio --group_reporting

echo -e "\n\n\nCloubench completed - `date`"

if [ "$email" != "" ]
then
  cd $basedir
  cat cloudbench.out | mail -v -s "Cloudbench: `hostname` $EC2_instancetype" $email  > mail.out 2>&1
fi
) 2>&1 | tee cloudbench.out

exit 0
