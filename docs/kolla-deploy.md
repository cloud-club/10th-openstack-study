# Ch 4. Kolla-Ansible 배포 절차 (가비아 VM · ML2/OVS)

> 우리 스터디의 배포 방식. 5회차(배포)와 6회차(인스턴스·네트워크 실습)가 이 절차를 따름.
> 이 구성은 스터디장이 SU-Cloud 운영계를 Kolla-Ansible로 구축하며 검증한 설계를 가비아 VM 환경 + OVS 백엔드로 옮긴 것.

---

## 1. 최종 구성

| 항목 | 값 |
| --- | --- |
| 환경 | 가비아 클라우드 VM (Ubuntu 24.04, 16GB, 1인 1대) |
| 배포 도구 | Kolla-Ansible 22.0.0 / ansible-core 2.19.x |
| OpenStack | 2026.1 (Gazpacho, SLURP) |
| 구성 | all-in-one (컨트롤러+컴퓨트 단일 VM) |
| 네트워크 백엔드 | **ML2/OVS** (테넌트 타입 vxlan) |
| 활성 컴포넌트 | Keystone, Glance, Placement, Nova, Neutron(OVS), Horizon |
| 공용 인프라 | MariaDB, RabbitMQ, Memcached |
| 비활성 | HAProxy, Keepalived, Cinder, Heat, 모니터링 스택 전량 |

### 백엔드 선택 근거 — 왜 OVN이 아니라 OVS인가

판정 기준은 "학습자가 호스트에 접속해 netns 실습을 할 수 있는가".

- 스터디는 참가자 전원이 자기 VM에 직접 접속하는 구조 → `ip netns exec qrouter-*` 실습이 6회차 핵심 → **OVS 필수** (OVN은 L3를 netns 없이 플로우로 처리하므로 qrouter 네임스페이스 자체가 생기지 않음)
- OVS는 장애 위치를 agent 단위(l3/dhcp/ovs)로 좁힐 수 있어 초심자 트러블슈팅에 유리함. OVN은 NB/SB DB와 전용 도구(`ovn-nbctl`/`ovn-sbctl`) 체계를 추가로 배워야 함
- all-in-one 단일 노드라 OVN의 장점(확장성, 경량 에이전트)이 발휘될 지점이 없음
- 참고: 학습자가 호스트에 접속하지 않는 대규모 운영 환경이라면 반대로 OVN이 정답. **기술 선택은 "최신"이 아니라 목적 적합이 기준**

---

## 2. 네트워크 구조

가비아 VM은 공인 IP가 VM 밖(가비아 NAT)에 있고 VM 안에는 사설 IP만 존재함. 따라서 FIP를 공인 대역으로 만들 수 없으며, **FIP = 사설 대역 + 호스트 SNAT** 구조를 사용함.

```
[관리 평면]                      [데이터 평면]
eth0 (VM 사설 IP)                br-ex (192.168.200.1/24)
  ↑ 가비아 NAT (공인 IP)           └─ veth1 (OVS 편입, IP 없음)
  ↑                                    ╎ veth 쌍 (L2 단절)
인터넷 (SSH/Horizon 인바운드)       veth0 ← 어디에도 미부착
```

데이터 경로 — NAT는 경로별로 다르게 걸림:

**경로 A. 인스턴스 → 인터넷** (NAT 3회 — ①은 OpenStack 내장, ③은 가비아 소관, 우리가 추가하는 것은 ②뿐)

```
인스턴스 (10.10.10.x)
  → qrouter netns — Neutron SNAT ①  (10.10.10.x → 192.168.200.2)
  → br-ex (192.168.200.1)
  → 호스트 MASQUERADE ②             (192.168.200.x → eth0 사설 IP)
  → 가비아 NAT ③                    (사설 → 공인) → 인터넷
```

**경로 B. `ssh cirros@<FIP>`** (시즌1 최종 목표 — MASQUERADE를 타지 않음)

```
가비아 VM 호스트에서 실행:
  ssh cirros@192.168.200.1xx
  → 호스트는 br-ex(192.168.200.1)를 직접 보유 — 로컬 라우팅
  → qrouter netns — Neutron DNAT    (FIP → 10.10.10.x)
  → 인스턴스
```

- 최종 목표(경로 B)만 보면 MASQUERADE 없이도 동작함. 그래도 구성하는 이유: 인스턴스의 인터넷 통신 검증(ping 8.8.8.8, DNS)이 전 경로 개통의 증명이 되고, 인스턴스에서 패키지 설치가 필요해질 때 필수임
- **FIP는 VM 안에서만 존재하는 주소** — 참가자 노트북에서 FIP로 직접 접속 불가. 접속은 항상 2단계: 노트북 → 가비아 VM(공인 IP) SSH → VM 안에서 `ssh cirros@<FIP>`

| 인터페이스 | 역할 |
| --- | --- |
| `eth0` (이름은 VM마다 확인) | 관리망. SSH, OpenStack API, Horizon. `network_interface` |
| `veth1` | `neutron_external_interface`. 배포 시 OVS `br-ex`에 편입, IP 없음 |
| `veth0` | `veth1`의 쌍. **어디에도 붙이지 않음** — UP 상태만 유지 |
| `br-ex` (OVS) | 프로바이더망 L3 종단. `192.168.200.1` (배포 후 생성됨) |
| `br-int` (OVS) | 인스턴스 포트 부착 |
| `br-tun` (OVS) | VXLAN 터널 (단일 노드라 실사용 없음, 구조 관찰용) |

**veth0 미부착 원칙**: veth0을 다른 브리지에 물리면 br-ex의 플러딩 트래픽이 관리망으로 새어나가는 경로가 생김 (운영계 구축 시 실제 장애로 확인된 패턴). 두 평면은 L2로 완전히 분리하고 호스트 커널의 L3 라우팅 + MASQUERADE로만 연결함.

---

## 3. 구축 순서

### Step 1 — 사전 준비

```bash
sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone Asia/Seoul
sudo apt install -y chrony git tmux python3-dev python3-venv libffi-dev gcc libssl-dev
sudo systemctl enable --now chrony
```

**hostname 해석 — 추가가 아닌 치환**

```bash
PRIV_IP=$(hostname -I | awk '{print $1}')
sudo sed -i "s/^127\.0\.1\.1\s\+$(hostname)/$PRIV_IP $(hostname)/" /etc/hosts
```

기존 `127.0.1.1 <호스트명>` 줄이 있는 상태에서 `tee -a`로 덧붙이면 앞 줄이 먼저 매칭되어 여전히 루프백으로 해석됨. RabbitMQ가 루프백에 바인드되면 배포 중반에 원인 파악이 어려운 형태로 실패함.

**커널 파라미터**

```bash
sudo tee /etc/sysctl.d/99-kolla.conf >/dev/null <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.default.rp_filter=2
EOF
sudo sysctl --system
```

`rp_filter`는 loose(2) 필수. strict(1)이면 다중 NAT 경로의 비대칭성으로 인해 FIP 응답 패킷이 **로그도 없이** drop됨.

### Step 2 — veth 유닛

`/etc/systemd/system/veth-setup.service`

```ini
[Unit]
Description=Create veth pair for Neutron external interface
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStartPre=-/sbin/ip link del veth0
ExecStart=/sbin/ip link add veth0 type veth peer name veth1
ExecStart=/sbin/ip link set veth0 up
ExecStart=/sbin/ip link set veth1 up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now veth-setup.service
ip link show veth1   # UP 확인
```

- `ExecStartPre=-`의 `-`는 "이미 없어도 실패로 치지 않음" — 재실행 멱등 처리
- **`veth0 master <브리지>` 류의 줄을 절대 넣지 않음** (§2의 미부착 원칙)

### Step 3 — Kolla-Ansible 설치 + 설정 파일 3종

```bash
python3 -m venv ~/kolla-venv && source ~/kolla-venv/bin/activate
pip install -U pip
pip install docker
pip install "ansible-core>=2.19,<2.20"
pip install kolla-ansible==22.0.0
pip install python-openstackclient osc-placement
```

`osc-placement`는 `python-openstackclient`에 포함되지 않음. 없으면 `openstack resource provider list`가 동작하지 않음.

우리가 손대는 설정 파일은 셋 — 전부 예제 복사에서 시작함:

```bash
sudo mkdir -p /etc/kolla && sudo chown $USER:$USER /etc/kolla
cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one /etc/kolla/
kolla-genpwd -p /etc/kolla/passwords.yml
```

| 파일 | 역할 | 우리가 하는 일 |
| --- | --- | --- |
| `globals.yml` | 어떻게 배포할지 | Step 4의 블록 추가 |
| `passwords.yml` | 서비스별 비밀번호 | `kolla-genpwd` 자동 생성 — **단순한 값으로 바꾸지 말 것**, 생성 직후 백업 |
| `all-in-one` (인벤토리) | 어디에 배포할지 | 단일 노드라 그대로 사용 |

**passwords.yml 즉시 백업 — 분실 시 복구 불가**

```bash
mkdir -p ~/kolla-backup
cp /etc/kolla/passwords.yml ~/kolla-backup/passwords.yml.$(date +%F)
chmod 600 ~/kolla-backup/passwords.yml.*
```

### Step 4 — globals.yml

`/etc/kolla/globals.yml` 말미에 추가함. 각자 수정할 곳은 **자기 값 두 곳**뿐.

```yaml
########################################
# OpenStack 스터디 시즌1 — AIO / ML2-OVS
########################################

# --- 기본 ---
kolla_base_distro: "ubuntu"
kolla_internal_vip_address: "<자기 값 ①: VM 사설 IP>"   # ip a로 확인. 공인 IP 절대 아님!
network_interface: "<자기 값 ②: 인터페이스명>"           # eth0 / ens3 등
neutron_external_interface: "veth1"

# --- 단일 노드: LB 계층 제거 ---
enable_haproxy: "no"
enable_keepalived: "no"
enable_proxysql: "no"

# --- 네트워크 백엔드: OVS (6회차 netns 실습 전제) ---
neutron_plugin_agent: "openvswitch"

# --- 컴퓨트 ---
nova_compute_virt_type: "qemu"     # egrep -c '(vmx|svm)' /proc/cpuinfo 가 1 이상이면 kvm

# --- 스터디 범위 밖: 배포 시간·메모리 절약 ---
enable_cinder: "no"
enable_heat: "no"
enable_swift: "no"
enable_octavia: "no"
enable_barbican: "no"
enable_designate: "no"
enable_magnum: "no"
enable_prometheus: "no"
enable_grafana: "no"
enable_central_logging: "no"
```

**의도적으로 넣지 않는 것**

| 변수 | 이유 |
| --- | --- |
| `openstack_release` | kolla-ansible 22.0.0이 자기 버전(2026.1)에 맞는 값을 보유. 임의 지정 시 pull 실패 위험 |
| `enable_mariadb` / `enable_rabbitmq` / `enable_memcached` | `enable_openstack_core: true`에 의해 자동 활성화됨 |

- 흔한 실수 1순위: VIP에 **공인 IP**를 넣는 것. 공인 IP는 VM 밖(가비아 NAT)에 있는 주소라 서비스가 바인딩할 수 없음

### Step 5 — 배포

```bash
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/kolla-nopasswd
sudo chmod 0440 /etc/sudoers.d/kolla-nopasswd

kolla-ansible install-deps
kolla-ansible bootstrap-servers -i /etc/kolla/all-in-one
```

**bootstrap 후 docker 그룹 확인** — bootstrap-servers가 그룹 추가를 누락하는 경우가 있음. 미조치 시 deploy 중 `docker.sock permission denied` 발생함.

```bash
sudo usermod -aG docker $USER
# SSH 완전 재접속 (newgrp보다 확실함)
```

```bash
tmux new -s kolla        # 이후 전 과정은 tmux 안에서 (SSH 끊겨도 진행됨)
source ~/kolla-venv/bin/activate

kolla-ansible prechecks   -i /etc/kolla/all-in-one
kolla-ansible pull        -i /etc/kolla/all-in-one   # 이미지 미리 받기
kolla-ansible deploy      -i /etc/kolla/all-in-one   # 30~60분
kolla-ansible post-deploy -i /etc/kolla/all-in-one
```

- `pull`과 `deploy` 분리가 핵심 — 한 번에 돌리면 배포 중간에 다운로드가 끼어들어 타임아웃으로 죽는 경우가 있음
- deploy는 멱등 — 실패 시 원인 수정 후 같은 명령 재실행하면 이어서 진행됨

배포 확인:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}' | sort
# keystone, nova_*, neutron_*(l3/dhcp/ovs agent 포함), openvswitch_*, horizon,
# mariadb, rabbitmq, memcached ... 전부 Up이면 성공
```

### Step 6 — 외부망 배관 (br-ex + MASQUERADE)

`br-ex`는 배포 후 OVS가 생성하므로 사전에 IP를 줄 수 없음. systemd 유닛으로 부팅 시마다 부여함.

`/etc/systemd/system/br-ex-gw.service`

```ini
[Unit]
Description=Assign gateway IP to br-ex for Neutron external network
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=/bin/sh -c 'until ip link show br-ex >/dev/null 2>&1; do sleep 2; done'
ExecStart=/sbin/ip addr replace 192.168.200.1/24 dev br-ex
ExecStart=/sbin/ip link set br-ex up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now br-ex-gw.service
ip addr show br-ex   # 192.168.200.1 확인
```

**MASQUERADE** — FIP 대역(사설)이 인터넷으로 나가는 출구

```bash
IFACE=<자기 값 ②>
sudo apt install -y iptables-persistent
sudo iptables -t nat -A POSTROUTING -s 192.168.200.0/24 -o $IFACE -j MASQUERADE
sudo iptables -I FORWARD -s 192.168.200.0/24 -j ACCEPT
sudo iptables -I FORWARD -d 192.168.200.0/24 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo netfilter-persistent save
```

> Step 2 + Step 6의 systemd 유닛 두 개(veth-setup, br-ex-gw)가 스터디의 `init.sh`가 하는 일의 전부. 재부팅 후 네트워크가 살아 있는 이유가 이 두 유닛임.

### Step 7 — OpenStack 네트워크·이미지·플레이버

```bash
source /etc/kolla/admin-openrc.sh

# 외부(프로바이더) 네트워크 — FIP 풀
openstack network create --external \
  --provider-network-type flat \
  --provider-physical-network physnet1 \
  provider_network

openstack subnet create provider_subnet \
  --network provider_network --no-dhcp \
  --subnet-range 192.168.200.0/24 \
  --gateway 192.168.200.1 \
  --allocation-pool start=192.168.200.101,end=192.168.200.150

# 테넌트 네트워크
openstack network create tenant_network
openstack subnet create tenant_subnet \
  --network tenant_network \
  --subnet-range 10.10.10.0/24 \
  --dns-nameserver 8.8.8.8

# 라우터 — 외부 IP를 명시 지정 (미지정 시 FIP 풀을 임의 잠식함)
openstack router create tenant_router
openstack router set tenant_router --external-gateway provider_network \
  --fixed-ip ip-address=192.168.200.2
openstack router add subnet tenant_router tenant_subnet
```

| 대역 | 용도 |
| --- | --- |
| `192.168.200.1` | br-ex (호스트, 게이트웨이) |
| `192.168.200.2` | tenant_router 외부 포트 |
| `.101 – .150` | FIP 풀 |

- `--dns-nameserver` 미지정 시 인스턴스가 도메인 해석 불가함

```bash
# 이미지 (CirrOS ~20MB) · 플레이버 · 키페어 · 보안그룹
wget http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create "cirros" \
  --file cirros-0.6.2-x86_64-disk.img \
  --disk-format qcow2 --container-format bare --public

openstack flavor create --vcpus 1 --ram 512 --disk 1 m1.tiny

openstack keypair create mykey > ~/mykey.pem && chmod 600 ~/mykey.pem

openstack security group rule create --protocol icmp default
openstack security group rule create --protocol tcp --dst-port 22 default
```

### Step 8 — 인스턴스 기동 + 검증 (시즌1 최종 목표)

```bash
openstack server create test-vm \
  --image cirros --flavor m1.tiny \
  --key-name mykey --network tenant_network

openstack floating ip create provider_network
openstack server add floating ip test-vm <할당된 FIP>

ping <FIP>
ssh cirros@<FIP>        # 🏁 성공 시 시즌1 목표 달성
```

netns로 라우터 실체 확인 (6회차 실습):

```bash
ip netns list                                  # qrouter-*, qdhcp-* 확인
QR=$(ip netns list | grep -o 'qrouter-[^ ]*')
sudo ip netns exec $QR ip a                    # 라우터의 인터페이스 = 10.10.10.1 / 192.168.200.2
sudo ip netns exec $QR iptables -t nat -L      # SNAT/DNAT 규칙 = FIP의 실체
```

---

## 4. 예방 포인트 (운영계 구축에서 확인된 함정)

| 함정 | 증상 | 예방 |
| --- | --- | --- |
| hostname이 루프백 해석 | 배포 중반 RabbitMQ 관련 실패 | Step 1의 sed **치환** (tee -a 금지) |
| rp_filter strict | FIP ping/SSH 무응답, 로그 없음 | Step 1의 `rp_filter=2` |
| VIP에 공인 IP | prechecks 또는 서비스 바인딩 실패 | VIP = 사설 IP |
| docker 그룹 누락 | deploy 중 permission denied | bootstrap 후 `usermod -aG docker` + 재접속 |
| veth0을 브리지에 부착 | 관리망으로 플러딩 유출 | veth0은 UP만, 미부착 |
| 라우터 외부 IP 미지정 | FIP 풀 임의 잠식 | `--fixed-ip` 명시 |
| br-ex IP가 재부팅에 소실 | FIP 통신 두절 (과거 DevStack에서 동일 증상 실측) | br-ex-gw.service |
| passwords.yml 분실 | 복구 불가 | 생성 직후 백업 |

## 5. 알아둘 것

- 관리 명령은 컨테이너 안: `docker exec -it nova_api nova-manage cell_v2 list_hosts`
- 서비스 재시작: `docker restart <컨테이너명>` / 로그: `/var/log/kolla/<서비스>/`
- 인스턴스 ERROR 시 사유 확인: `openstack server show <이름> -c fault`
- **MTU 1450**: VXLAN 캡슐화 오버헤드(1500−50)로 인스턴스 MTU가 자동 조정됨. 인스턴스에서 대용량 전송 문제 시 1차 확인 지점
- 인스턴스 부팅 1~2분 소요는 QEMU 에뮬레이션 모드의 정상 동작 (중첩 가상화 미지원 시)
