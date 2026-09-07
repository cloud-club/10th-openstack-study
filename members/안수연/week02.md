# OpenStack 기본 구조 및 VM 생성 흐름

## 1. OpenStack이란?

> **OpenStack은 데이터센터의 Compute · Storage · Network 자원을 하나의 Resource Pool로 관리하고, API를 통해 사용자에게 제공하는 오픈소스 IaaS 플랫폼임.**

일반적인 OS가 한 대의 서버 안에서 CPU · Memory · Disk를 여러 프로세스에 나눠준다면, OpenStack은 같은 역할을 **데이터센터 규모**에서 수행함.

즉, 여러 대의 물리 서버가 가지고 있는 자원을 하나의 거대한 Resource Pool처럼 관리하고 필요한 사용자에게 VM · Network · Storage 형태로 제공함.

### 일반 OS와 OpenStack의 차이

[일반 OS]

CPU / Memory / Disk
        ↓
      Linux
        ↓
   Application


[OpenStack]

Compute / Storage / Network
             ↓
         OpenStack
             ↓
     VM / Volume / Network
   
따라서 OpenStack을 **Cloud Operating System**이라고도 표현함.

AWS와 같은 Public Cloud를 사용하는 것이 아니라, 직접 보유한 서버에 AWS와 유사한 IaaS 환경을 구축할 수 있도록 해주는 플랫폼이라고 이해하면 됨.

## 2. Provisioning

> **Provisioning이란 필요한 IT 자원을 준비하여 실제 사용할 수 있는 상태로 만드는 과정임.**

예를 들어 AWS에서 EC2 Instance를 생성하면 다음 과정이 자동으로 수행됨.

```
VM 생성 요청
    ↓
Compute Resource 할당
    ↓
Network 연결
    ↓
OS Image 적용
    ↓
VM 생성
    ↓
사용 가능한 상태
```

OpenStack 역시 사용자가 VM 생성을 요청하면 Compute · Network · Image · Storage Service가 협력하여 Instance를 Provisioning함.

---

## 3. OpenStack의 API 기반 구조

OpenStack에서 발생하는 대부분의 Resource 관리 작업은 API를 기반으로 이루어짐.

사용자가 어떤 Interface를 사용하느냐만 다를 뿐, 최종적으로 OpenStack Service의 REST API를 호출함.

```
Horizon
   │
CLI
   │
SDK
   │
   ▼
REST API
   │
   ▼
OpenStack Services
```

예를 들어 다음 명령을 실행하면,

```
openstack server list
```

내부적으로 Nova API에 다음과 같은 요청이 전달됨.

```
GET /v2.1/servers
X-Auth-Token: <TOKEN>
```

즉,

> **Horizon · CLI · SDK는 서로 다른 기능을 수행하는 것이 아니라 동일한 OpenStack API를 사용하는 서로 다른 Client임.**

---

# 4. OpenStack Architecture


OpenStack은 하나의 거대한 프로그램이 아니라 **각 역할을 담당하는 독립적인 Service들의 집합**임.

각 Service는 API를 제공하며 서로 협력하여 하나의 Cloud Platform처럼 동작함.

## 핵심 Component

| Component     | 역할                         | AWS 대응  |
| ------------- | -------------------------- | ------- |
| **Keystone**  | 인증 · 인가                    | IAM     |
| **Nova**      | VM Lifecycle 관리            | EC2     |
| **Neutron**   | Virtual Network 관리         | VPC     |
| **Glance**    | VM Image 관리                | AMI     |
| **Cinder**    | Block Storage              | EBS     |
| **Horizon**   | Web Dashboard              | Console |
| **Placement** | Compute Resource Inventory | -       |

---

# 5. Keystone — Identity Service

> **OpenStack의 사용자 인증 · 인가를 담당하는 서비스임.**

사용자 · Project · Role을 관리하고 인증된 사용자에게 **Token**을 발급함.

```
User
 │
 │ ID / Password
 ▼
Keystone
 │
 ├─ 사용자 인증
 ├─ Token 발급
 └─ Service Catalog 제공
 │
 ▼
OpenStack API 요청
```

OpenStack의 다른 Service API를 호출할 때 Keystone이 발급한 Token을 함께 전달함.

```
X-Auth-Token: <TOKEN>
```

따라서 Keystone은 **OpenStack의 모든 요청이 통과하는 인증 관문**이라고 이해할 수 있음.

---

## Service Catalog

Keystone 인증 시 Token과 함께 OpenStack Service의 Endpoint 목록을 전달받음.

예를 들어 다음과 같은 정보임.

```
Nova      → Compute API
Neutron   → Network API
Glance    → Image API
Cinder    → Volume API
```

이를 **Service Catalog**라고 함.

Client가 모든 Service 주소를 직접 알고 있을 필요 없이 Keystone을 통해 필요한 Endpoint를 확인할 수 있음.

```
openstack catalog list
```

명령어로 확인 가능함.

---

## Fernet Token

Keystone에서는 기본적으로 Fernet 방식의 Token을 사용할 수 있음.

Token 자체에 사용자 · Project · 만료 시간 등의 정보가 암호화되어 포함됨.

```
사용자 인증
    ↓
Keystone
    ↓
Fernet Token 생성
    ↓
Client
```

Token 정보를 별도의 Token DB에 모두 저장하고 조회하는 방식이 아니기 때문에 확장에 유리한 구조임.

---

# 6. Nova — Compute Service

> **VM의 생성 · 중지 · 재시작 · 삭제 등 Instance Lifecycle을 관리하는 서비스임.**

대표적으로 다음 작업을 담당함.

```
Create
Start
Stop
Reboot
Resize
Delete
```

여기서 중요한 점은,

> **Nova가 VM을 직접 실행하는 것은 아님.**

Nova는 VM 생성 과정을 **관리하고 조율하는 역할**을 담당함.

실제 VM은 더 아래의 Virtualization Layer에서 생성됨.

```
Nova
 ↓
nova-compute
 ↓
libvirt
 ↓
QEMU / KVM
 ↓
VM
```

---

# 7. Nova 내부 Component

Nova 자체도 하나의 Process가 아니라 여러 Component로 구성됨.

|Component|역할|
|---|---|
|`nova-api`|REST API 요청 접수|
|`nova-scheduler`|VM을 배치할 Compute Node 결정|
|`nova-conductor`|Compute와 DB 사이의 중계|
|`nova-compute`|Hypervisor를 통한 VM 관리|

---

## nova-api

> **사용자의 Compute API 요청을 받는 접수 창구임.**

예를 들어 사용자가 VM 생성을 요청하면 `nova-api`가 요청을 받아 처리하기 시작함.

```
Client
   ↓
nova-api
```

---

## nova-scheduler

> **VM을 어느 Compute Node에 배치할지 결정함.**

Scheduler는 크게 **Filter → Weigh** 과정을 수행함.

```
Compute Nodes
      ↓
    Filter
      ↓
조건을 만족하는 Node
      ↓
    Weigh
      ↓
점수가 가장 높은 Node
      ↓
   VM 배치
```

### Filter

조건을 충족하지 않는 Compute Node를 제외함.

예:

```
Memory 부족 → 제외
Disk 부족   → 제외
조건 불일치 → 제외
```

### Weigh

Filter를 통과한 Node에 점수를 부여하여 적절한 Node를 선택함.

```
Node A → 80
Node B → 95  ← 선택
Node C → 70
```

이 과정에서 **Placement가 관리하는 Resource 정보를 활용함.**

---

## nova-conductor

> **nova-compute가 DB에 직접 접근하지 않도록 중간에서 DB 작업을 처리함.**

```
nova-compute
      ↓
RabbitMQ / RPC
      ↓
nova-conductor
      ↓
   MariaDB
```

Compute Node가 수백 대까지 증가했을 때 각 Node가 중앙 DB에 직접 접근하면 보안과 Connection 관리 측면에서 문제가 발생할 수 있음.

따라서 `nova-conductor`가 중간 계층 역할을 수행함.

---

## nova-compute

> **선택된 Compute Node에서 실제 VM 생성 작업을 수행하는 Nova Component임.**

다만 `nova-compute` 역시 VM을 직접 실행하지 않음.

```
nova-compute
      ↓
   libvirt
      ↓
 QEMU / KVM
      ↓
     VM
```

Hypervisor 계층에 VM 생성 작업을 요청하는 역할임.

---

# 8. Placement — Resource Inventory

> **Compute Node가 가지고 있는 자원 현황을 관리하는 서비스임.**

대표적으로 다음과 같은 Resource 정보를 관리함.

```
vCPU
Memory
Disk
...
```

Nova Scheduler가 VM을 배치할 Node를 결정할 때 Placement의 정보를 활용함.

```
nova-scheduler
       │
       │ Resource 조회
       ▼
   Placement
       │
       │ CPU / Memory / Disk
       ▼
Compute Node 선택
```

---

# 9. Neutron — Networking Service

> **OpenStack의 Virtual Network를 생성하고 관리하는 서비스임.**

대표적으로 다음 Resource를 관리함.

### Network

가상의 L2 Network임.

```
Network ≒ Virtual Switch
```

### Subnet

Network에서 사용할 IP Address Range를 정의함.

```
10.0.0.0/24
```

### Router

서로 다른 Network를 연결함.

```
Private Network
       ↓
     Router
       ↓
External Network
```

### Security Group

Instance에 적용되는 Virtual Firewall Rule임.

예:

```
Inbound TCP 22 Allow
Inbound TCP 80 Allow
```

### Floating IP

외부에서 Instance에 접근하기 위해 연결하는 IP임.

```
Internet
   ↓
Floating IP
   ↓
Private IP
   ↓
Instance
```

---

# 10. Glance — Image Service

> **VM을 생성할 때 사용하는 OS Image를 관리하는 서비스임.**

AWS의 AMI와 비슷한 역할임.

```
Glance
 ├─ Ubuntu
 ├─ Rocky Linux
 └─ CirrOS
```

OpenStack 실습에서는 Resource 사용량이 적은 **CirrOS**를 테스트 Image로 많이 사용함.

대표적인 Image Format으로 `qcow2`가 있음.

---

# 11. Cinder — Block Storage

> **Instance에 연결할 Persistent Block Storage를 관리하는 서비스임.**

AWS의 EBS와 유사함.

```
Instance
   │
   ├── Ephemeral Disk
   │      └─ Instance Lifecycle에 종속
   │
   └── Cinder Volume
          └─ Instance와 독립적으로 관리
```

Instance를 삭제하더라도 Volume을 별도로 유지할 수 있으며 다른 Instance에 다시 연결할 수 있음.

---

# 12. Horizon — Dashboard

> **OpenStack Resource를 Web UI에서 관리할 수 있도록 제공하는 Dashboard임.**

```
Browser
   ↓
Horizon
   ↓
OpenStack API
   ↓
Nova / Neutron / Glance / Cinder
```

Horizon 자체가 VM이나 Network를 직접 생성하는 것은 아님.

Horizon 역시 OpenStack API를 호출하는 **Client**임.

---

# 13. OpenStack 서비스 간 통신

OpenStack의 통신 구조는 크게 두 가지로 구분할 수 있음.

```
① 서비스 ↔ 서비스
   REST API

② 서비스 내부 Component ↔ Component
   RPC / Message Queue
```

---

## REST API

서로 다른 OpenStack Service 사이의 요청에는 REST API가 사용됨.

예:

```
Nova → Glance
Nova → Neutron
Nova → Cinder
```

HTTP 기반 API 요청을 통해 필요한 Resource 정보를 요청함.

---

## RabbitMQ

> **OpenStack 내부 Component 사이에서 작업을 전달하는 Message Broker임.**

기본 구조는 다음과 같음.

```
Producer
   ↓
Exchange
   ↓
Binding
   ↓
Queue
   ↓
Consumer
```

|요소|역할|
|---|---|
|Producer|Message 발행|
|Exchange|Message 분류|
|Binding|Routing Rule|
|Queue|Message 저장|
|Consumer|Message 처리|

OpenStack에서는 RabbitMQ 위에서 RPC를 사용하여 Component 간 작업을 전달함.

### Message Queue를 사용하는 이유

VM 생성처럼 오래 걸리는 작업을 API가 끝날 때까지 기다리는 구조로 만들면 API Worker가 장시간 점유될 수 있음.

따라서 작업을 Message Queue를 통해 전달함.

```
nova-api
   ↓
Message Queue
   ↓
nova-compute
```

이를 통해 Component 간 결합도를 낮추고 비동기 작업 전달이 가능해짐.

---

# 14. OpenStack VM 생성 전체 흐름 ⭐

사용자가 Instance 생성을 요청하면 여러 OpenStack Service가 협력하여 최종 VM을 생성함.
![OpenStack VM Flow](../images/openstack_vm_flow.png)

## ① 사용자 요청

```
User
 ↓
Horizon / CLI / SDK
```

사용자가 VM 생성을 요청함.

---

## ② Keystone 인증

```
Client
 ↓ ID / Password
Keystone
 ↓
Token + Service Catalog
```

Keystone이 사용자를 인증하고 Token을 발급함.

---

## ③ nova-api 요청 접수

Client가 Token과 함께 VM 생성 요청을 전달함.

```
POST /servers
X-Auth-Token: <TOKEN>
```

`nova-api`가 요청을 접수함.

---

## ④ Glance Image 확인

Nova가 VM 부팅에 사용할 Image 정보를 확인함.

```
Nova
 ↓
Glance
 ↓
CirrOS / Ubuntu / Rocky Linux
```

---

## ⑤ Neutron Network 준비

VM이 사용할 Network Resource를 준비함.

```
Network
Subnet
Port
Security Group
```

---

## ⑥ Scheduler 배치 결정

`nova-scheduler`가 VM을 어느 Compute Node에 배치할지 판단함.

```
nova-scheduler
       ↓
   Placement
       ↓
Resource 확인
       ↓
Compute Node 결정
```

---

## ⑦ Placement Resource 조회

각 Compute Node의 사용 가능한 자원을 확인함.

```
CPU
Memory
Disk
```

---

## ⑧ RabbitMQ 작업 전달

선택된 Compute Node의 `nova-compute`에 VM 생성 작업을 전달함.

```
Scheduler
   ↓
RabbitMQ
   ↓
nova-compute
```

---

## ⑨ nova-compute 작업 수행

Compute Node에서 VM 생성 작업을 수행함.

```
nova-compute
      ↓
Hypervisor
```

---

## ⑩ libvirt 호출

`nova-compute`가 libvirt를 통해 Hypervisor에 VM 생성을 요청함.

```
nova-compute
      ↓
   libvirt
      ↓
 QEMU / KVM
```

---

## ⑪ QEMU / KVM에서 VM 생성

실제 VM Process를 생성함.

```
QEMU / KVM
     ↓
     VM
```

---

## 전체 흐름

```
User
 ↓
Horizon / CLI / SDK
 ↓
Keystone
 ↓
nova-api
 ├────→ Glance
 ├────→ Neutron
 ↓
nova-scheduler
 ↓
Placement
 ↓
RabbitMQ
 ↓
nova-compute
 ↓
libvirt
 ↓
QEMU / KVM
 ↓
VM
```

> **Keystone이 인증하고 → Nova가 VM 생성을 조율하고 → Placement가 Resource를 확인하고 → Scheduler가 Compute Node를 선택하고 → nova-compute가 libvirt를 통해 Hypervisor에 VM 생성을 요청함.**

---

# 15. Hypervisor 계층

OpenStack에서 실제 VM 생성까지 내려가면 다음 구조가 됨.

```
OpenStack
   ↓
Nova
   ↓
nova-compute
   ↓
libvirt
   ↓
QEMU / KVM
   ↓
VM
```

## libvirt

> **여러 Hypervisor를 공통 Interface로 관리하기 위한 추상화 계층임.**

Nova가 KVM이나 QEMU의 세부 구현을 직접 제어하지 않고 libvirt를 통해 VM을 관리함.

확인 시 다음 CLI를 사용할 수 있음.

```
virsh list
```

---

## KVM

> **Linux Kernel에 포함된 Hardware Virtualization 기능임.**

CPU의 Hardware Virtualization 기능을 활용함.

```
Intel → VT-x
AMD   → AMD-V
```

Hardware 가속을 사용하여 VM을 효율적으로 실행할 수 있음.

---

## QEMU

> **실제 VM Process를 실행하는 Emulator임.**

KVM을 사용할 수 있는 경우 CPU 실행은 KVM의 Hardware Virtualization을 활용함.

```
QEMU
 │
 ├─ CPU → KVM / Hardware Acceleration
 ├─ Virtual Disk
 └─ Virtual NIC
```

KVM을 사용할 수 없는 경우 QEMU가 CPU까지 Software 방식으로 Emulation할 수 있으므로 성능이 크게 감소함.

---

# 16. Nested Virtualization

현재 실습 환경에서는 **VM 안에서 다시 VM을 실행하는 구조**를 사용함.

```
Physical Server
      ↓
Gabia Hypervisor
      ↓
Ubuntu VM
      ↓
OpenStack
      ↓
QEMU / KVM
      ↓
OpenStack Instance
```

이를 **Nested Virtualization**이라고 함.

Hardware Virtualization 지원 여부는 다음 명령어로 확인 가능함.

```
egrep -c '(vmx|svm)' /proc/cpuinfo
```

결과가 `0`이라면 Nested Virtualization을 사용할 수 없는 환경일 가능성이 있음.

이 경우 QEMU Software Emulation을 사용하게 되어 Instance 생성 속도가 느려질 수 있음.