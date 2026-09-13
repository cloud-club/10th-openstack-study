### **Part A. 핵심 이론 및 실습 요약**

**1. 인스턴스 생성 6단계 (핵심 메커니즘)**

- **1~4단계 (결정 구간 / 수 초 미만):** `Keystone`(인증) → `nova-api`(BUILD 상태로 DB 등록) → `scheduler`(Placement 조회 후 최적 노드 선정) → `nova-compute`(RabbitMQ 비동기 메시지 수신).
- **5~6단계 (실물 준비 구간 / 수십 초 이상):** `Glance`(이미지 다운 load/캐시), `Neutron`(IP/MAC 할당), `Cinder`(볼륨 붙이기)에서 준비물을 모은 뒤 `libvirt`/`QEMU`가 VM을 기동. 완료 시 `ACTIVE` 변환.
- **Troubleshooting Insight:** 대시보드 표시(2단계)와 실제 생성 완료(6단계) 시점에 시차가 존재함. 생성 지연 발생 시 병목은 100% 5~6단계(이미지 다운로드, 네트워크 할당)에서 발생.

**2. SSH 키페어 및 트러블슈팅**

- **인증 방식:** 서버에는 공개키(`~/.ssh/authorized_keys`), 내 PC에는 개인키(`.pem`) 보관.
- **권한 설정:** macOS/Linux는 개인키 권한 `600` 필수 (`chmod 600 <key_file>`).
- **에러 구분:**
    - `timed out`: 네트워크/방화벽/IP 문제 (길이 막힘)
    - `refused`: 서버 22번 포트/서비스 미응답 (도착 후 문전박대)
    - `Permission denied`: 계정명/키 파일 오류

### 실습

1. OS 정보 확인

```bash
ubuntu@vm-2:~$ cat /etc/os-release 
PRETTY_NAME="Ubuntu 24.04.4 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.4 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo

```

1. cpu / memory 정보

```bash
ubuntu@vm-2:~$ cat /proc/cpuinfo 
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 143
model name	: INTEL(R) XEON(R) SILVER 4510
stepping	: 8
microcode	: 0x2b000661
cpu MHz		: 2400.000
cache size	: 16384 KB
physical id	: 0
siblings	: 2
core id		: 0
cpu cores	: 2
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 31
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon rep_good nopl xtopology cpuid tsc_known_freq pni pclmulqdq vmx ssse3 fma cx16 pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch cpuid_fault ssbd ibrs ibpb stibp ibrs_enhanced tpr_shadow flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves avx_vnni avx512_bf16 wbnoinvd arat vnmi avx512vbmi umip pku ospke waitpkg avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg avx512_vpopcntdq la57 rdpid bus_lock_detect cldemote movdiri movdir64b fsrm md_clear serialize tsxldtrk avx512_fp16 arch_capabilities
vmx flags	: vnmi preemption_timer posted_intr invvpid ept_x_only ept_ad ept_1gb flexpriority apicv tsc_offset vtpr mtf vapic ept vpid unrestricted_guest vapic_reg vid shadow_vmcs pml tsc_scaling usr_wait_pause
bugs		: spectre_v1 spectre_v2 spec_store_bypass swapgs taa eibrs_pbrsb bhi ibpb_no_ret its
bogomips	: 4800.00
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 57 bits virtual
power management:

processor	: 1
vendor_id	: GenuineIntel
cpu family	: 6
model		: 143
model name	: INTEL(R) XEON(R) SILVER 4510
stepping	: 8
microcode	: 0x2b000661
cpu MHz		: 2400.000
cache size	: 16384 KB
physical id	: 0
siblings	: 2
core id		: 1
cpu cores	: 2
apicid		: 1
initial apicid	: 1
fpu		: yes
fpu_exception	: yes
cpuid level	: 31
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon rep_good nopl xtopology cpuid tsc_known_freq pni pclmulqdq vmx ssse3 fma cx16 pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch cpuid_fault ssbd ibrs ibpb stibp ibrs_enhanced tpr_shadow flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves avx_vnni avx512_bf16 wbnoinvd arat vnmi avx512vbmi umip pku ospke waitpkg avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg avx512_vpopcntdq la57 rdpid bus_lock_detect cldemote movdiri movdir64b fsrm md_clear serialize tsxldtrk avx512_fp16 arch_capabilities
vmx flags	: vnmi preemption_timer posted_intr invvpid ept_x_only ept_ad ept_1gb flexpriority apicv tsc_offset vtpr mtf vapic ept vpid unrestricted_guest vapic_reg vid shadow_vmcs pml tsc_scaling usr_wait_pause
bugs		: spectre_v1 spectre_v2 spec_store_bypass swapgs taa eibrs_pbrsb bhi ibpb_no_ret its
bogomips	: 4800.00
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 57 bits virtual
power management:

ubuntu@vm-2:~$ 
ubuntu@vm-2:~$ 
ubuntu@vm-2:~$ cat /proc/meminfo 
MemTotal:        8131496 kB
MemFree:         6364408 kB
MemAvailable:    7636176 kB
Buffers:           43644 kB
Cached:          1385316 kB
SwapCached:            0 kB
Active:           175336 kB
Inactive:        1295308 kB
Active(anon):      55716 kB
Inactive(anon):        0 kB
Active(file):     119620 kB
Inactive(file):  1295308 kB
Unevictable:       31292 kB
Mlocked:           27292 kB
SwapTotal:             0 kB
SwapFree:              0 kB
Zswap:                 0 kB
Zswapped:              0 kB
Dirty:               472 kB
Writeback:             0 kB
AnonPages:         73004 kB
Mapped:            69728 kB
Shmem:              5272 kB
KReclaimable:     155340 kB
Slab:             217240 kB
SReclaimable:     155340 kB
SUnreclaim:        61900 kB
KernelStack:        2128 kB
PageTables:         2516 kB
SecPageTables:         0 kB
NFS_Unstable:          0 kB
Bounce:                0 kB
WritebackTmp:          0 kB
CommitLimit:     4065748 kB
Committed_AS:     276852 kB
VmallocTotal:   13743895347199 kB
VmallocUsed:       15868 kB
VmallocChunk:          0 kB
Percpu:             1448 kB
HardwareCorrupted:     0 kB
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
FileHugePages:         0 kB
FilePmdMapped:         0 kB
Unaccepted:            0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:               0 kB
DirectMap4k:       87916 kB
DirectMap2M:     4106240 kB
DirectMap1G:     6291456 kB

```

1. 디스크/FS 정보

```bash
ubuntu@vm-2:~$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           795M  1.1M  794M   1% /run
/dev/vda1        48G  2.2G   46G   5% /
tmpfs           3.9G     0  3.9G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
/dev/vda16      881M  117M  703M  15% /boot
/dev/vda15      105M  6.2M   99M   6% /boot/efi
tmpfs           795M   12K  795M   1% /run/user/1000
ubuntu@vm-2:~$ 
ubuntu@vm-2:~$ 
ubuntu@vm-2:~$ 
ubuntu@vm-2:~$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda     253:0    0   50G  0 disk 
├─vda1  253:1    0   49G  0 part /
├─vda14 253:14   0    4M  0 part 
├─vda15 253:15   0  106M  0 part /boot/efi
└─vda16 259:0    0  913M  0 part /boot
```

1. 네트워크 정보
    - networkmanger 패키지를 설치했는데도 nmcli 명령어로는 확인할 수가 없음..

```bash
ubuntu@vm-2:~$ ifconfig
Command 'ifconfig' not found, but can be installed with:
sudo apt install net-tools
ubuntu@vm-2:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether fa:16:3e:61:41:9d brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    altname ens3
    inet 192.168.0.103/24 metric 100 brd 192.168.0.255 scope global dynamic eth0
       valid_lft 39306sec preferred_lft 39306sec
    inet6 fe80::f816:3eff:fe61:419d/64 scope link 
       valid_lft forever preferred_lft forever

**ubuntu@vm-2:~$ nmcli connection show**
```

### **Part B. 심화 개념 (상태 전이 & cloud-init)**

- **BUILD 내 세부 상태:** `scheduling` → `networking` → `spawning` → `ACTIVE` (실패 시 `ERROR`).
- **cloud-init & 메타데이터:** 부팅 시 링크-로컬 주소 (`http://169.254.169.254`)로 요청을 보내 공개키와 기본 설정을 주입받음.
- **known_hosts:** VM 재발급 후 동일 IP 접속 시 `REMOTE HOST IDENTIFICATION HAS CHANGED!` 경고가 발생하면 `ssh-keygen -R <IP>`로 기존 지문 삭제 후 재접속.

### **예습 퀴즈 답**

**Q1. 6단계 중 시간이 실제로 걸리는 구간은 어디고, 왜 그런가요?**

- 5단계(준비물 수집)와 6단계(기동)입니다. 1~4단계는 API 호출 및 배치 계산(소프트웨어적 결정)이라 수 초 내에 끝나지만, 5~6단계는 네트워크를 통한 이미지 다운로드, 가상 포트/IP 할당, QEMU 프로세스 실행 등 **실제 자원을 할당하고 부팅하는 물리적/네트워크 작업**이 수반되기 때문입니다.

**Q2. 인스턴스가 대시보드에 보이는 시점과 실제로 존재하는 시점은 왜 다른가요? (몇 단계와 몇 단계 사이?)**

- **2단계(접수)와 6단계(기동) 사이**의 시차 때문입니다. `nova-api`가 요청을 받자마자 DB에 상태를 `BUILD`로 기록하면서 대시보드에 즉시 노출되지만, 실제 Hypervisor 상에서 QEMU 프로세스가 떠서 부팅이 완료되는 것은 **6단계**가 끝나야 하기 때문입니다.

**Q3. 개인키와 공개키 중 서버에 저장되는 것은? 절대 남에게 전달하면 안 되는 것은?**

- 서버에 저장되는 것: **공개키 (Public Key)**
- 절대 남에게 전달하면 안 되는 것: **개인키 (Private Key)**

**Q4. Connection timed out과 Connection refused는 각각 무엇이 problem이라는 신호인가요?**

- `Connection timed out`: **네트워크/방화벽 문제** (IP 오타, 22번 포트 블록 등 라우팅 경로상의 막힘).
- `Connection refused`: **서버 내부 서비스/포트 문제** (패킷은 서버에 도착했으나 22번 포트에서 SSH 데몬이 응답하지 않음).
