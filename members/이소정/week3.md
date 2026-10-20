## 실습

~~~
ubuntu@vm-6:~$ lsb_release -a
No LSB modules are available.
Distributor ID:	Ubuntu
Description:	Ubuntu 24.04.4 LTS
Release:	24.04
Codename:	noble

ubuntu@vm-6:~$ nproc  
2

ubuntu@vm-6:~$ free -h 
               total        used        free      shared  buff/cache   available
Mem:           7.8Gi       490Mi       6.1Gi       5.2Mi       1.5Gi       7.3Gi
Swap:             0B          0B          0B

ubuntu@vm-6:~$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        48G  2.2G   46G   5% /

ubuntu@vm-6:~$ egrep -c '(vmx|svm)' /proc/cpuinfo
4

ubuntu@vm-6:~$ ip a   
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether fa:16:3e:80:df:1c brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    altname ens3
    inet 192.168.0.107/24 metric 100 brd 192.168.0.255 scope global dynamic eth0
       valid_lft 24022sec preferred_lft 24022sec
    inet6 fe80::f816:3eff:fe80:df1c/64 scope link 
       valid_lft forever preferred_lft forever
~~~

### Linux 부팅 순서
1. BIOS: 주변 장치에 전원이 들어오는 것을 가장 먼저 인지하는 단계
2. Boot Loader(GRUB): 커널을 메모리에 올리기 위한 준비(E키를 눌러 수동으로 설정 가능)
3. Kernel
4. Initfs: 실제 디스크의 파일디스크를 마운트하기 위한 임시 파일 시스템
5. Systemd: PID 1번 프로세스로서 시스템의 모든 서비스와 데몬 실행
6. cloud-init: OS 부팅의 가장 마지막 단계에서 실행되는 초기화 도구 
7. boot 

### Glance
~~~
openstack image create ~
~~~
deploy에서 image create 명령어를 날리면 glance에 저장이 됨 
* deploy > openstack image list  에 나오는 UUID
* controller > /var/lib/glance/images/UUID


openstack volume create 할 때, 항상 image를 가져오지 않고 캐시

controller는 3개 > 그럼 glance도 각각 3개 > 하지만 하나의 저장소를 바라보도록