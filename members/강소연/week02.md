# 2회차 OpenStack 아키텍처·Neutron 예습 정리

## 1. OpenStack 이란

OpenStack은 여러 물리 서버의 CPU, 메모리, 스토리지, 네트워크를 하나의 자원 풀처럼 묶고 API를 통해 사용자에게 제공하는 오픈소스 IaaS 플랫폼이다. 하나의 거대한 프로그램이 아니라 인증, 컴퓨트, 네트워크, 이미지, 스토리지 역할을 맡은 여러 독립 서비스의 집합이다.

사용자가 Horizon이나 CLI에서 VM 생성을 요청하면 Keystone이 인증하고, Nova가 요청 접수와 배치를 조정하며, Placement가 가용 자원을 알려 준다. 선택된 컴퓨트 노드의 nova-compute는 Glance에서 이미지를 받고 Neutron에서 포트와 IP를 할당받은 뒤 libvirt를 통해 QEMU/KVM VM을 기동한다. 서비스 간 요청에는 REST API를, 같은 서비스 내부의 오래 걸리는 작업 전달에는 RabbitMQ 기반 RPC를 사용한다.

Neutron은 논리 네트워크를 실제 Linux 네트워크 구성으로 변환한다. 이번 실습에서 사용하는 OVS 방식은 노드별 에이전트, Open vSwitch 브리지, 네트워크 네임스페이스를 이용한다. 여러 컴퓨트 노드에 흩어진 VM을 같은 네트워크에 있는 것처럼 연결할 때는 VXLAN 같은 터널 프로토콜로 원본 프레임을 물리망용 UDP 패킷 안에 캡슐화한다.

## 2. OpenStack의 구조

### 2.1 OpenStack이 ‘클라우드 운영체제’인 이유

일반 운영체제가 한 컴퓨터의 CPU·메모리·디스크를 여러 프로세스에 나누어 주듯, OpenStack은 데이터센터에 있는 여러 서버의 컴퓨팅·스토리지·네트워크 자원을 여러 프로젝트(테넌트)에 나누어 준다. 자원을 준비해 실제로 사용할 수 있는 상태로 만드는 과정을 프로비저닝이라고 한다.

Horizon의 버튼, OpenStack CLI, SDK는 표현 방식만 다를 뿐 최종적으로 같은 REST API를 호출한다. 모든 API 요청은 Keystone이 발급한 인증 토큰을 사용하므로 인증 체계가 서비스 전체를 하나로 묶는다.

### 2.2 주요 컴포넌트

| 컴포넌트 | 역할 | 대표 포트 | AWS 유사 서비스 |
|---|---|---:|---|
| Keystone | 사용자·프로젝트·역할 관리, 토큰 발급 및 인증·인가 | 5000 | IAM |
| Nova | VM 생성, 배치, 중지, 삭제 등 생명주기 관리 | 8774 | EC2 |
| Neutron | 네트워크, 서브넷, 라우터, 보안 그룹, Floating IP 관리 | 9696 | VPC |
| Glance | VM 부팅 이미지 등록·저장·조회 | 9292 | AMI |
| Cinder | VM에 연결하는 영속 블록 볼륨 관리 | 8776 | EBS |
| Horizon | OpenStack API를 호출하는 웹 대시보드 | 80/443 | Management Console |
| Placement | 컴퓨트 노드별 CPU·메모리·디스크 자원 인벤토리 관리 | 8778 | 직접 대응 없음 |

추가 서비스로는 오브젝트 스토리지 Swift, 로드밸런서 Octavia, DNS Designate, 오케스트레이션 Heat, 베어메탈 Ironic, 공유 파일시스템 Manila, 시크릿 관리 Barbican 등이 있다. 이 구성을 보면 퍼블릭 클라우드의 서비스들이 해결하는 문제가 OpenStack 프로젝트와 상당히 비슷하다는 것을 알 수 있다.

### 2.3 서비스 간 통신

#### REST API

서로 다른 서비스 사이의 요청은 주로 HTTP 기반 REST API를 사용한다. 예를 들어 `openstack server list`는 내부적으로 Nova의 `GET /v2.1/servers` 요청으로 변환되며 `X-Auth-Token` 헤더가 함께 전달된다.

Keystone 인증 흐름은 다음과 같다.

1. 클라이언트가 Keystone에 ID와 비밀번호를 제출한다.
2. Keystone이 토큰과 서비스 카탈로그를 반환한다.
3. 클라이언트가 카탈로그에서 Nova 주소를 찾고 토큰을 붙여 요청한다.
4. Nova API가 공통 인증 체계를 통해 토큰의 유효성과 권한을 확인한다.
5. 유효한 요청이면 Nova가 실제 처리를 시작한다.

서비스 카탈로그에는 Nova, Glance 등 각 서비스의 API 엔드포인트가 들어 있다. 클라이언트는 Keystone의 주소만 알아도 나머지 서비스 주소를 발견할 수 있다. Fernet 토큰은 사용자·프로젝트·만료 시각 등의 정보를 대칭키로 보호한 무상태 토큰이므로, 발급한 모든 토큰을 DB에 저장하는 방식보다 확장에 유리하다.

#### RabbitMQ 기반 RPC

nova-api, nova-scheduler, nova-conductor, nova-compute처럼 같은 서비스 안에서 역할이 분리된 프로세스들은 RabbitMQ를 통한 RPC로 통신한다.

```text
Producer → Exchange → Binding → Queue → Consumer
```

- `call`: 요청을 보낸 뒤 응답을 기다리는 동기 방식
- `cast`: 메시지를 보낸 뒤 즉시 반환하는 비동기 방식

VM 생성처럼 수십 초 이상 걸리는 작업은 API 프로세스를 오래 점유하지 않도록 비동기로 전달한다. 큐는 작업자 장애 시 메시지를 보존할 수 있고, 같은 큐를 소비하는 작업자를 늘려 수평 확장하기도 쉽다.

### 2.4 공용 인프라

| 구성 요소 | 역할 | 장애 시 영향 |
|---|---|---|
| MariaDB | 각 서비스의 구성과 자원 상태를 영속적으로 저장 | 상태 조회·변경이 불가능해져 제어 영역이 사실상 마비됨 |
| RabbitMQ | 서비스 내부 프로세스 사이의 RPC 메시지 전달 | 스케줄링·생성 같은 비동기 작업 전달이 멈추고 요청이 지연·실패함 |
| Memcached | 토큰 검증 결과 등 자주 쓰는 데이터를 메모리에 캐시 | 인증 백엔드 부하와 지연이 크게 증가함 |
| HAProxy | 다중 노드 API의 단일 진입점과 부하 분산 | API 진입점의 가용성과 분산 기능을 잃음 |

## 3. Nova와 VM 생성 경로

### 3.1 Nova 내부 프로세스

| 프로세스 | 역할 |
|---|---|
| nova-api | REST 요청 접수, 토큰·권한 검사, 초기 DB 레코드 생성 |
| nova-scheduler | Placement의 자원 정보를 바탕으로 실행 노드 결정 |
| nova-conductor | nova-compute의 DB 접근을 대신 수행하는 중계 계층 |
| nova-compute | 이미지·네트워크·볼륨을 준비하고 하이퍼바이저에 VM 생성을 지시 |

스케줄러는 메모리나 디스크가 부족한 노드를 Filter 단계에서 제거하고, 남은 후보를 Weigh 단계에서 점수화해 최적 노드를 선택한다. nova-conductor는 많은 컴퓨트 노드가 중앙 DB에 직접 연결하지 못하게 하여 DB 연결 수와 보안 노출 범위를 줄인다.

### 3.2 VM 생성의 전체 흐름

1. 사용자가 Horizon 또는 CLI로 생성 요청을 보내고 Keystone 토큰을 얻는다.
2. nova-api가 토큰을 검증하고 DB에 `BUILD` 상태의 인스턴스 레코드를 만든다.
3. nova-scheduler가 Placement에서 후보 노드를 조회해 Filter/Weigh로 배치 노드를 정한다.
4. 선택된 노드의 nova-compute가 RabbitMQ를 통해 생성 작업을 받는다.
5. nova-compute가 Glance 이미지, Neutron 포트·MAC·IP, 필요한 경우 Cinder 볼륨을 준비한다.
6. nova-compute가 libvirt에 VM 정의를 넘기고 QEMU/KVM이 VM 프로세스를 실행한다. 준비가 끝나면 상태가 `ACTIVE`가 된다.

초기에 Horizon에 `BUILD`가 표시되는 것은 DB에 논리적 레코드가 만들어졌다는 뜻일 뿐, VM 프로세스가 이미 실행 중이라는 뜻은 아니다. 처음 사용하는 이미지는 Glance에서 내려받아야 하지만 이후에는 로컬 캐시를 이용할 수 있어 더 빨라질 수 있다.

### 3.3 하이퍼바이저와 중첩 가상화

```text
nova-compute → libvirt → QEMU/KVM → VM 프로세스
```

- libvirt: 서로 다른 하이퍼바이저를 공통 API로 제어하는 추상화 계층
- KVM: CPU의 VT-x/AMD-V를 이용하는 Linux 커널 가상화 기능
- QEMU: VM 프로세스와 가상 장치를 실행하는 에뮬레이터

실습 환경은 클라우드 VM 안에서 다시 OpenStack VM을 실행하는 중첩 가상화 구조다. 바깥 하이퍼바이저가 가상화 CPU 기능을 노출하지 않으면 안쪽 VM은 KVM 가속을 사용할 수 없고 QEMU 소프트웨어 에뮬레이션으로 동작해 부팅이 느려진다.

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

결과가 `0`이면 CPU 가상화 플래그가 보이지 않는 상태다. 또한 OpenStack 제어 서비스와 VM은 메모리를 함께 사용하므로 메모리 부족 시 OOM Killer가 `mysqld`나 `qemu-system-x86`을 종료할 수 있다. 인스턴스가 갑자기 꺼졌을 때 Nova만 추측하지 말고 `dmesg`와 서비스 로그를 확인해야 한다.

## 4. Neutron 내부 구조

### 4.1 핵심 네트워크 자원

- Network: 가상의 L2 스위치
- Subnet: Network에서 사용할 IP 대역과 주소 할당 정보
- Router: 서로 다른 네트워크 또는 내부망과 외부망을 연결
- Security Group: 인스턴스 포트에 적용되는 상태 기반 방화벽 규칙
- Floating IP: 외부 네트워크의 IP를 내부 인스턴스 포트에 매핑하는 접근 수단

가상 스위치(vSwitch)는 한 호스트 안의 VM vNIC과 물리 NIC을 연결한다. 네트워크 네임스페이스(netns)는 인터페이스·라우팅 테이블·방화벽 규칙을 서로 격리한 독립 네트워크 공간이며, OVS 방식의 Neutron은 이를 사용해 가상 라우터와 DHCP 서비스를 구현한다.

### 4.2 OVS 방식

```text
neutron-server → ML2(Open vSwitch mechanism driver)
               → RabbitMQ RPC → 각 노드의 Neutron 에이전트
```

- neutron-ovs-agent: OVS 브리지와 OpenFlow 규칙 구성
- neutron-l3-agent: 라우터 네임스페이스와 라우팅·NAT 관리
- neutron-dhcp-agent: DHCP 네임스페이스에서 dnsmasq를 실행해 IP 배부

| OVS 브리지 | 역할 |
|---|---|
| br-int | VM 포트가 연결되는 통합 브리지 |
| br-tun | 다른 노드와의 VXLAN 등 오버레이 터널 처리 |
| br-ex | Provider/External 네트워크로 나가는 외부 브리지 |

서버가 변경 내용을 RabbitMQ로 에이전트에 전달하면 에이전트가 명령을 실행하는 명령형 구조다.

### 4.3 OVN 방식과의 차이

OVN에서는 neutron-server가 원하는 논리 네트워크 상태를 Northbound DB에 기록한다. `ovn-northd`가 이를 실행 가능한 논리 흐름으로 변환해 Southbound DB에 기록하고, 각 노드의 `ovn-controller`가 DB 변경을 구독해 자신의 OVS에 필요한 규칙만 반영한다.

| 항목 | OVS 에이전트 방식 | OVN 방식 |
|---|---|---|
| 전달 | RabbitMQ RPC push | DB 상태 구독 |
| 노드 프로세스 | ovs/l3/dhcp agent | ovn-controller 중심 |
| L3 | l3-agent와 netns | OVN의 분산 라우팅 |
| 상태 모델 | 명령형 | 선언형·상태 수렴 |
| 대규모 확장 | RabbitMQ와 다수 에이전트가 병목 가능 | 분산 DB 구독과 로컬 반영으로 확장에 유리 |

최신 대규모 환경에서는 OVN이 유리하지만, 이번 실습은 가상 라우터의 netns와 OVS 브리지를 직접 관찰하는 것이 목적이므로 구조가 눈에 보이는 OVS 방식을 사용한다.

## 5. 오버레이 네트워크와 가상화 용어

### 5.1 VXLAN 캡슐화

서로 다른 물리 호스트의 VM이 같은 테넌트 네트워크에 있을 때, 송신 호스트는 VM의 원본 Ethernet 프레임 전체를 물리 호스트 간 UDP 패킷 안에 넣는다.

```text
[외부 Ethernet: 송신 호스트 MAC → 수신 호스트 MAC]
[외부 IP:       송신 호스트 IP  → 수신 호스트 IP]
[UDP:           목적지 포트 4789]
[VXLAN:         VNI]
[내부 원본 Ethernet/IP 패킷 전체]
```

물리 네트워크는 이를 호스트 사이의 평범한 UDP/IP 패킷으로 전달한다. 수신 호스트의 OVS가 외부 헤더를 제거하고 VNI로 테넌트 네트워크를 식별해 목적 VM에 보낸다. 따라서 물리 라우터가 테넌트의 사설 IP 대역이나 VM MAC 주소를 알지 못해도 여러 호스트에 걸친 L2 네트워크를 구성할 수 있다.

### 5.2 VLAN, VXLAN, Geneve

- VLAN은 12비트 VID로 하나의 물리 L2 망을 논리적으로 분리한다. 약 4,096개의 ID 한계가 있다.
- VXLAN은 24비트 VNI를 사용해 약 1,600만 개의 논리 네트워크를 식별하고 UDP 4789로 전송한다.
- Geneve도 24비트 VNI를 사용하지만 가변 옵션 필드가 있어 논리 포트 등 추가 메타데이터를 전달할 수 있다. OVN은 기본적으로 Geneve를 사용한다.

SDN은 네트워크 제어부와 패킷 전송부를 분리해 소프트웨어가 중앙에서 규칙을 관리하는 접근이다. NFV는 라우터·방화벽·로드밸런서 같은 네트워크 기능을 전용 장비 대신 범용 서버의 소프트웨어로 구현하는 접근이다. Neutron은 논리 정책을 OVS에 반영한다는 점에서 SDN이며, netns 기반 가상 라우터는 NFV의 사례이기도 하다.

## 6. Ceph와 배포 도구

프로덕션 OpenStack에서는 Ceph가 대표적인 분산 스토리지 백엔드다.

- MON: 클러스터 맵과 상태의 합의 관리
- OSD: 실제 데이터 저장, 복제, 복구, 리밸런싱
- MGR: 운영 메트릭과 관리 기능
- MDS: CephFS 메타데이터 관리
- RBD: Cinder 볼륨과 Glance 이미지에 연결되는 블록 스토리지
- RGW: S3 호환 오브젝트 API
- CephFS: POSIX 호환 파일시스템

CRUSH는 중앙 위치 조회 테이블 대신 오브젝트 ID와 클러스터 맵으로 저장 OSD를 계산한다. 클라이언트가 OSD에 직접 접근하므로 중앙 조회 서버 병목을 줄일 수 있다.

이번 실습은 서비스별 Docker 컨테이너와 Ansible 자동화를 사용하는 Kolla-Ansible로 OpenStack을 배포한다. DevStack보다 준비가 필요하지만 서비스 구성이 명확하게 보이고, 반복 실행해도 목표 상태로 맞추는 멱등성을 가지며, 실제 운영과 가까운 구조를 경험할 수 있다.

## 7. 필수 예습 질문 답변

### Q1. Nova/Neutron/Glance/Keystone을 AWS 서비스와 짝짓고, Keystone이 모든 요청의 관문인 이유를 설명하라.

Nova는 EC2, Neutron은 VPC, Glance는 AMI, Keystone은 IAM에 대응한다.

Keystone은 단순 로그인 화면이 아니라 공통 신원·권한 체계다. 클라이언트가 자격 증명을 Keystone에 제출하면 토큰과 서비스 카탈로그를 받는다. 이후 Nova 등 목적 서비스에 `X-Auth-Token`을 붙여 요청한다. 각 서비스는 토큰의 유효 기간, 프로젝트 범위, 역할과 정책을 확인하고 권한이 있을 때만 요청을 처리한다. 따라서 어떤 자원을 다루든 유효한 Keystone 신원과 권한이 먼저 필요하다는 의미에서 모든 요청의 관문이다.

### Q2. nova-api와 nova-compute가 메시지 큐로 통신하는 이유 3가지는?

1. **비동기 처리:** nova-api는 오래 걸리는 VM 생성 완료를 기다리지 않고 메시지를 전달한 뒤 다음 API 요청을 처리할 수 있다.
2. **내결함성:** nova-compute가 일시적으로 응답하지 않아도 큐에 남은 메시지를 복구 후 처리하거나 실패 상태로 관리할 수 있다.
3. **수평 확장:** 여러 컴퓨트 노드와 작업자가 큐를 나누어 소비할 수 있어 노드를 늘리기 쉽고 요청을 분산할 수 있다.

### Q3. MariaDB, RabbitMQ, Memcached의 역할과 장애 영향은?

MariaDB는 Nova·Neutron 등 서비스의 영속 상태를 저장한다. 장애가 나면 기존 VM이 즉시 사라지는 것은 아니지만 제어 서비스가 상태를 읽고 갱신할 수 없어 조회·생성·삭제 같은 관리 작업이 광범위하게 실패한다. RabbitMQ는 서비스 내부 RPC 작업을 전달하므로 장애 시 스케줄링과 컴퓨트 작업 전달이 멈추고 API 요청이 지연되거나 실패한다. Memcached는 인증 검증 결과 같은 반복 데이터를 캐시한다. 장애 시 원본 데이터가 소실되지는 않지만 캐시 미스로 Keystone과 DB 부하가 커지고 인증 지연이나 연쇄 장애 위험이 증가한다.

## 8. 심화 확인 질문 답변

### Q1. VM 생성 단계 중 1~4보다 5~6이 오래 걸리는 이유는?

1~4단계는 인증 정보 확인, DB 레코드 생성, 자원 조회·계산, 메시지 전달처럼 비교적 작은 제어 영역 작업이다. 반면 5~6단계는 실제 데이터와 운영체제 자원을 다루는 데이터 영역 작업이다. Glance 이미지 다운로드와 복사, qcow2 파일 준비, Neutron 포트·OVS 흐름·네임스페이스 구성, 필요 시 볼륨 연결, libvirt XML 생성, QEMU 프로세스 시작, 게스트 OS 부팅과 DHCP까지 포함한다. 네트워크·디스크 I/O와 여러 서비스의 완료 대기가 필요하므로 수십 초 이상 걸릴 수 있다. KVM 가속을 사용할 수 없다면 QEMU가 CPU까지 에뮬레이션해 차이가 더 커진다.

### Q2. OVS 방식에서 수백 노드로 확장할 때의 병목과 OVN의 회피 방법은?

OVS 에이전트 방식은 neutron-server가 RabbitMQ RPC를 통해 노드별 ovs/l3/dhcp 에이전트에 변경을 전달한다. 노드와 포트가 늘면 메시지 팬아웃, 큐 적체, 에이전트 상태 동기화, 중앙 서버 처리량이 병목이 될 수 있다. 여러 종류의 에이전트가 각각 상태를 맞추므로 운영 복잡성도 커진다.

OVN은 원하는 논리 상태를 Northbound DB에 기록하고, 이를 Southbound DB의 실행 가능한 흐름과 포트 바인딩으로 변환한다. 각 호스트의 ovn-controller는 Southbound DB 변경을 구독하고 자신에게 필요한 규칙만 로컬 OVS에 반영한다. 중앙에서 모든 노드에 개별 명령을 밀어 넣는 대신 분산된 컨트롤러가 공통 상태를 보고 스스로 수렴하므로 RabbitMQ 팬아웃과 다중 에이전트 병목을 줄인다.

### Q3. VXLAN 패킷을 물리 라우터는 어떻게 인식하며, 그 덕분에 무엇이 가능한가?

물리 라우터는 내부 VM 패킷을 보지 않고, 송신 터널 엔드포인트의 물리 IP에서 수신 터널 엔드포인트의 물리 IP로 가는 일반 UDP/IP 패킷으로 인식한다. 테넌트의 사설 IP와 VM MAC, 논리 네트워크 구분은 VXLAN 내부 프레임과 VNI에 들어 있고 터널 종단의 OVS가 처리한다. 따라서 물리 네트워크를 변경하거나 테넌트 주소를 라우팅 테이블에 등록하지 않아도 서로 다른 호스트의 VM을 같은 L2 네트워크에 연결할 수 있다. 24비트 VNI 덕분에 VLAN보다 훨씬 많은 격리 네트워크도 만들 수 있다.

### Q4. 최신 OVN 대신 OVS를 선택한 이유를 6회차 실습과 연결해 설명하라.

이번 스터디의 목적은 최신 기술을 선택하는 것 자체가 아니라 가상 네트워크의 실체를 직접 관찰하는 것이다. OVS 방식에서는 l3-agent가 Linux 네트워크 네임스페이스 안에 가상 라우터를 만들고 DHCP agent가 dnsmasq를 실행하며, `br-int`, `br-tun`, `br-ex`의 역할도 명확히 나뉜다. 따라서 6회차에 `ip netns`로 라우터를 찾고 네임스페이스 안의 인터페이스·라우팅·NAT를 확인하면서 Horizon의 논리 객체가 Linux에서 어떻게 구현되는지 추적할 수 있다. OVN은 L3를 분산 논리 흐름으로 구현해 같은 형태의 라우터 netns가 없으므로 해당 실습의 관찰 지점이 사라진다. 학습 목표에 OVS가 더 적합하다는 선택이다.
