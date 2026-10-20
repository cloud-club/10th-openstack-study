# Week 02 — OpenStack 아키텍처

> OpenStack은 데이터센터의 컴퓨팅, 스토리지, 네트워크 자원을 하나의 풀로 묶고, 공통 인증을 거친 API로 사용자에게 제공하는 오픈소스 IaaS 플랫폼이다.

## 1. OpenStack이란?

일반 운영체제가 한 컴퓨터의 CPU, 메모리, 디스크를 여러 프로세스에 나눠 준다면, OpenStack은 여러 서버의 자원을 데이터센터 단위로 묶어 여러 사용자에게 나눠 준다. 이런 의미에서 OpenStack을 **클라우드 운영체제**라고 부른다.

- **IaaS**: 서버, 스토리지, 네트워크 같은 인프라를 서비스로 제공하는 방식
- **프로비저닝**: 필요한 자원을 준비해 실제로 사용할 수 있는 상태로 만드는 것
- **API 중심 구조**: Horizon, CLI, SDK 중 무엇을 사용하더라도 최종적으로는 각 서비스의 REST API를 호출함
- **공통 인증**: 모든 API 요청은 Keystone에서 발급한 토큰을 사용함

이번 실습에서는 가비아 VM 한 대에 OpenStack 2026.1 **Gazpacho**를 all-in-one 형태로 배포한다.

## 2. 핵심 컴포넌트

OpenStack은 하나의 거대한 프로그램이 아니라, 역할이 분리된 여러 서비스의 집합이다.

| 컴포넌트 | 역할 |
| --- | --- |
| **Keystone** | 사용자, 프로젝트, 역할 관리와 인증 토큰 발급 |
| **Nova** | VM 생성, 배치, 중지, 삭제 등 생명주기 관리 |
| **Neutron** | 가상 네트워크, 서브넷, 라우터, IP, 방화벽 관리 |
| **Glance** | VM 부팅에 사용할 OS 이미지 관리 |
| **Cinder** | VM에 연결하는 영속적인 블록 볼륨 관리 |
| **Horizon** | OpenStack을 조작하는 웹 대시보드 |
| **Placement** | 컴퓨트 노드의 CPU, 메모리, 디스크 자원 현황 관리 |

Nova가 VM의 생명주기를 관리하지만 VM을 직접 실행하는 것은 아니다. Nova가 배치할 서버를 결정하고, 마지막에는 하이퍼바이저가 실제 VM 프로세스를 실행한다.

## 3. 서비스의 통신 방식

OpenStack은 통신 상황에 따라 REST API와 메시지 큐를 나눠 사용한다.

- 서로 다른 서비스 간 통신: **REST API**  
  예: Nova가 Glance에 이미지를 요청하거나 Neutron에 포트 생성을 요청
- 같은 서비스의 내부 프로세스 간 통신: **RabbitMQ를 이용한 RPC**  
  예: Nova의 API, Scheduler, Conductor, Compute 사이의 업무 전달

RabbitMQ의 기본 흐름은 다음과 같다.

```text
Producer → Exchange → Binding → Queue → Consumer
```

## 4. Nova 내부 구조와 VM 생성 과정

### Nova의 주요 프로세스

| 프로세스 | 역할 |
| --- | --- |
| **nova-api** | REST 요청 접수 및 토큰 검증 |
| **nova-scheduler** | VM을 실행할 컴퓨트 노드 선택 |
| **nova-conductor** | nova-compute와 DB 사이를 중계 |
| **nova-compute** | libvirt를 통해 하이퍼바이저에 VM 실행 요청 |

Scheduler는 먼저 조건을 만족하지 못하는 노드를 **Filter**로 제외하고, 남은 노드를 **Weigh**로 점수화해 최적의 노드를 고른다. 이때 Placement에서 각 노드의 남은 자원 정보를 가져온다.

Conductor가 DB 접근을 중계하는 이유는 수많은 컴퓨트 노드가 중앙 DB에 직접 연결할 때 생기는 보안 위험과 커넥션 증가를 줄이기 위해서다.

### 인스턴스 생성 흐름

```text
Horizon 또는 CLI
  → Keystone 인증과 토큰 발급
  → nova-api 요청 접수
  → Placement 자원 조회
  → nova-scheduler가 실행 노드 선택
  → nova-compute가 작업 수신
  → Glance 이미지 준비
  → Neutron 포트와 IP 준비
  → 필요하면 Cinder 볼륨 연결
  → libvirt → QEMU/KVM으로 VM 실행
```

요청을 접수하면 DB에 먼저 인스턴스 레코드가 생기고 상태가 `BUILD`로 표시된다. 이미지와 네트워크 등의 준비가 끝나 QEMU 프로세스가 실행되면 최종적으로 `ACTIVE` 상태가 된다. 따라서 Horizon에 항목이 보인다는 사실만으로 실제 VM 생성이 끝났다고 볼 수는 없다.

## 5. Neutron이 관리하는 네트워크 자원

| 자원 | 의미 |
| --- | --- |
| **Network** | VM을 연결하는 가상의 L2 스위치 |
| **Subnet** | 해당 네트워크에서 사용할 IP 주소 대역 |
| **Router** | 서로 다른 네트워크 또는 내부망과 외부망을 연결 |
| **Security Group** | 인스턴스 단위로 적용하는 가상 방화벽 규칙 |
| **Floating IP** | 외부에서 VM에 접근할 수 있도록 연결하는 외부 IP |

노드 사이의 API, DB, 메시지 큐 통신에는 Management Network를 사용하고, 외부 연결에는 Provider/External Network를 사용한다. 사용자가 만드는 격리된 가상망은 Self-Service 또는 Tenant Network라고 한다.

## 6. VM을 실제로 실행하는 계층

```text
nova-compute → libvirt → QEMU/KVM → 실제 VM 프로세스
```

- **libvirt**: 서로 다른 하이퍼바이저를 공통 인터페이스로 제어하게 해 주는 추상화 계층
- **KVM**: CPU의 하드웨어 가상화 기능을 사용하는 Linux 커널 모듈
- **QEMU**: VM 프로세스와 가상 장치를 실행하는 에뮬레이터

실습 환경은 이미 가상화된 가비아 VM 안에서 다시 OpenStack 인스턴스를 실행하므로 **VM 안의 VM**, 즉 중첩 가상화 구조이다.

```text
물리 서버
  └─ 가비아 Ubuntu VM
       └─ Docker 컨테이너로 배포된 OpenStack
            └─ OpenStack이 생성한 VM
```

외부 하이퍼바이저가 VT-x/AMD-V 기능을 내부 VM에 노출하지 않으면 KVM 가속을 사용할 수 없다. 이 경우 QEMU가 CPU까지 소프트웨어로 에뮬레이션하므로 인스턴스 부팅이 느려질 수 있다.

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

결과가 `0`이면 내부에서 하드웨어 가상화 기능을 인식하지 못한 것이다.

### 리소스 부족과 트러블슈팅

OpenStack의 컨트롤 플레인은 인스턴스를 만들지 않아도 많은 메모리를 사용한다. 메모리가 부족하면 Linux의 OOM Killer가 MariaDB나 QEMU 같은 중요한 프로세스를 종료할 수 있다.

따라서 인스턴스가 갑자기 꺼졌다는 증상만 보고 Nova 문제라고 단정하면 안 된다. `dmesg`와 각 서비스의 로그를 확인하면서 원인을 좁혀야 한다.

## 7. Kolla-Ansible의 역할

OpenStack은 구성 요소가 많아 각 서비스를 직접 설치하고 연결하기가 어렵다. **Kolla-Ansible은 각 OpenStack 서비스를 Docker 컨테이너로 배포하고, Ansible로 설정과 배포 과정을 자동화하는 도구**이다.

- 서비스와 컨테이너의 관계가 명확해 `docker ps`로 전체 구조를 확인하기 쉽다.
- 같은 배포 작업을 다시 실행해도 원하는 상태에 수렴하는 멱등성을 활용할 수 있다.
- 개발용 간이 설치 도구인 DevStack과 달리 실제 운영에 가까운 형태로 구성할 수 있다.
- 이번 실습에서는 Controller, Network, Storage, Compute 역할을 한 VM에 모은 all-in-one 구성을 만든다.

Kolla-Ansible 자체가 Nova나 Neutron처럼 클라우드 기능을 제공하는 서비스는 아니다. 여러 OpenStack 서비스를 **설치하고 설정하고 운영 가능한 상태로 만들어 주는 배포 도구**이다.

## 8. 이번 주에 이해한 핵심

- OpenStack은 하나의 프로그램이 아니라 독립된 서비스들이 API와 메시지 큐로 협력하는 구조이다.
- Keystone은 모든 API 요청에 필요한 토큰을 발급하고 검증하는 공통 관문이다.
- Nova는 VM을 관리하지만, 실제 실행은 `nova-compute → libvirt → QEMU/KVM` 계층에서 이루어진다.
- 수평 확장은 컴퓨트 노드를 더 추가하는 것이며, Scheduler가 Placement 정보를 바탕으로 작업을 분산한다.
- 장애를 볼 때는 증상만으로 특정 OpenStack 서비스를 의심하지 않고 DB, 메시지 큐, 메모리 및 로그까지 함께 확인해야 한다.

## 9. 예습 질문 답변

### 1. Nova, Neutron, Glance, Keystone을 AWS 서비스와 연결하고, Keystone이 모든 요청의 관문인 이유 설명하기

| OpenStack | AWS | 역할 |
| --- | --- | --- |
| **Nova** | EC2 | VM 생명주기 관리 |
| **Neutron** | VPC | 네트워크 관리 |
| **Glance** | AMI | 부팅 이미지 관리 |
| **Keystone** | IAM | 인증과 권한 관리 |

Keystone이 모든 요청의 관문인 이유는 모든 OpenStack API 요청에 Keystone이 발급한 토큰이 필요하기 때문이다.

```text
1. 클라이언트가 Keystone에 ID와 비밀번호를 제출한다.
2. Keystone이 토큰과 서비스 카탈로그를 발급한다.
3. 클라이언트가 X-Auth-Token을 담아 Nova API 등에 요청한다.
4. 요청을 받은 서비스가 토큰의 유효성과 권한을 확인한다.
5. 토큰이 유효할 때만 요청을 처리한다.
```

서비스 카탈로그에는 각 OpenStack 서비스의 API 주소가 들어 있다. Fernet 토큰은 사용자, 프로젝트, 만료 시각 등의 정보를 암호화해 담으며, 토큰 자체를 매번 DB에 저장하지 않는 무상태 방식이라 확장에 유리하다.

### 2. nova-api와 nova-compute가 REST 대신 메시지 큐를 사용하는 이유 세 가지

1. **비동기 처리**

   VM 생성은 수십 초 이상 걸릴 수 있다. nova-api는 작업을 큐에 넣고 바로 다음 요청을 받을 수 있으므로 작업이 끝날 때까지 묶이지 않는다.

2. **내결함성**

   nova-compute가 잠시 응답하지 못해도 메시지를 큐에 보관할 수 있어, 구성과 장애 상황에 따라 복구 후 다시 처리할 여지가 생긴다.

3. **수평 확장**

   서버 한 대의 사양만 높이는 것이 아니라 컴퓨트 노드를 여러 대로 늘릴 수 있다. 노드가 추가되어도 API 구조를 바꿀 필요가 없으며, Scheduler가 Placement의 자원 정보를 보고 적절한 노드를 선택한다. 이후 RabbitMQ가 선택된 노드의 nova-compute에 작업을 전달한다.

RabbitMQ가 VM을 임의의 노드에 배치하는 것은 아니다. **Scheduler가 배치를 결정하고 메시지 큐는 선택된 노드로 작업을 전달한다.**

### 3. MariaDB, RabbitMQ, Memcached의 역할과 장애 영향

| 구성 요소 | 역할 | 장애가 발생하면 |
| --- | --- | --- |
| **MariaDB** | 각 서비스의 상태와 설정을 영구 저장 | 제어 서비스가 상태를 읽고 쓸 수 없어 전반적인 API 처리가 마비될 수 있음 |
| **RabbitMQ** | 서비스 내부 프로세스 사이의 RPC 메시지 전달 | VM 생성과 삭제 등의 작업 전달이 중단됨 |
| **Memcached** | 토큰 검증 결과 등 자주 쓰는 데이터를 메모리에 캐싱 | 성능이 저하되고 일부 인증 요청이 일시적으로 실패할 수 있음 |

이 서비스에 장애가 생겨도 이미 실행 중인 VM 프로세스는 당장 계속 동작할 수 있다. 다만 OpenStack 제어 영역에서 VM을 조회하거나 새로 생성하고 변경하는 작업은 영향을 받는다.
