# OpenStack Architecture & Operations Standard Specification

- **Document Version:** 2026.1-GA
- **Target Release:** OpenStack 2026.1 "Gazpacho"
- **Status:** Official Concept & Operational Reference Guide

## 1. Overview & Core Philosophy

### 1.1. OpenStack Definition

OpenStack은 데이터센터 전반에 분산된 대규모의 컴퓨팅, 스토리지, 네트워킹 자원 풀(Pool)을 제어하고 프로비저닝하는 클라우드 운영체제(Cloud Operating System)이자 IaaS(Infrastructure as a Service) 오픈소스 플랫폼입니다.

- **클라우드 운영체제:** 단일 서버의 OS가 단일 시스템 내 자원을 관리하듯, OpenStack은 분산 데이터센터 환경의 이종 물리 자원을 단일 풀로 추상화하여 멀티테넌트(Multi-tenancy) 환경에 배분합니다.
- **프로비저닝(Provisioning):** API 요청에 의해 자원을 즉시 할당하고 실행 가능 상태로 자동화하여 배포하는 일련의 메커니즘을 의미합니다.
- **통합 REST API 인터페이스:** Web Dashboard(Horizon), CLI, 파이썬 SDK 등 모든 클라이언트 요청은 동일한 백엔드 REST API로 수렴하며, 모든 호출은 공통 인증 메커니즘(Keystone)을 통과합니다.

### 1.2. Release Engineering: 2026.1 "Gazpacho"

- **Release Versioning:** OpenStack은 6개월 주기(매년 4월, 10월)로 릴리스되며 `YYYY.X` 형식의 연도/차수 버전 정책과 알파벳 순 코드네임을 부여합니다.
- **Target Release Spec:** 본 문서가 기준으로 하는 **2026.1 "Gazpacho"** 버전은 33번째 공식 릴리스로, Kolla-Ansible `stable/2026.1` 브랜치 기반 배포를 표준으로 적용합니다.

## 2. Core Service Matrix & Mapping

OpenStack은 독립적인 서비스 프로세스들의 집합으로 구성되어 있으며, 각 서비스는 개별 API 엔드포인트와 분리된 데이터베이스를 보유합니다.

| **Service Name** | **Project Role** | **Default API Port** | **AWS Service Mapping** | **Core Functions** |
| --- | --- | --- | --- | --- |
| **Keystone** | Identity | `5000` | AWS IAM | 사용자 인증, 권한 부여(RBAC), 토큰 발급 및 엔드포인트 카탈로그 관리 |
| **Nova** | Compute | `8774` | AWS EC2 | 가상머신(VM) 생명주기 관리(생성, 스케줄링, 중지, 삭제) |
| **Neutron** | Networking | `9696` | AWS VPC | L2/L3 가상 네트워크, 서브넷, 라우팅, 보안 그룹, Floating IP 관리 |
| **Glance** | Image | `9292` | AWS AMI | VM 부팅용 OS 디스크 이미지(qcow2 등) 저장 및 관리 |
| **Cinder** | Block Storage | `8776` | AWS EBS | VM에 연결되는 영속성 블록 스토리지 볼륨 관리 |
| **Horizon** | Dashboard | `80` / `443` | AWS Management Console | Django 기반의 관리자 및 사용자용 통합 웹 GUI |
| **Placement** | Resource Inventory | `8778` | N/A | 노드별 자원(CPU, Memory, Disk) 보유량 및 점유 상태 추적 장부 |

### Expanded Ecosystem Reference

기타 서비스 프로젝트(Swift, Octavia, Designate, Heat, Magnum, Trove, Ironic, Manila, Barbican 등) 역시 퍼블릭 클라우드의 주요 서비스 라인업과 1:1로 대칭되는 표준 프레임워크를 공유합니다.

## 3. Inter-Service Communication Architecture

OpenStack 인프라는 내부/외부 레이어에 따라 동기식 REST API 및 비동기식 메시지 큐 방식을 혼용하여 통신을 수행합니다.

```
┌──────────────────────────────────────────────────────────────────┐
│                      Client / Horizon / CLI                      │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ 1. Token Request (ID/PW)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                         Keystone (:5000)                         │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ 2. Issues Token & Service Catalog
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                       Client Application                         │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ 3. REST API + X-Auth-Token Header
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                        nova-api (:8774)                          │
└──────────────┬──────────────────────────────────┬────────────────┘
               │ 4. Token Validation Check        │ 6. AMQP Cast (RPC)
               ▼                                  ▼
┌────────────────────────────┐      ┌──────────────────────────────┐
│      Keystone (:5000)      │      │       RabbitMQ (AMQP)        │
└────────────────────────────┘      └──────────────┬───────────────┘
                                                   │
                                                   ▼
                                    ┌──────────────────────────────┐
                                    │         nova-compute         │
                                    └──────────────────────────────┘
```

### 3.1. Inter-Service Communication: REST API & Keystone Token

서비스 간 또는 클라이언트-서비스 간 요청은 HTTP/REST API 프로토콜을 사용하며, 요청 헤더의 `X-Auth-Token`으로 인가를 확인합니다.

1. **Authentication:** 클라이언트가 Keystone에 Credentials를 제출하여 인증을 요청합니다.
2. **Issue Token & Catalog:** Keystone은 인증 성공 시 **Fernet Token**과 서비스별 접속 주소가 명시된 **Service Catalog**를 반환합니다.
3. **API Invocation:** 클라이언트는 Catalog의 Endpoint URL로 API 요청을 보내며 헤더에 Token을 동반합니다.
4. **Validation:** API 수신 서비스(e.g., `nova-api`)는 Keystone에 해당 Token의 유효성 검증을 요청합니다.
5. **Execution:** Token 검증 승인 후 해당 요청을 처리합니다.

#### Technical Deep Dive: Fernet Token Architecture

Keystone의 기본 토큰 메커니즘인 **Fernet Token**은 무상태성(Stateless) 구조입니다. 토큰 자체에 사용자 ID, Scope, 만료 시간 등의 메타데이터가 대칭키로 암호화되어 내장되어 있습니다. 검증 시 DB 조회가 필요 없이 대칭키 복호화만으로 유효성을 증명하므로, DB I/O 병목을 제거하고 높은 확장성을 보장합니다.

### 3.2. Intra-Service Communication: Message Queue (RabbitMQ AMQP)

동일 서비스 내부 구성요소 간(e.g., `nova-api` $\leftrightarrow$ `nova-scheduler` $\leftrightarrow$ `nova-compute`) 통신은 RabbitMQ 기반의 AMQP(Advanced Message Queuing Protocol) 버스를 통한 RPC(Remote Procedure Call)로 이루어집니다.

- **AMQP Message Flow:** `Producer` $\rightarrow$ `Exchange` $\rightarrow$ (`Binding Rules`) $\rightarrow$ `Queue` $\rightarrow$ `Consumer`
- **RPC Direct Invocations:**
    - `call`: 응답을 대기하는 동기식(Synchronous) 요청.
    - `cast`: 응답을 기다리지 않고 즉시 반환하는 비동기식(Asynchronous) 요청 (VM 생성 등 장시간 실행 작업에 적용).
- **Message Queue 도입 이점:**
    - **Asynchronous Decoupling:** Long-running 작업 처리 중 API Worker가 차단(Block)되지 않음.
    - **Fault Tolerance:** 수신자(Compute Node) 일시 장애 시에도 메시지는 Queue에 유실 없이 보존됨.
    - **Horizontal Scalability:** Queue를 수신하는 Worker 노드를 증설하는 것만으로 자동으로 작업 부하가 분산됨.

### 3.3. Mandatory Infrastructure Dependencies

OpenStack 컨트롤 플레인 구동을 위한 제3자 공통 인프라 컴포넌트는 다음과 같습니다.

```
+--------------------------------------------------------------------------+
|                       Common Infrastructure Services                     |
+--------------------+--------------------+--------------------------------+
| Mariadb            | RabbitMQ           | Memcached                      |
| [State Storage]    | [Internal RPC Bus] | [Token Validation Caching]     |
+--------------------+--------------------+--------------------------------+
```

- **MariaDB:** 서비스별 영속 데이터 저장소 (`nova`, `neutron`, `keystone` 등 독립 DB 구동). (장애 시: 서비스 상태 기록 불가 및 클러스터전체 마비)
- **RabbitMQ:** 서비스 내부 구성요소 간 RPC 메시지 전달 버스. (장애 시: 서비스 간 작업 명령 및 제어 불가능)
- **Memcached:** Keystone 토큰 검증 결과 및 DB 쿼리 결과 메모리 캐싱. (장애 시: 매 요청마다 Keystone/DB 접근이 발생하여 극심한 성능 저하 발생)
- **HAProxy (Multi-Node):** 컨트롤러 노드 전면의 API Endpoints VIP 로드밸런싱 및 리버스 프록시.

## 4. Deep Dive: Compute Subsystem (Nova & Hypervisor)

### 4.1. Nova Internal Microservices

Nova는 기능별로 분리된 4개의 독립 Daemon 프로세스로 작동합니다.

```
┌──────────────┐     REST/Token     ┌──────────────┐
│  nova-api    ├───────────────────►│   Keystone   │
└──────┬───────┘                    └──────────────┘
       │ AMQP (cast)
       ▼
┌──────────────┐     Inventory      ┌──────────────┐
│nova-scheduler├───────────────────►│  Placement   │
└──────┬───────┘                    └──────────────┘
       │ AMQP (cast)
       ▼
┌──────────────┐     RPC Request    ┌──────────────┐     DB I/O     ┌──────────────┐
│ nova-compute ├───────────────────►│nova-conductor├───────────────►│ MariaDB (Nova)│
└──────┬───────┘                    └──────────────┘                └──────────────┘
       │ Driver Call
       ▼
┌──────────────┐     libvirt API    ┌──────────────┐     Hardware   ┌──────────────┐
│   libvirt    ├───────────────────►│  QEMU/KVM    ├───────────────►│  Host CPU    │
└──────────────┘                    └──────────────┘                └──────────────┘
```

1. **`nova-api`:** 사용자 REST 요청 접수, 입력값 검증, Keystone 토큰 검증 제어.
2. **`nova-scheduler`:** Placement 서비스로부터 컴퓨팅 자원 인벤토리를 수신 후, **Filter**(조건 미달 노드 제거) $\rightarrow$ **Weigh**(우선순위 점수 산출) 2단계 알고리즘을 거쳐 최적의 Compute Host를 선정.
3. **`nova-conductor`:** DB Access Proxy. `nova-compute` 노드가 중앙 DB에 직접 접근하는 것을 차단하여 보안성 증대 및 커넥션 폭증 방지.
4. **`nova-compute`:** 하이퍼바이저 제어 모듈. VM 생성을 직접 수행하지 않고, 하이퍼바이저 드라이버를 호출하여 VM provisioning을 지시.

### 4.2. Hypervisor Layer & Virtualization Stack

`nova-compute`에서 실제 물리 VM 프로세스 실행까지의 추상화 계층은 다음과 같습니다.

```
nova-compute ──► libvirt (Virtualization API) ──► QEMU/KVM ──► Guest Instance Process
```

- **libvirt:** KVM, Xen, VMware 등 이종 하이퍼바이저 제어를 표준화된 XML 사양 및 API로 추상화한 관리 인터페이스 (CLI: `virsh`).
- **KVM (Kernel-based Virtual Machine):** 리눅스 커널 모듈로, Intel VT-x / AMD-V 등의 하드웨어 가상화 기술을 사용하여 CPU/Memory 가상화를 가속.
- **QEMU:** 가상화 에뮬레이터. KVM과 결합 시 CPU 외의 I/O Device(디스크, NIC 등)에 대한 에뮬레이션을 담당.

### 4.3. Nested Virtualization & Hardware Acceleration Context

가상화 환경(e.g., Cloud VM) 내부에 OpenStack을 배포하여 인스턴스를 생성하는 구조를 중첩 가상화(Nested Virtualization)라고 합니다.

```
[ Physical Baremetal Host ]
   └── [ Hypervisor / Guest VM ] (Hypervisor Node)
        └── [ OpenStack Docker Containers ]
             └── [ QEMU / Guest Instance ] (Inner Instance)
```

- **하드웨어 가속 검증 명령:**Bash
    
    ```
    egrep -c '(vmx|svm)' /proc/cpuinfo
    ```
    
    - **결과 값 $\ge$ 1:** 하드웨어 가속(KVM) 활성화 상태.
    - **결과 값 0:** 하드웨어 가속 미지원 상태. QEMU가 CPU 명령어를 **순수 소프트웨어 에뮬레이션** 모드로 처리하므로, VM 부팅 및 I/O 동작 속도가 현저히 저하됩니다.

### 4.4. Memory Architecture & Out-Of-Memory (OOM) Analysis

OpenStack Control Plane(서비스 API, MariaDB, RabbitMQ, Memcached 등)은 인스턴스 미배포 상태에서도 상당량의 기본 RAM을 점유합니다.

- **Sizing Constraint:** 컨트롤 노드의 최소 메모리 스펙은 **16GB 이상**을 필수 권장합니다.
- **OOM Killer Failure Scenario:**Plaintext
    
    메모리 고갈 발생 시 Linux Kernel OOM Killer 알고리즘은 `badness` 점수가 가장 높은 프로세스를 강제 종료(`SIGKILL`)시킵니다.
    
    ```
    Kernel Message: Out of memory: Killed process (mysqld)
    Kernel Message: Out of memory: Killed process (qemu-system-x86)
    ```
    
    - **분석 원칙:** 인스턴스가 비정상 종료된 경우 Nova 서비스 내부 문제로 단정짓지 않고, `dmesg` 및 시스템 커널 로그를 통해 OOM에 의한 `mysqld` 또는 `qemu-system-x86` 프로세스 강제 종료 여부를 최우선으로 검증해야 합니다.

## 5. Executive Verification & Assessment (Quiz)

### Q1. Core Component Mapping & Keystone Flow

**Question:** Nova, Neutron, Glance, Keystone을 AWS의 대응 서비스(EC2, VPC, AMI, IAM)와 짝지어 설명하고, Keystone이 "모든 요청의 관문"이라 불리는 이유를 토큰 검증 5단계 흐름으로 제시하시오.

- **Solution:**
    - **Service Mapping:** Nova $\rightarrow$ AWS EC2, Neutron $\rightarrow$ AWS VPC, Glance $\rightarrow$ AWS AMI, Keystone $\rightarrow$ AWS IAM.
    - **Keystone Token Verification Flow:**
        1. **Credentials Submission:** Client $\rightarrow$ Keystone (`POST /v3/auth/tokens`) 인증 요청.
        2. **Token & Catalog Return:** Keystone $\rightarrow$ Client (Fernet Token 및 Service Catalog 발급).
        3. **Target Service Invocation:** Client $\rightarrow$ Target API (Token 헤더 포함 요청).
        4. **Token Validation Check:** Target Service $\rightarrow$ Keystone (토큰 유효성/권한 검증).
        5. **Execution Authorization:** Keystone 승인 시 Target Service에서 명령 최종 실행.

### Q2. Inter-process Communication Rationale

**Question:** `nova-api`와 `nova-compute` 간 통신 시 REST API 대신 Message Queue(RabbitMQ)를 채택한 기술적 이유 3가지를 설명하시오.

- **Solution:**
    1. **비동기 처리(Asynchronous / Non-blocking):** VM 생성 등 수십 초 이상 소요되는 장시간 작업 처리 시 `nova-api`가 대기 상태에 빠지지 않고 즉시 추가 API 요청을 처리할 수 있음.
    2. **내결함성 보장(Fault Tolerance):** `nova-compute` 노드 장애 또는 네트워크 단절 시에도 생성 메시지가 Queue에 보존되어 복구 후 정상 처리 가능.
    3. **수평적 확장성(Horizontal Scalability):** Queue를 수신하는 Compute Node(Worker)를 무중단으로 확장하면 부하가 메시지 큐에 의해 자동으로 분산됨.

### Q3. Infrastructure Dependencies & Impact Analysis

**Question:** MariaDB, RabbitMQ, Memcached의 개별 역할을 정의하고, 서비스 중 하나가 Down 되었을 때 시스템에 미치는 영향을 기술하시오.

- **Solution:**
    - **MariaDB:**
        - *역할:* OpenStack 서비스들의 영속 메타데이터 저장.
        - *장애 영향:* 상태 조회 및 신규 자원 생성 등 데이터베이스 I/O를 수반하는 모든 OpenStack API의 동작이 완전히 정지됨(기억상실/클러스터 마비).
    - **RabbitMQ:**
        - *역할:* 동일 서비스 구성 요소 간 AMQP RPC 통신 버스.
        - *장애 영향:* API 노드가 Compute/Network 제어 노드로 명령을 전달하지 못해 VM 생성, 삭제 등 제어 작업 실행 불가.
    - **Memcached:**
        - *역할:* Keystone 토큰 검증 데이터 및 DB Query 결과의 In-Memory 캐싱.
        - *장애 영향:* 모든 API 호출마다 Keystone/MariaDB로의 직접 인증 조회가 발생하여 시스템 전체 API 응답 속도 및 Latency가 급격히 저하됨.

## 예습 질문에 대한 답변

1. Nova/Neutron/Glance/Keystone을 EC2/VPC/AMI/IAM과 짝지어 보세요. Keystone만 “모든 요청의 관문”이라 부르는 이유를 토큰 검증 흐름(5단계)으로 설명하면?
    - Nova - EC2
    - Neutron - VPC
    - Glance - AMI
    - Keystone - IAM
    - Keystone이 모든 오픈스택 환경을 사용하기 위한 SSO로 작용하기 때문.
        - Keystone을 활용하여 RBAC와 멀티테넌시를 구현 가능
2. nova-api와 nova-compute는 왜 REST가 아니라 메시지 큐로 통신할까요? 이유 3가지.
    - 비동기
        - 메시지를 던지고 즉시 다음 요청을 받을 수 있음
    - 내결함성
        - compute가 잠깐 죽어도 메시지는 큐에 남아 있다가 복구 후 처리됨
    - 수평 확장
        - 같은 큐를 구독하는 compute 노드를 늘리면 작업이 자동으로 분산됨
3. `docker ps`에 뜨는 mariadb, rabbitmq, memcached는 OpenStack 프로젝트가 아닙니다. 각각 무슨 역할이고, 이 중 하나가 죽으면 어떤 일이 벌어질까요?
    - MariaDB
        - 모든 서비스의 데이터 저장소.
        - VM의 생성, 삭제, 변경 등의 모든 기록을 저장
        - 만약 DB가 내려가게 되면, 모든 서비스 장애. (이중화 및 DR 구성 필요)
    - RabbitMQ
        - 서비스 내부 RPC 버스
        - 내려가게 되면, 컴포넌트 간의 통신이 안됨. 서비스 장애
    - Memcached
        - 토큰 검증 결과 등을 메모리에 캐싱.
        - 매 요청마다 Keystone까지 왕복하는 비용 절약
        - 내려가게 되면, 서비스 장애 까진 나지 않지만, 성능에 저하가 있음
