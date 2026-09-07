# 인프라 가이드 — 가비아 VM 생성부터 `ssh cirros@<FIP>`까지

> CloudClub 10기 OpenStack 스터디 시즌1 · 리더용 런북
> 2026-09-07 프리런(VM-cjm)으로 전 구간 검증 완료. 아래 수치·출력은 전부 실측값.

---

## 0. 확정 사양·예산·일정

| 항목 | 값 |
| --- | --- |
| VM | 가비아 클라우드 **Standard 2vCore / 8GB / 루트 50GB**, Ubuntu 24.04 |
| 요금 | 74,250원 + 공인 IP 4,000원 = 월 78,250원/대 (시간 과금, 중지 상태도 과금 → 삭제만이 절약) |
| 수량 | 참가자 10대 + 리더 1대(VM-cjm) |
| 기간 | **9/12(토) 생성 → 10/13(화) 전원 삭제** (7회차 다음 날). 8회차·발표는 VM 없이 |
| 예산 | 총 100만 원(50+50). 예상 약 92만 원. 9월분만으로 1차 50만 원 초과 → 2차 크레딧 적용 시점 사전 확인 |
| 스택 | Kolla-Ansible 22.0.0 / ansible-core 2.19.11 / OpenStack 2026.1 / ML2-OVS / KVM |
| 전체 소요 | setup 3.5분 + pull 8분 + deploy 9분 + init 39초 ≈ **21분** |

---

## 1. 가비아 콘솔 — VM 생성 (리더가 1인 1대)

경로: 그룹 `10th-openstack` → 프로젝트 → 컴퓨팅 → 서버 → 생성

### 1-1. 사전 준비 (한 번만)

**보안 그룹 `Openstack-SecureGroup`** (보안 → 보안 그룹 → 생성)

| 구분 | 타입 | 프로토콜 | 포트 | IP/CIDR | 용도 |
| --- | --- | --- | --- | --- | --- |
| 인바운드 | SSH | TCP | 22 | 0.0.0.0/0 | 참가자 접속 |
| 인바운드 | HTTP | TCP | 80 | 0.0.0.0/0 | Horizon |
| 인바운드 | HTTPS | TCP | 443 | 0.0.0.0/0 | (선택) |
| 인바운드 | 사용자 정의 | TCP | 6080 | 0.0.0.0/0 | noVNC 콘솔 |
| 아웃바운드 | ALL | ALL | 1~65535 | 0.0.0.0/0 | 이미지 pull |

> 22번을 0.0.0.0/0으로 여는 건 키 인증만 되므로 허용. 참가자가 비밀번호 로그인을 켜지 않도록 안내. 원하면 참가자 공인 IP 수집 후 /32로 제한.

**참가자 공인 IP 수집**은 IP 제한을 걸 때만 필요. 열어두면 생략.

### 1-2. 서버 생성 화면 — 값 그대로

| 섹션 | 값 |
| --- | --- |
| 이미지 | 운영체제(OS) → Ubuntu → **Ubuntu-24.04** |
| 서버 타입 | **Standard** → **2vCore / 8GB** (High CPU 아님 — 2:1 비율이라 8GB가 4vCore) |
| 서버 개수 | 1 (이름·IP를 개별 지정하려면 한 대씩) |
| 루트 스토리지 | **50GB** (pull 후 18GB 사용, 여유 30GB) |
| 데이터 스토리지 | 사용 안 함 |
| 로그인 방식 | **SSH 키페어로 접속 → 신규 생성하기** → 참가자별 키 1개 (`gabia-keypair-<이름>`), 개인키 즉시 저장 (재다운로드 불가) |
| VPC / 서브넷 | Default-VPC (192.168.0.0/16) / Default-Subnet (192.168.0.0/24) |
| 사설 IP | 리더 `.101`, 참가자 `.102`~`.111` 순서 지정 |
| 공인 IP | **할당 → 신규 생성** |
| 보안 그룹 | `Openstack-SecureGroup` |
| 사용자 스크립트 | 지정하지 않음 (리더 공개키 자동 등록용으로 쓰려면 `echo "<공개키>" >> /home/ubuntu/.ssh/authorized_keys` 검증 후) |
| 서버 이름 | `vm-<이름>` (예: vm-cjm) |

생성 후 요약에 **월 78,250원**이 보이면 사양이 맞는 것.

### 1-3. 생성 직후 리더 확인 (VM당 1분)

```bash
ssh -i gabia-keypair-<이름>.pem ubuntu@<공인IP>
lsb_release -a; nproc; free -h; df -h /; egrep -c '(vmx|svm)' /proc/cpuinfo; ip a | grep -E 'eth0|inet '
```

기대값: `24.04` / `2` / `7.8Gi` / `48G` / **`4`**(VT-x 노출) / `eth0 192.168.0.1xx/24`, MAC `fa:16:3e:*`

### 1-4. 개인키 DM (9/12)

개별 DM으로만. 단톡방 금지.

```
[OpenStack 스터디 VM 접속 정보]
공인 IP : <공인IP>
계정    : ubuntu
개인키  : (첨부) gabia-keypair-<이름>.pem
접속    : ssh -i gabia-keypair-<이름>.pem ubuntu@<공인IP>
  - macOS/리눅스: 먼저 chmod 600 gabia-keypair-<이름>.pem
  - Windows: PowerShell 또는 Windows Terminal 권장 (cmd는 스크롤 버퍼가 짧음)
세션 전에 한 번 접속해보고, 안 되면 에러 메시지 그대로 단톡방에.
리더 공개키가 함께 등록돼 있습니다 (세션 밖 지원용). 원치 않으면 ~/.ssh/authorized_keys에서 삭제.
```

---

## 2. 3회차 (9/14) — SSH 접속 + 검증

참가자가 실행:

```bash
lsb_release -a; nproc; free -h; df -h /
egrep -c '(vmx|svm)' /proc/cpuinfo   # 4 → 중첩 가상화 KVM 가능
ip a; ip route
```

세션에서 짚을 것:
- `fa:16:3e:` MAC → OpenStack Neutron 포트의 OUI. **가비아 자체가 OpenStack 위에서 동작**
- `169.254.169.254 via 192.168.0.2` → 메타데이터 서비스 경로 (3회차 Part B 그대로)
- `vmx` 4 → 6회차 인스턴스가 KVM 가속으로 뜬다

에러 메시지 3종:

| 메시지 | 의미 | 조치 |
| --- | --- | --- |
| `Connection timed out` | 길이 막힘 (IP 오타·방화벽) | IP·보안그룹 확인 |
| `Connection refused` | 도착했는데 22번 응답 없음 | 부팅 직후면 대기 |
| `kex_exchange_identification: Connection closed` | 문은 열렸는데 서버가 바쁨 (재부팅 직후 컨테이너 기동 중) | 30초~1분 뒤 재시도 |

완료 기준: 접속 화면 + 검증 명령 출력 스크린샷 → 단톡방.

---

## 3. 4회차 (9/21) — setup.sh

```bash
tmux new -s kolla
git clone https://github.com/cloud-club/10th-openstack-study.git
cd 10th-openstack-study/scripts
./setup.sh 2>&1 | tee ~/setup.log        # 약 3~5분
```

`READY ✅` 확인 후:

```bash
cat /etc/hosts                                   # 127.0.1.1 없음, 192.168.0.1xx vm-<이름>
sed -n '/>>> su-study/,/<<< su-study/p' /etc/kolla/globals.yml   # eth0 / VIP=사설IP / kvm / 공인IP
free -h; ls -l /dev/kvm                          # Swap 8G, /dev/kvm 존재
exit                                             # docker 그룹 반영을 위해 재접속
```

setup.sh가 자동으로 하는 것: NIC·IP 감지, veth 쌍(veth-setup.service), hosts 치환, ip_forward·rp_filter, kvm 모듈 로드(kvm-load.service — 가비아 이미지가 `/etc/modprobe.d/kvm.conf`로 블랙리스트하므로 modules-load.d 불가), 스왑 8G, Kolla 설치, 인벤토리, 비밀번호 생성·백업, prechecks.

(선택) 재부팅 생존 확인: `sudo reboot` → `ip link show veth1`, `ls /dev/kvm`, `grep -c 127.0.1.1 /etc/hosts`(0), `swapon --show`, `docker ps`

---

## 4. 5회차 (9/28) — pull + deploy

```bash
tmux new -s kolla        # 또는 tmux attach -t kolla
source ~/kolla-venv/bin/activate
kolla-ansible pull   -i /etc/kolla/all-in-one    # 약 8분 (16GB 다운로드)
kolla-ansible deploy -i /etc/kolla/all-in-one    # 약 9분. --use-test-images 붙이지 않음
```

`failed=0` 확인 후:

```bash
docker ps | wc -l          # 29 (헤더 포함 = 컨테이너 28개)
free -h                    # used ≈ 4.7G, available ≈ 3.0G
df -h /                    # 사용 ≈ 18G
```

**정상 상태 기준표 — `docker ps --format '{{.Names}}' | sort`** (28개):

```
cron glance_api horizon keystone keystone_fernet keystone_ssh kolla_toolbox mariadb memcached
neutron_dhcp_agent neutron_l3_agent neutron_metadata_agent neutron_openvswitch_agent
neutron_periodic_worker neutron_rpc_server neutron_server
nova_api nova_compute nova_conductor nova_libvirt nova_metadata nova_novncproxy nova_scheduler nova_ssh
openvswitch_db openvswitch_vswitchd placement_api rabbitmq
```

없어야 정상: haproxy, proxysql, fluentd, cinder_*, heat_* (globals에서 끔)

---

## 5. 6회차 (10/6 화) — init.sh + 인스턴스 + SSH

```bash
source ~/kolla-venv/bin/activate
cd ~/10th-openstack-study/scripts
./init.sh 2>&1 | tee ~/init.log     # 약 40초. post-deploy 포함
```

`INIT ✅` 화면에 Horizon 주소·admin 비밀번호·다음 단계가 출력됨. 비밀번호 다시 보기: `grep keystone_admin_password /etc/kolla/passwords.yml`

### 5-1. 인스턴스 → FIP → SSH (시즌1 목표)

CLI (Horizon으로 해도 동일):

```bash
source /etc/kolla/admin-openrc.sh
openstack keypair create mykey > ~/mykey.pem && chmod 600 ~/mykey.pem
openstack server create first-vm --image cirros --flavor m1.tiny --network tenant_network --key-name mykey
watch -n 2 'openstack server list -c Name -c Status -c Networks'      # ACTIVE까지 수십 초 (KVM)
FIP=$(openstack floating ip create provider_network -f value -c floating_ip_address); echo $FIP
openstack server add floating ip first-vm $FIP
ping -c 3 $FIP                        # ttl=63 → qrouter 한 홉
ssh -i ~/mykey.pem cirros@$FIP        # 🏁
```

인스턴스 안에서:

```bash
ping -c 3 8.8.8.8                                          # 경로 A: qrouter SNAT → br-ex → MASQUERADE
ping -c 3 google.com                                       # DNS
ip a | grep mtu                                            # eth0 mtu 1450 (VXLAN 50바이트)
curl -s http://169.254.169.254/latest/meta-data/public-keys/   # 0=mykey ← 3회차 Part B의 답
exit
```

### 5-2. 라우터의 실체 (마무리 5분, OVS를 고른 이유)

```bash
sudo ip netns list                              # qrouter-*, qdhcp-*
QR=$(sudo ip netns list | grep -o 'qrouter-[^ ]*')
sudo ip netns exec $QR ip -4 a                  # 10.10.10.1 / 192.168.200.2
sudo ip netns exec $QR iptables -t nat -L -n    # FIP = DNAT/SNAT 규칙
```

### 5-3. Horizon

`http://<공인IP>/` → admin / passwords.yml 값
- Network → Network Topology: provider_network ─ tenant_router ─ tenant_network
- Compute → Instances: IP 10.10.10.x + FIP
- 인스턴스 → 콘솔 탭: noVNC (공인 IP:6080) — 미검증, 안 되면 콘솔 탭은 생략

---

## 6. 운영 메모

- **인스턴스는 2대까지.** 1대당 약 0.8GB. 2대에서 가용 1.4GB·OOM 없음, 3대는 위험
- **VM 재부팅 후 인스턴스는 Shutoff** — Nova 기본 동작. Horizon에서 "인스턴스 시작" 클릭. 네트워크 배관(br-ex·NAT·FIP)은 자동 복구됨
- 재부팅 직후 1~2분은 컨테이너 기동 중 → SSH `kex_exchange_identification` 또는 `openstack` 명령 실패 정상
- **5분 룰**: 세션 중 개인 트러블슈팅 5분 초과 시 메모하고 진행, 세션 후 리더가 SSH로
- 스크립트 재실행 안전 (setup.sh·init.sh 모두 멱등)
- 로그: `~/setup.log`, `~/pull.log`, `~/deploy.log`, `~/init.log`, 서비스 로그 `sudo ls /var/log/kolla/`
- **10/13 전원 삭제** — 캘린더 등록. 하루 지연 = 약 2.7만 원

---

## 7. 가비아 특이사항 (프리런에서 확인)

| 항목 | 내용 | 대응 |
| --- | --- | --- |
| `kvm_intel` 블랙리스트 | `/etc/modprobe.d/kvm.conf`에 `blacklist kvm_intel` → 부팅 시 `/dev/kvm` 없음 | setup.sh가 `kvm-load.service`로 명시적 modprobe (가비아 파일은 그대로 둠) |
| 중첩 가상화 | VT-x 노출됨 → KVM 가속 | 자동 감지, 인스턴스 부팅 수십 초 |
| 가비아 = OpenStack | MAC `fa:16:3e`, 메타데이터 라우트 | 3회차 교재 |
| eth0 DHCP | 사설 IP는 콘솔 지정값으로 고정 배정 | 그대로 사용 (VIP = 사설 IP) |
| apt 미러 | mirror.kakao.com, 빠름 | — |
| 회선 | quay.io에서 16GB / 8분 | pull 예상 10~20분으로 안내 |
