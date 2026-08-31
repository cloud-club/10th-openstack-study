# OpenStack 공부 노트 (스터디장 공유본)

> 프로젝트를 진행하며 개인적으로 정리한 공부 노트입니다. 스터디 예습 자료와 별개로, 참고용으로 공유합니다.
실습 기록(DevStack)과 트러블슈팅 과정이 그대로 담겨 있어서, 우리가 5~6회차에 겪을 상황의 예고편이기도 합니다.
> 

---

# Ch 1. OpenStack & Components

### 참고자료

- [https://www.openstack.org/software/](https://www.openstack.org/software/)
- [https://velog.io/@dlwpdlf147/OpenStack-오픈스택이란](https://velog.io/@dlwpdlf147/OpenStack-%EC%98%A4%ED%94%88%EC%8A%A4%ED%83%9D%EC%9D%B4%EB%9E%80)
- [https://wikidocs.net/230172](https://wikidocs.net/230172)

## 1. OpenStack이란

OpenStack은 데이터센터 전반에 걸쳐 있는 대규모의 컴퓨팅, 스토리지, 네트워킹 자원 풀(pool)을 제어하는 클라우드 운영체제이며, 이 모든 자원은 공통된 인증 메커니즘을 갖춘 API를 통해 관리되고 프로비저닝 된다. - openstack 공식 소개

→ 클라우드 컴퓨팅 환경을 구축하고 관리할 수 있는 **오픈소스 소프트웨어 플랫폼**
쉽게 말해 AWS나 Kakaocloud 같은 클라우드 서비스를 내 회사 서버에 직접 만들 수 있게 해주는 도구

## 2. IaaS & OpenStack

1. IaaS (Infrastructure as a Service) 란
    - 서버, 스토리지 및 네트워크 등과 같은 사용자가 필요한 컴퓨팅 자원(IT 인프라)을 가상화된 형태로 제공하는 서비스
2. IaaS 와 OpenStack의 관계
    - OpenStack을 활용해 내 컴퓨팅·스토리지·네트워킹 자원을 가상화하여 사용자에게 자원을 제공함으로써 **IaaS형 CSP의 역할을 수행**

## 3. Components

굵게 표시한 것이 스터디에서 다루는 핵심 컴포넌트.

- **Compute**
    1. **Nova - Compute Service**
        - 가상 머신(VM)의 생명 주기 관리(생성, 스케줄링, 삭제)를 담당
    2. Zun - Containers Service
- **Storage**
    1. Swift - Object Storage
        - 객체 스토리지 서비스, 대규모 비정형 데이터 저장, HTTP로 접근 가능
    2. **Cinder - Block Storage**
        - 블록 스토리지 서비스 제공, 데이터베이스, 파일 시스템 등을 위한 스토리지 볼륨 관리
    3. Manila - Shared filesystems
- **Networking**
    1. **Neutron - Networking (VPC)**
        - 클라우드 내 네트워킹 기능을 관리하는 컴포넌트로, 가상 네트워크, 서브넷, 라우터 등을 설정하고 관리
    2. Octavia - Load Balancer
    3. Designate - DNS Service
- **Shared Services**
    1. **Keystone - Identity service**
        - OpenStack 내의 모든 인증 및 권한 부여 작업을 담당하는 서비스, 사용자와 서비스 간의 인증 관리
    2. Placement - Placement service
    3. **Glance - Image service**
        - 가상 머신 이미지 관리 서비스, VM 이미지 등록, 저장, 검색 기능 제공
    4. Barbican - Key management
- **Orchestration**
    1. Heat - Orchestration
        - 오케스트레이션 서비스, 템플릿을 사용하여 애플리케이션 스택의 자원을 자동으로 생성하고 관리
    2. Mistral - Workflow service
    3. Zaqar - Messaging Service
    4. Blazar - Resource reservation service
    5. AODH - Alarming Service
- **Workload Provisioning**
    1. Magnum - Container Orchestration Engine Provisioning
    2. Trove - Database as a Service
        - 데이터베이스 서비스, 관계형 및 비관계형 데이터베이스 인스턴스를 관리할 수 있게 함
- **Application Lifecycle**
    1. Freezer - Backup and Restore
    2. Masakari - Instances High Availability Service
- **Web frontends**
    1. **Horizon - Dashboard**
        - OpenStack의 대시보드, 웹 기반의 사용자 인터페이스를 제공하여 OpenStack 서비스를 관리
    2. Skyline - Next Generation Dashboard
- **Hardware Lifecycle**
    1. Ironic - Bare Metal Provisioning Service
    2. Cyborg - Lifecycle management of accelerators
- **Monitoring service**
    1. Ceilometer - Metering & Data Collection Service
        - 텔레메트리 서비스, 클라우드 사용에 대한 메트릭 수집, 모니터링 및 빌링을 위한 데이터를 제공
- **Resource optimization**
    1. Watcher - Optimization Service
- **Billing / Business Logic**
    1. Adjutant - Operators processes automation
    2. Cloudkitty - Billing and chargebacks
- **Testing / Benchmark**
    1. Rally - Benchmarking tool
    2. Tempest - The OpenStack Integration Test Suite

![openstack-architecture.png](OpenStack%20%EA%B3%B5%EB%B6%80%20%EB%85%B8%ED%8A%B8%20(%EC%8A%A4%ED%84%B0%EB%94%94%EC%9E%A5%20%EA%B3%B5%EC%9C%A0%EB%B3%B8)/openstack-architecture.png)

---

# Ch 2. 네트워크 가상화

## NAT (Network Address Translation)

사설 네트워크의 호스트가 외부의 공개된 네트워크에 연결할 수 있도록 상호 간에 주소를 변환해 주는 기술

- 사용 이유: IPv4 주소 부족
- NAT를 사용하면 하나의 공인 IP 주소를 여러 기기가 공유할 수 있음
- 외부에서 내부로 접속하려면 Port Forwarding 필요

#### 사설 IP 주소 대역 (RFC 1918)

- `10.0.0.0 ~ 10.255.255.255` (10.0.0.0/8)
- `172.16.0.0 ~ 172.31.255.255` (172.16.0.0/12)
- `192.168.0.0 ~ 192.168.255.255` (192.168.0.0/16)

#### 사용 예시

1. 위키피디아라는 사이트에 접속하고 싶으면, 컴퓨터는 Gateway addr에 해당되는 IP 머신(공유기)에게 신호를 보낸다.
2. 공유기는 먼저 요청 받은 내부 IP를 기록한다. 누가 요청했는지 알아야 하기 때문.
3. 요청한 컴퓨터 IP는 외부에서 접속할 수 없는 사설 IP이다. 따라서 사설 IP를 공인 IP로 변환한다.
4. 공유기는 이 요청을 public IP address로 위키피디아에게 요청을 하고 위키피디아는 그 요청을 처리한다.
5. 위키피디아에서 보낸 응답을 공유기가 받아 다시 사설 IP로 변환해 사설 IP에 해당하는 컴퓨터로 보낸다.

## Network Virtualization

물리적인 네트워크 형태를 따르지 않는 가상적/논리적 망 또는 회선

스위치나 라우터 등의 물리적 네트워크 장비 기능을 가상화하여 가상 머신(VM)이나 컨테이너, 또는 범용 프로세서를 탑재한 하드웨어에서 구동하는 방식

이를 통해 새로운 장비를 설치하지 않아도 소프트웨어적으로 라우팅, 방화벽, 로드밸런싱, WAN 가속, 암호화 등의 네트워크 기능을 구현하거나 네트워크 상의 다양한 위치로 이동이 가능

- 네트워크 가상화의 예: VLAN / VXLAN / vSwitch / NFV / SDN

### VLAN (Virtual LAN)

물리적인 네트워크를 논리적인 네트워크로 분할하는 가상화 기술

사용 이유: Broadcast Domain을 분할하기 위해서 (ARP Broadcast)

**IEEE 802.1Q Tag Frame**

- TPID (Tag Protocol Identifier, 16bit): 2Byte 태그(0x8100)가 존재함을 알리는 식별자
- PCP (Priority Code Point, 3bit): 0~7까지 우선순위 (CoS)
- CFI (Canonical Format Indicator, 1bit): Ethernet = 0 / Token Ring = 1
- VID (VLAN Identifier, 12bit): 각각의 VLAN 식별

### VXLAN (Virtual eXtensible LAN)

VLAN의 한계를 극복하기 위해 등장한 기술로, L3 네트워크 위에 가상의 L2 네트워크를 얹는 Overlay 기술

VXLAN은 50byte 헤더(MAC over IP, UDP Header, 24bit VNI)를 추가로 구성하여 16,000,000개 이상의 가상 네트워크를 제공 가능

- **Overlay Network란?**
    - 물리적인 인프라를 기반으로 네트워크 가상화 기술을 사용하여 End-to-End 통신을 수행하는 기술
    - Tunnel 구성을 한다고 표현

| 특징 | 내용 |
| --- | --- |
| 정보 은닉 | 오버레이 기술을 사용하면 새로운 헤더가 추가되어 원본 IP 헤더를 감싸는 캡슐화가 수행됨. 새로운 헤더 정보를 이용하여 라우팅이 수행되기 때문에 원본 헤더는 외부에 노출되지 않음 |
| SDN 활용 | 오버레이 네트워크는 일반적으로 SDN을 이용하며 컨트롤러를 통해 트래픽 부하분산 수행 |
| 독립성 | 오버레이 네트워크의 구성 변경이 언더레이에 영향을 주지 않음. 반면 언더레이의 구성 변경은 오버레이에 영향을 줄 수 있음 |
| 높은 효율성 | Network Slicing과 Segmentation을 지원하여 네트워크를 분할하여 사용 가능 |
| 높은 보안성 | 암호화 알고리즘을 적용하여 End-to-End 통신에 높은 보안성 |

**L2 Network와의 차이점**

- L2 Network에서는 Broadcast를 이용하여 ARP 테이블을 수집하고, MAC address는 스위치에서 수집하여 관리
- 하지만 VXLAN은 VM들이 직접 ARP 테이블을 보유하고 vSwitch에서 테이블을 관리
- VXLAN에서 BUM 트래픽에 대해서 **IP Multicast**를 기반으로 전송
    - Multicast로 ARP 테이블을 갱신하고 직접 해당 스위치 쪽에 P2P Tunnel로 통신하는 방식

**VXLAN을 사용하는 이유**

- MAC Address Table의 한계
    - 가상화 환경이 생기면서 수많은 VM이 생성되는데, 이때 MAC 주소를 부여하면 MAC 주소가 기하급수적으로 늘어남
    - 이 많은 MAC 주소를 스위치의 MAC Table에 담으면 스위치의 처리 속도와 메모리에 엄청난 무리
    - 이를 해결하기 위해 VXLAN은 스위치에서 MAC 주소를 담당하지 않고 가상 스위치에서 MAC 주소를 담당하게 함
- 유연성
    - VLAN에서는 서로 간의 통신을 위해 VLAN Trunk를 구성하는데 이는 정적이고 변경에 빠르게 대처하기가 힘듦
    - VXLAN에서는 이러한 VLAN Trunk 없이 Multicast를 이용하여 Tree를 구성해 통신을 진행하기 때문에 동적이고 유연한 구성이 가능

### vSwitch

vSwitch는 vNIC을 물리적 NIC에 연결하고, local 통신을 위해 vNIC을 다른 서버의 vNIC들과 연결

- Access Port (Untagged Port): 하나의 VLAN에 속한 포트, VLAN Tag 전달 X (Switch와 End device 연결)
- Trunk Port (Tagged Port): VLAN 정보를 넘겨 여러 VLAN이 한꺼번에 통신하도록 해주는 포트, VLAN Tag 전달 O
- Trunk Port로 들어온 VLAN을 vSwitch가 분류하여 해당 VLAN ID에 맞는 Access Port(Tag 떼고)로 전송

**vSwitch 종류**

- **단순 브리지형 (기본형)**: Linux Bridge가 대표적. 기본적인 L2 스위칭만 수행하는 단순하고 가벼운 가상 스위치
- **고급 기능형 (프로그래머블)**: Open vSwitch(OVS)가 대표적. 단순 스위칭을 넘어 VLAN, VXLAN 캡슐화, QoS, 트래픽 모니터링, 그리고 SDN 제어(OpenFlow)까지 지원. **OpenStack Neutron이 바로 이 OVS를 핵심 엔진으로 사용**

### NFV (Network Function Virtualization)

하드웨어 장비가 수행하던 네트워크 기능들을, 하드웨어에서 떼어내 범용 서버 위의 소프트웨어로 구현하는 기술 **(방화벽, LB, Router → Software (VM, Container)) - 장비 가상화**

### SDN (Software-Defined Networking)

네트워크의 제어부(Control Plane)와 데이터 전송부(Data Plane)를 분리하고, 제어부를 소프트웨어로 중앙 집중화하는 네트워크 아키텍처

### NFV vs SDN

- **SDN**: 네트워크를 보다 쉽게 제어 및 관리를 할 수 있도록 지원
- **NFV**: 네트워크를 보다 쉽게 구축하고 확장할 수 있는 소프트웨어이며, 상호 보완적인 관계

| 구분 | NFV | SDN |
| --- | --- | --- |
| 목적 | 네트워크 장비의 기능을 가상화하여 하드웨어 종속성을 줄이고 유연성 향상 | 제어부와 전송부를 분리하여 중앙에서 소프트웨어로 관리·제어 |
| 특징 | 소프트웨어 기반 솔루션의 구축 편의성과 확장 용이성 | 중앙화·원격화를 통한 네트워크 설정과 관리의 효율성 |
| 서비스 영역 | Router, Switch, Firewall, Gateway, CDN 등 | 클라우드 형태의 범용 네트워크 제어·관리 플랫폼 |
| 프로토콜 | 표준화 진행 중 | OpenFlow |

---

# Ch 3. Nova · Neutron 내부 구조 & 실습 기록

## Nova

```
사용자 요청 (REST + Token)
        │
        ▼
┌───────────────┐
│   nova-api    │  요청 수신, 토큰 검증
└───────┬───────┘
        │ RabbitMQ (RPC)
        ▼
┌───────────────┐
│nova-conductor │  DB 접근 중계
└───────┬───────┘
        ▼
┌───────────────┐
│nova-scheduler │  Filter/Weigh로 배치 노드 선택
└───────┬───────┘
        ▼
┌───────────────┐  API 호출   ┌─────────┐
│ nova-compute  │◀╌╌╌╌╌╌╌╌╌▶│ Glance  │ 이미지
└───────┬───────┘             ├─────────┤
        │                     │ Neutron │ 포트/IP
        │ virsh               ├─────────┤
        ▼                     │ Cinder  │ 볼륨
┌───────────────┐             └─────────┘
│    libvirt    │  하이퍼바이저 추상화 (VM XML 정의/제어)
└───────┬───────┘
        ▼
┌───────────────┐
│   QEMU/KVM    │  실제 VM 프로세스 실행
└───────────────┘

실선(│▼): Nova 내부 동기 흐름 / 점선(╌): 외부 서비스 연동
```

### VM 생성 흐름

**1) Nova 내부 컴포넌트 (동기 호출, 실선 화살표)**

요청이 순차적으로 흐릅니다:

- **nova-api**: 요청 수신 및 토큰 검증
- **nova-conductor**: DB 접근 중계 역할
- **nova-scheduler**: Filter/Weigh 알고리즘으로 VM을 배치할 노드 선택
- **nova-compute**: 실제 VM 생성 및 실행 담당

**2) 외부 서비스 연동 (비동기/API 호출, 점선 화살표)**

RabbitMQ(AMQP) 메시지 큐를 통해 다른 OpenStack 서비스와 통신합니다:

- **Glance**: VM 부팅용 이미지 다운로드
- **Neutron**: 네트워크 포트 생성
- **Cinder**: 루트 볼륨(스토리지) 요청

**3) 하이퍼바이저 계층**

nova-compute가 VM 생성을 결정하면:

- **libvirt**: `virsh define`, `virsh start` 명령으로 VM XML을 정의하고 제어하는 하이퍼바이저 추상화 계층
- **QEMU/KVM**: `qemu-system-x86_64 -enable-kvm` 명령으로 실제 VM 실행
    - QEMU는 VM 프로세스 실행 및 에뮬레이션
    - KVM은 CPU 하드웨어 가상화 위임

**RabbitMQ란?**

**메시지 큐**(Message Queue)를 통해 여러 애플리케이션에 데이터를 주고받을 수 있도록 해주기 위한 **AMQP**의 오픈소스 메시지 브로커

**AMQP**: Advanced Message Queuing Protocol의 약자로 생산자(Producer)와 소비자(Consumer) 사이에서 메시지를 안전하게 교환하는 메시지 지향 미들웨어 개방형 프로토콜

- Producer: 메시지를 발행하는 생산자
- Exchange: 생산자가 발행한 메시지를 보관하고 있다가 알맞은 큐에 전달하는 매개체
- Queue: 생산자가 발행한 메시지를 보관하고 있다가 소비자가 소비할 때 전달
- Consumer: 생산자가 발행한 메시지를 구독하고 사용하는 소비자
- Binding: Exchange가 알맞은 큐에 메시지를 라우팅할 때 규칙을 지정하는 행위. Exchange의 종류에 따라 지정하는 방식이 달라짐

**libvirt란?**

virtualization platform을 관리하기 위한 도구로, QEMU-KVM, Xen, VMware 등 다양한 hypervisor를 작동시키기 위한 통합 API

- KVM, QEMU, Xen, VMware, Hyper-V 등 다양한 하이퍼바이저 지원
- 가상 머신의 생성, 삭제, 스냅샷, 마이그레이션 등 다양한 기능 제공
- virsh, virt-manager, libvirt API 등을 활용한 관리 가능

## Neutron

### Neutron + OVS (Open vSwitch) - 전통적 방식

```
[Control Plane]
┌────────────────┐    ┌────────────────────┐    ┌──────────┐
│ neutron-server │──▶│    ML2 plugin      │──▶│ RabbitMQ │
│ REST, 논리 DB  │    │ driver:openvswitch │    │   RPC    │
└────────────────┘    └────────────────────┘    └────┬─────┘
                                                     │ RPC push
[Data Plane: 각 compute/network 노드]                ▼
┌──────────────────────────────────────────────────────────┐
│ ┌───────────────┐  ┌────────────┐  ┌────────────┐        │
│ │  ovs-agent    │  │  l3-agent  │  │ dhcp-agent │        │
│ │ovs-vsctl/ofctl│  │qrouter netns│ │qdhcp+dnsmasq│       │
│ └───────┬───────┘  └─────┬──────┘  └─────┬──────┘        │
│         └────────────────┼───────────────┘               │
│                          ▼                               │
│  Open vSwitch ┌────────┐ ┌────────┐ ┌────────┐           │
│               │ br-int │ │ br-tun │ │ br-ex  │           │
│               └───┬────┘ └───┬────┘ └───┬────┘           │
│                   │          │          │                │
│                 [VMs]   VXLAN 터널   외부 네트워크       │
│                          (노드 간)   (Floating IP)       │
└──────────────────────────────────────────────────────────┘

특징: 노드마다 agent 상주, neutron-server가 RabbitMQ로 broadcast (명령형)
```

**Control Plane (제어 흐름)**

- **neutron-server**: REST API 수신, 논리 네트워크 DB 관리
- **ML2 plugin**: mechanism driver로 `openvswitch`를 사용
- **RabbitMQ**: RPC 메시지 큐로 명령을 각 노드에 전달

**Data Plane (compute/network 노드에서 실제 동작)**

- **neutron-ovs-agent**: 각 노드에 상주하면서 RabbitMQ로 RPC를 수신하고, OVS 흐름을 **직접** 설정
- **Open vSwitch 브릿지 3종**:
    - `br-int`: VM 포트 연결 (통합 브릿지)
    - `br-tun`: VXLAN 터널 (노드 간 오버레이 통신)
    - `br-ex`: 외부망 연결
- 각 브릿지에 `ovs-ofctl`, `ovs-vsctl` 명령으로 OpenFlow 룰을 직접 주입

**핵심 특징**: 모든 compute/network 노드마다 **agent가 상주**하면서 RPC를 받아 OVS를 명령줄 도구로 일일이 설정. neutron-server가 모든 변경사항을 RabbitMQ로 broadcast하는 구조.

### Neutron + OVN (Open Virtual Network) - 현대적 방식

```
┌────────────────┐   ┌────────────┐
│ neutron-server │──▶│ ML2 (ovn) │
└────────────────┘   └─────┬──────┘
                           ▼
              ┌─────────────────────────┐
              │     Northbound DB       │  논리: 스위치/라우터/ACL
              │ "이런 네트워크를 원해요"│  물리 위치 정보 없음 (선언적)
              └────────────┬────────────┘
                           ▼
              ┌─────────────────────────┐
              │       ovn-northd        │  논리 → Logical Flow 번역
              └────────────┬────────────┘
                           ▼
              ┌─────────────────────────┐
              │     Southbound DB       │  Logical Flow + Chassis
              │    + Port Binding       │  논리 포트 ↔ 물리 호스트 매핑
              └────────────┬────────────┘
             ┌─────────────┼─────────────┐  각 노드가 구독(watch)
             ▼             ▼             ▼
      ┌──────────────┐┌──────────────┐┌──────────────┐
      │ovn-controller││ovn-controller││ovn-controller│
      │  compute-1   ││  compute-2   ││  compute-3   │
      └──────┬───────┘└──────┬───────┘└──────┬───────┘
             ▼               ▼               ▼
          [ OVS ]═════════[ OVS ]═════════[ OVS ]
                  Geneve 터널 (UDP 6081)

특징: RabbitMQ 없음, 노드별 agent 없음 — DB 구독 기반 (선언형)
```

- **CMS**: 클라우드 상에서 가상 네트워크 서버에 대한 플러그인이라고 이해
- **OVN Northbound daemon/DB**: OVN에서는 가상 네트워크를 현대 물리 네트워크의 구조와 유사한 형태로 받아들인다. L3 스위치를 사용자가 요청하면, 이 논리적인 장비를 Northbound DB에 저장하는 식
- **OVN Southbound daemon/DB**: 언더레이 네트워크와 가상 네트워크를 잇는 부분. 논리적인 구조를 동작하게 하려면, 어떤 포트에 논리적인 장비가 연결되어 있는지와 같은 정보를 가지고 있을 필요가 있다
- **ovn-controller**: 각 장비에서 어떻게 데이터를 처리할지를 결정. 새로운 인터페이스가 감지되었다거나, 연결 상태들의 변화를 Southbound에 보고하는 역할도 진행
- **ovs-vswitchd/ovsdb-server**: OVN은 결국 OVS라는 블록을 사용해 추상화된 네트워크를 제공하는 프로젝트

**OVN의 Northbound/Southbound DB 분리**

분리 이유: “논리”와 “물리”를 분리하기 위해서

```
사용자 의도 (논리)
    ↓
[Northbound DB] ← "이런 네트워크를 원해요"
    ↓
[ovn-northd] ← 번역기
    ↓
[Southbound DB] ← "그럼 각 호스트는 이렇게 동작해야 해요"
    ↓
실제 호스트들 (물리)
```

**Northbound DB: “원하는 것”의 세계**

저장하는 것 (논리적, 추상적):

- Logical Switch: “프론트엔드 네트워크”
- Logical Router: “프론트엔드와 백엔드를 연결하는 라우터”
- Logical Switch Port: “VM1이 연결될 포트, IP는 10.0.0.5”
- ACL: “포트 80은 허용, 22는 거부”
- Load Balancer: “이 VIP는 이 백엔드들로 분산”

특징:

- **물리적 위치에 대한 정보가 전혀 없음**. VM이 어느 호스트에 있는지, 터널이 어떻게 뚫려야 하는지 모른다
- 사용자(Neutron)가 보는 추상화 수준
- 그래서 **선언적(declarative)**: “이렇게 됐으면 좋겠어”만 기술

**ovn-northd: 번역기**

Northbound DB의 논리 정의를 읽어서 **Logical Flow**라는 중간 표현으로 변환하고, Southbound DB에 쓴다.

핵심 작업: “이 논리 스위치에 포트가 3개 있다 → 그럼 MAC 학습 테이블은 이렇고, 브로드캐스트는 이렇게 처리하고, ACL은 이런 흐름으로…”

사용자가 만든 단순한 “스위치 + 포트 3개”가 실제로는 **수십 개의 OpenFlow 룰**로 펼쳐져야 하는데, ovn-northd가 그걸 자동으로 풀어준다. 이 시점까지도 **여전히 물리적 위치는 모른다**.

**Southbound DB: “어떻게 할지”의 세계**

저장하는 것:

1. **Logical Flow**: ovn-northd가 만든 추상 흐름 규칙
2. **Chassis**: 물리 호스트 목록 — 각 compute 노드가 자기 자신을 여기 등록
3. **Port Binding**: **논리 포트 ↔︎ 물리 호스트 매핑** — “VM1의 포트는 compute-3에 있어”. 이게 **연결고리**
4. **MAC Binding**: ARP 학습 결과 캐싱

특징:

- 논리와 물리가 **만나는 지점**
- 모든 ovn-controller가 이 DB를 구독함

**Data Plane (각 compute 노드)**

- **ovn-controller**: Southbound DB를 구독하다가 변경이 감지되면 OVS flows를 자동 주입
- **Open vSwitch**: 흐름 테이블을 실행 — 별도 agent 없이 자동

**핵심 특징**: RabbitMQ도 없고, neutron-ovs-agent도 없다. 대신 **DB 기반 pub/sub 모델**로 동작.

### Geneve (Generic Network Virtualization Encapsulation)

OVN에서 호스트 간 통신에 사용하는 터널 프로토콜

```
[VM-A: 10.0.0.5]              [VM-B: 10.0.0.6]
    ↓                              ↓
[compute-1: 192.168.1.11]    [compute-2: 192.168.1.12]
              ↑                   ↑
              └── 물리 네트워크 ──┘
```

VM-A와 VM-B는 같은 가상 네트워크(10.0.0.0/24)에 있다고 **믿고** 있다. 하지만 실제로는 서로 다른 물리 서버에 있고, 그 사이에는 물리 네트워크(192.168.1.0/24)가 있다.

문제: VM-A가 10.0.0.6으로 패킷을 보내면, 물리 네트워크 라우터는 “10.0.0.0/24가 어디 있는지 모르는데?” 한다. 물리 네트워크는 가상 네트워크의 존재조차 모른다.

**해결책: 캡슐화(Encapsulation)**. VM의 패킷을 통째로 물리 네트워크용 패킷 안에 **포장**해서 보낸다.

**1) VM이 만든 원본 패킷**

```
[Ether: src=VM-A_MAC, dst=VM-B_MAC]
[IP: src=10.0.0.5, dst=10.0.0.6]
[TCP/UDP/...: 페이로드]
```

**2) compute-1의 OVS가 Geneve로 캡슐화**

```
[Ether: src=compute-1_MAC, dst=compute-2_MAC]   ← 물리 이더넷
[IP: src=192.168.1.11, dst=192.168.1.12]        ← 물리 IP
[UDP: dst_port=6081]                             ← Geneve 표준 포트
[Geneve Header: VNI, options...]                 ← 가상 네트워크 식별자
[원본 패킷 전체가 여기 통째로 들어감]              ← payload
```

물리 네트워크는 바깥쪽 헤더만 보고 “compute-1 → compute-2” 일반 UDP 패킷이라고 생각하고 전달한다.

**3) compute-2의 OVS가 받아서 포장을 벗김**

- Geneve 헤더 확인 → “이건 VNI=5인 가상 네트워크 거구나”
- 안의 원본 패킷을 꺼냄 → VNI 5에 속한 로컬 VM(VM-B)에게 전달

VM-B는 자기가 받은 게 캡슐화돼서 왔다는 걸 **전혀 모른다**.

**Geneve vs VXLAN: 왜 OVN은 Geneve를 쓰나?**

- VXLAN의 한계: 헤더가 **고정 크기**. VNI 24비트 + 약간의 예약 필드, 끝. 추가 정보를 실을 공간이 없음
- Geneve의 강점: **Variable Length Options**. 헤더에 임의의 메타데이터를 붙일 수 있고, OVN은 논리 입력 포트/논리 출력 포트를 여기 실음 → 받는 쪽 ovn-controller가 **이 패킷이 어떤 논리 흐름의 일부인지 즉시 알 수 있음**

**Geneve vs VXLAN vs GRE 비교표**

| 항목 | GRE | VXLAN | Geneve |
| --- | --- | --- | --- |
| 전송 프로토콜 | IP 위 직접 | UDP (4789) | UDP (6081) |
| VNI 크기 | 32비트 (Key) | 24비트 | 24비트 |
| 헤더 크기 | 4~8바이트 | 8바이트 고정 | 8바이트 + 가변 옵션 |
| 확장성 | 거의 없음 | 없음 | 우수 (옵션) |
| 하드웨어 오프로드 | 광범위 | 광범위 | 점차 확대 중 |
| OVN 사용 | ❌ | 가능하지만 비권장 | ✅ 기본 |
| 표준화 | RFC 2784 | RFC 7348 | RFC 8926 |

**OVS 방식 vs OVN 방식 비교**

| 구분 | OVS 방식 | OVN 방식 |
| --- | --- | --- |
| 통신 방식 | RabbitMQ RPC (push) | DB 구독 (pull/watch) |
| 노드별 에이전트 | neutron-ovs-agent 필요 | ovn-controller만 (경량) |
| L3 라우팅 | 별도 l3-agent 필요 | OVN 내장 (분산 라우팅) |
| 상태 모델 | 명령형 (각 노드에 명령 전달) | 선언형 (원하는 상태 정의 → 알아서 수렴) |
| 확장성 | RabbitMQ 병목 가능 | DB 기반이라 더 잘 확장됨 |

> 참고: 우리 스터디는 OVS 방식(`neutron_plugin_agent: "openvswitch"`)을 사용한다. 6회차의 netns 실습(qrouter 네임스페이스 직접 관찰)이 OVS 방식에서만 가능하기 때문.
> 

## VLAN 기반 Network 격리 (설계)

```
              ┌─────────────────────┐
              │  Router (Mikrotik)  │  VLAN 6종 정의
              └──────────┬──────────┘
                         │ Trunk (모든 VLAN 태그 통과)
              ┌──────────┴──────────┐
              │       Switch        │
              └───┬───────┬───────┬─┘
                  │       │       └───────┐   각 노드에 필요한 VLAN만 전달
        ┌─────────▼──┐ ┌──▼───────────┐ ┌─▼──────────┐
        │  control   │ │   compute    │ │  storage   │
        ├────────────┤ ├──────────────┤ ├────────────┤
        │ Node Mgmt  │ │ Node Mgmt    │ │ Node Mgmt  │
        │ Service    │ │ Virtual NW   │ │ Storage    │
        │  Mgmt      │ │ Provider     │ │ Service    │
        │            │ │ External     │ │  Mgmt      │
        └────────────┘ └──────────────┘ └────────────┘

VLAN 6종: Node Mgmt / Service Mgmt / Storage / Virtual Network / Provider / External
```

프로덕션 OpenStack에서는 트래픽 종류별로 VLAN을 분리한다. 6개 VLAN 정의:

| VLAN | 용도 |
| --- | --- |
| Node Mgmt VLAN | 노드 자체 관리 (SSH, 모니터링 등 호스트 OS 접근) |
| Service Mgmt VLAN | OpenStack 서비스 간 통신 (API 호출, RabbitMQ 등) |
| Storage VLAN | 스토리지 트래픽 (Cinder 볼륨, Ceph 등) |
| Virtual Network VLAN | 테넌트 VM 간 통신 (Geneve/VXLAN 오버레이가 여기 실림) |
| Provider VLAN | 물리 네트워크와 직접 연결되는 프로바이더 네트워크 |
| External VLAN | 외부 인터넷 연결 (Floating IP, 외부 게이트웨이) |

각 노드로 가는 VLAN 역할:

- **compute**: VM을 돌리니까 Virtual Network, Provider, External 등 대부분 필요
- **control**: API/서비스 관리가 핵심이니 Service Mgmt, Node Mgmt 위주
- **storage**: Storage VLAN이 핵심

## Ceph

오픈소스 분산 스토리지 플랫폼으로 단일 분산 컴퓨터 클러스터에 오브젝트 스토리지를 구현하고 object, block 및 file level의 스토리지 기능을 제공

- **MON (Ceph Monitor)**
    - 클러스터의 결정적 상태 정보를 관리하는 역할, 클러스터 맵의 마스터 복사본을 유지
    - 높은 일관성이 필요하며, 상태에 대한 합의를 보장하기 위해 `Paxos` 알고리즘 사용
- **OSD (Object Storage Daemon)**
    - 실제 데이터 object가 저장되는 노드
    - data replication, erasure coding, rebalancing, recovery, monitoring 기능을 수행
- **MDS (Metadata Server)**
    - CephFS에 저장된 파일과 관련된 메타데이터를 저장 및 관리
- **MGR (Ceph Manager)**
    - 실시간 운영 데이터를 수집하는 역할과 Monitor의 부하를 줄여주는 역할

#### Ceph Interface

- **RGW (RADOS Gateway)**: RESTful 게이트웨이를 제공하는 **Object Storage Interface** (S3 호환)
- **RBD (RADOS Block Device)**: RADOS 상에 block device image를 만들 수 있도록 제공. **클라우드 상 가상머신의 image로 활용** — Cinder/Glance 백엔드
- **CephFS**: POSIX와 호환되는 **File Storage Interface**. 메타데이터는 MDS에서 관리

#### 파일 저장 방식

- Data Write

```
사용자가 파일 하나를 Ceph에 저장
    ↓
Ceph가 자동으로 파일을 여러 object들로 나눈다 (각 object에 ID 부여)
    ↓
객체 저장을 위해 만든 논리적인 파티션인 Pool에 object들을 넣는다
    ↓
object ID 기반으로 각 object는 PG에 할당 (CRUSH 알고리즘으로 해당 PG가 어떤 OSD들에 저장되는지 계산)
    ↓
모든 object를 여러 OSD에 중복 저장 후 사용자에게 object ID 전달
```

- Data Read

```
사용자가 파일을 읽고자 한다
    ↓
object ID를 이용해 직접 <PG정보 + CRUSH 알고리즘>으로 어떤 OSD에 저장되어 있는지 계산
    ↓
해당 OSD에 데이터를 직접 요청
```

→ “어디 저장할지 물어볼 중앙 서버가 없어도 클라이언트가 스스로 계산” — Ceph 확장성의 핵심

---

# Ch 4. Kolla-Ansible 배포 절차 (가비아 VM · ML2/OVS)

> 우리 스터디의 배포 방식. 5회차(배포)와 6회차(인스턴스·네트워크 실습)가 이 절차를 따름.
이 구성은 스터디장이 SU-Cloud 운영계를 Kolla-Ansible로 구축하며 검증한 설계를 가비아 VM 환경 + OVS 백엔드로 옮긴 것.
> 

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

```
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

- `ExecStartPre=-`의 는 "이미 없어도 실패로 치지 않음" — 재실행 멱등 처리
- **`veth0 master <브리지>` 류의 줄을 절대 넣지 않음** (§2의 미부착 원칙)

### Step 3 — Kolla-Ansible 설치 + 설정 파일 3종

```bash
python3 -m venv ~/kolla-venv && source ~/kolla-venv/bin/activate
pip install -U pip
pip install docker
pip install dbus-python
pip install "ansible-core==2.19.11"
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

kolla-ansible prechecks   -i /etc/kolla/all-in-one --use-test-images   # 이 플래그는 prechecks 전용 (pull/deploy에 붙이면 에러)
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

```
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

> Step 2의 veth-setup은 스터디의 `setup.sh`가, Step 6의 br-ex-gw(+NAT)와 Step 7의 리소스 생성은 `init.sh`가 담당함. 재부팅 후 네트워크가 살아 있는 이유가 이 두 유닛임.
> 

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
- `-dns-nameserver` 미지정 시 인스턴스가 도메인 해석 불가함

```bash
# 이미지 (CirrOS ~20MB) · 플레이버 · 키페어 · 보안그룹
wget https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img
openstack image create "cirros" \
  --file cirros-0.6.3-x86_64-disk.img \
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