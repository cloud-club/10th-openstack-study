# 인스턴스 생성의 전 과정과 SSH

> **학습 목표**
> 
> 
> OpenStack에서 인스턴스 생성 요청이 실제 VM 실행으로 이어지는 과정을 이해하고, SSH를 통해 생성된 서버에 접속하여 상태를 확인합니다.
> 
> 추가로 Nova Scheduler가 여러 Compute Node 중 하나를 선택하는 과정과 운영자가 VM의 배치를 제어할 수 있는 방법을 살펴봅니다.
> 

이번 주차에서는 OpenStack의 각 서비스를 개별적으로 살펴본 지난 주차에 이어, **사용자가 인스턴스 생성을 요청했을 때 각 서비스가 어떤 순서로 동작하는지**를 중심으로 정리했습니다.

또한 실제 VM에 SSH로 접속하여 OS, CPU, Memory, Disk, Network 등의 상태를 확인했습니다.

---

# 1. 인스턴스 생성의 전체 과정

사용자가 Horizon이나 CLI에서 인스턴스 생성을 요청하면 바로 VM이 만들어지는 것이 아닙니다.

인증부터 Compute Node 선택, Image와 Network 준비, 실제 VM 실행까지 여러 단계를 거칩니다.

`Horizon / CLI → Keystone → nova-api → nova-scheduler ↔ Placement → nova-compute → libvirt → QEMU/KVM → VM`

전체 과정을 6단계로 나누면 다음과 같습니다.

| 단계 | 과정 | 주요 Component |
| --- | --- | --- |
| **1** | 사용자 인증 | Keystone |
| **2** | 인스턴스 생성 요청 접수 | nova-api |
| **3** | Compute Node 선택 | nova-scheduler / Placement |
| **4** | 생성 작업 전달 | RabbitMQ / nova-compute |
| **5** | Image, Network, Volume 준비 | Glance / Neutron / Cinder |
| **6** | 실제 VM 실행 | libvirt / QEMU/KVM |

---

## Step 1. 사용자 인증

사용자가 OpenStack에 요청을 보내기 위해서는 먼저 Keystone을 통해 인증해야 합니다.

사용자가 ID와 Password 등의 인증 정보를 전달하면 Keystone은 인증에 성공한 사용자에게 **Token**을 발급합니다.

이후 Nova와 같은 OpenStack API를 호출할 때 발급받은 Token을 Header에 포함합니다.

```
X-Auth-Token: <Token>
```

OpenStack 서비스는 Token을 통해 사용자가 누구인지, 어느 Project에 속해 있는지, 해당 요청을 수행할 권한이 있는지를 확인합니다.

---

## Step 2. 인스턴스 생성 요청 접수

인증이 완료되면 `nova-api`가 인스턴스 생성 요청을 받습니다.

nova-api는 Image, Flavor, Network 등 요청에 필요한 정보를 확인한 뒤 DB에 인스턴스 Record를 생성하고 상태를 `BUILD`로 기록합니다.

> **BUILD 상태 ≠ 실제 VM 생성 완료**
> 
> 
> Horizon에서는 DB에 생성된 Record를 기반으로 인스턴스를 표시하기 때문에 실제 QEMU Process가 실행되기 전에도 인스턴스가 화면에 나타날 수 있습니다.
> 

---

## Step 3. Compute Node 배치 결정

다음으로 `nova-scheduler`가 VM을 실행할 Compute Node를 결정합니다.

Scheduler는 Placement를 통해 요청한 VM에 필요한 Compute Resource를 제공할 수 있는 후보를 확인하고, Scheduling 조건을 적용하여 최종 Compute Node를 선택합니다.

`VM Resource Request → Placement → Candidate → Filter / Weigh → Compute Node`

이 단계는 이번 주차에서 추가로 궁금했던 부분이기 때문에 뒤에서 더 자세히 살펴봅니다.

---

## Step 4. Compute Node에 작업 전달

Compute Node가 결정되면 해당 Node에서 실행되는 `nova-compute`에 VM 생성 작업이 전달됩니다.

Nova Component 사이에서는 RabbitMQ를 이용한 RPC 방식으로 작업을 전달할 수 있으며, VM 생성과 같이 시간이 걸리는 작업은 요청을 전달한 뒤 완료될 때까지 계속 기다리지 않는 비동기적인 방식으로 처리할 수 있습니다.

---

## Step 5. VM에 필요한 자원 준비

VM을 실행하기 위해서는 Compute Resource뿐만 아니라 Image와 Network 등의 자원이 필요합니다.

| 서비스 | 역할 |
| --- | --- |
| **Glance** | VM이 부팅할 OS Image를 제공합니다. |
| **Neutron** | Port를 생성하고 MAC Address와 IP를 할당합니다. |
| **Cinder** | 필요한 경우 Block Volume을 준비하고 연결합니다. |

이 과정에서는 Image 전송이나 Network, Storage 관련 작업처럼 실제 I/O가 발생하기 때문에 앞의 인증이나 Scheduling 과정보다 시간이 오래 걸릴 수 있습니다.

---

## Step 6. 실제 VM 실행

필요한 자원 준비가 완료되면 `nova-compute`가 libvirt를 통해 VM 생성을 요청합니다.

`nova-compute → libvirt → QEMU/KVM → VM`

libvirt는 VM의 정의를 가상화 계층에 전달하고 QEMU Process가 실행되면서 실제 VM이 만들어집니다.

정상적으로 VM이 실행되면 인스턴스 상태가 `BUILD`에서 `ACTIVE`로 변경됩니다.

> **ACTIVE = SSH 접속 가능은 아닙니다.**
> 
> 
> ACTIVE는 OpenStack이 VM을 실행한 상태를 의미합니다. 이후 Guest OS가 부팅되고 cloud-init 등의 초기화 과정이 완료되어야 SSH 접속까지 정상적으로 가능해집니다.
> 

---

# 2. BUILD에서 ACTIVE까지

인스턴스가 `BUILD` 상태에 있는 동안에도 내부적으로 여러 작업이 진행됩니다.

`BUILD → Scheduling → Networking → Spawning → ACTIVE`

| 단계 | 의미 |
| --- | --- |
| **Scheduling** | VM을 실행할 Compute Node를 결정합니다. |
| **Networking** | Neutron을 통해 Network Resource를 준비합니다. |
| **Spawning** | 실제 VM을 생성하고 실행합니다. |
| **ACTIVE** | VM 실행이 완료된 상태입니다. |
| **ERROR** | 생성 과정에서 문제가 발생한 상태입니다. |

어느 단계에서 문제가 발생했는지 확인하면 장애 원인을 찾을 범위를 줄일 수 있습니다.

예를 들어 다음과 같은 오류가 발생할 수 있습니다.

```
No valid host was found
```

이는 Scheduler가 요청 조건을 만족하는 Compute Node를 찾지 못했다는 의미입니다.

따라서 Compute Node의 vCPU, Memory, Disk 등의 Resource가 충분한지 또는 VM의 Scheduling 조건을 만족하는 Host가 존재하는지 확인할 필요가 있습니다.

또한 OpenStack API 요청에는 `req-`로 시작하는 Request ID가 부여되기 때문에 관련 서비스의 Log에서 동일한 Request ID를 추적하여 요청 처리 과정을 확인할 수 있습니다.

---

# 3. SSH와 Key Pair

SSH는 Network를 통해 원격 Server에 안전하게 접속할 수 있도록 하는 Protocol이며 기본적으로 TCP 22번 Port를 사용합니다.

Cloud 환경에서는 Password 인증 대신 **Public Key와 Private Key를 이용한 Key Pair 인증**을 많이 사용합니다.

| Key | 저장 위치 |
| --- | --- |
| **Public Key** | Server의 `~/.ssh/authorized_keys` |
| **Private Key** | 사용자의 Local PC |

Server에는 Public Key를 등록하고 사용자는 이에 대응하는 Private Key를 보관합니다.

> **Private Key는 외부에 공유하면 안 됩니다.**
> 
> 
> `.pem` 파일을 GitHub 등의 공개 Repository에 올리거나 다른 사람에게 전달하지 않도록 관리해야 합니다.
> 

SSH를 사용하기 전 Private Key의 권한도 제한합니다.

```
chmod600 10th-openstack.pem
```

이후 `-i` Option으로 사용할 Private Key를 지정하여 접속합니다.

```
ssh-i 10th-openstack.pem ubuntu@<Public-IP>
```

---

# 4. SSH 접속 후 VM 확인

이번 실습에서는 지급받은 VM에 직접 SSH로 접속한 뒤 기본적인 Server 상태를 확인했습니다.

| 확인 항목 | 명령어 | 확인 결과 |
| --- | --- | --- |
| **OS** | `lsb_release -a` | Ubuntu 24.04.4 LTS |
| **vCPU** | `nproc` | 2 |
| **Memory** | `free -h` | 약 7.8GiB |
| **Root Disk** | `df -h /` | 약 48GB |
| **Virtualization Flag** | `egrep -c '(vmx|svm)' /proc/cpuinfo` | 4 |
| **Network** | `ip a` | eth0 / 192.168.0.104/24 |

실제로 SSH 접속 후 명령어를 실행해 봄으로써 VM에 할당된 Compute Resource와 Network 상태를 확인할 수 있었습니다.

### 가상화 Flag

다음 명령어는 Guest에서 CPU의 Hardware Virtualization Flag가 노출되는지 확인합니다.

```
egrep-c'(vmx|svm)' /proc/cpuinfo
```

이번 환경에서는 결과가 `4`로 확인되었습니다.

> 이 값은 Guest CPU에 `vmx` 또는 `svm` Flag가 노출되어 있다는 것을 의미합니다. 실제 Nested KVM 사용 가능 여부는 KVM Module과 Host 설정 등도 함께 확인해야 합니다.
> 

---

# 5. cloud-init과 Metadata Service

Cloud Image에는 VM이 처음 부팅될 때 초기 설정을 수행하기 위한 `cloud-init`이 포함될 수 있습니다.

cloud-init은 다음과 같은 작업을 수행합니다.

- SSH Public Key 등록
- Hostname 설정
- Disk 확장
- User Data 실행

OpenStack에서 사용자가 등록한 SSH Public Key 역시 VM이 처음 부팅되는 과정에서 Guest OS에 적용되어야 합니다.

이를 위해 VM은 Metadata Service에서 자신에게 필요한 정보를 가져올 수 있습니다.

`VM → 169.254.169.254 → Metadata Service → cloud-init → authorized_keys`

`169.254.169.254`는 Link-local Address이며 VM은 이 주소를 이용해 자신의 Metadata에 접근할 수 있습니다.

따라서 Hypervisor에서는 VM이 정상적으로 실행되어 `ACTIVE` 상태가 되었더라도 cloud-init이나 Metadata 처리에 문제가 있다면 SSH Key가 정상적으로 적용되지 않아 SSH 접속이 실패할 수 있습니다.

---

# 6. SSH Troubleshooting

SSH 접속에 실패했다면 Error Message를 통해 어느 부분부터 확인해야 하는지 판단할 수 있습니다.

| Error | 의미 | 확인할 부분 |
| --- | --- | --- |
| `Permission denied (publickey)` | 인증 실패 | 계정, Private Key |
| `UNPROTECTED PRIVATE KEY FILE` | Key 권한 문제 | `chmod 600` |
| `Identity file not accessible` | Key File을 찾지 못함 | File Path |
| `Connection timed out` | SSH Server까지 연결되지 않음 | IP, Network, Firewall |
| `Connection refused` | Server에는 도달했지만 연결을 거부함 | SSH Service, Port |

특히 `timed out`과 `refused`를 구분하면 Troubleshooting 범위를 빠르게 좁힐 수 있습니다.

`timed out`은 Packet이 대상 SSH Port까지 정상적으로 도달하지 못했을 가능성이 크고, `refused`는 대상 Host에는 도달했지만 해당 Port에서 Connection을 받아주지 않는 상태입니다.

### known_hosts

SSH로 Server에 처음 접속하면 Server의 Host Key Fingerprint를 확인합니다.

사용자가 이를 신뢰하면 해당 정보가 Local PC의 `~/.ssh/known_hosts`에 저장됩니다.

동일한 IP의 Server Host Key가 이후 변경되면 다음과 같은 경고가 발생할 수 있습니다.

```
REMOTE HOST IDENTIFICATION HAS CHANGED!
```

Cloud 환경에서는 VM을 삭제하고 새로운 VM이 동일한 IP를 할당받은 경우에도 발생할 수 있습니다.

정상적인 Server 교체임을 확인했다면 기존 Host Key를 제거할 수 있습니다.

```
ssh-keygen-R <IP>
```

---

# 7. 추가로 공부한 내용

인스턴스 생성 과정을 살펴보면서 **Nova Scheduler가 여러 Compute Node 중 정확히 어떤 Node를 선택하는지**, 그리고 **운영자가 Instance를 특정 조건의 Compute Node에 배치하도록 제어할 수 있는지** 궁금했습니다.

따라서 Scheduler와 Placement의 관계를 조금 더 자세히 살펴봤습니다.

---

## 7.1 Nova Scheduler는 어떤 Compute Node를 선택할까?

예를 들어 세 개의 Compute Node가 존재한다고 가정합니다.

```
Compute-01
Compute-02
Compute-03
```

사용자가 `2 vCPU / 4GB RAM`의 Instance를 요청했다고 해서 Scheduler가 단순히 남은 Memory가 가장 많은 Node를 바로 선택하는 것은 아닙니다.

전체적인 흐름은 다음과 같습니다.

`Instance 요구사항 → Placement → Allocation Candidates → Scheduling → 최종 Compute Node`

Placement는 요청을 만족할 수 있는 Resource Provider 후보를 찾는 데 필요한 Resource 정보를 관리하고, Nova Scheduler는 이러한 후보와 Scheduling 정책을 바탕으로 최종 Host를 결정합니다.

---

## 7.2 Placement와 Resource Provider

**Resource Provider**는 Compute Resource를 제공하는 대상을 Placement에서 표현하는 단위입니다.

Compute Node 역시 Resource Provider로 표현됩니다.

예를 들어 Compute-01이 다음과 같은 자원을 제공한다고 가정할 수 있습니다.

```
Compute-01
└─ Resource Provider
   ├─ VCPU
   ├─ MEMORY_MB
   └─ DISK_GB
```

Placement는 이러한 Resource Provider와 해당 Provider가 제공할 수 있는 Resource 정보를 관리합니다.

> **Placement가 직접 VM을 배치하는 것은 아닙니다.**
> 
> 
> Placement는 요청 조건을 만족할 수 있는 Resource Provider 후보를 찾는 데 필요한 정보를 제공하고, 최종 Compute Host 선택은 Nova Scheduler가 수행합니다.
> 

---

## 7.3 Inventory와 Allocation

Placement에서 Resource를 이해하기 위해 중요한 개념이 **Inventory와 Allocation**입니다.

| 개념 | 의미 |
| --- | --- |
| **Inventory** | Resource Provider가 제공할 수 있는 Resource 정보 |
| **Allocation** | Consumer에 실제로 할당된 Resource 정보 |

예를 들어 Compute Node가 32개의 vCPU를 제공할 수 있다는 정보는 Inventory에 해당하고, 그중 일부가 이미 Instance에 할당되어 있다는 정보는 Allocation으로 관리됩니다.

간단하게 정리하면 다음과 같습니다.

> **Inventory = 무엇을 얼마나 제공할 수 있는가**
> 
> 
> **Allocation = 그중 무엇이 실제로 할당되어 있는가**
> 

Placement는 이러한 정보를 이용하여 새로운 Instance의 Resource Request를 만족할 수 있는 후보를 찾습니다.

---

## 7.4 Allocation Candidate

사용자가 Instance를 요청하면 Placement는 Resource 요구사항을 만족할 수 있는 **Allocation Candidate**를 반환할 수 있습니다.

예를 들어:

```
Instance
2 vCPU / 4GB RAM
       ↓
   Placement
       ↓
Compute-01  O
Compute-02  X
Compute-03  O
```

Compute-02가 필요한 Resource를 제공할 수 없다면 후보에서 제외되고 Compute-01과 Compute-03이 Candidate가 될 수 있습니다.

이렇게 만들어진 후보를 기반으로 Nova Scheduler가 최종 Compute Node를 결정합니다.

---

## 7.5 Filter와 Weigher

Scheduler는 Scheduling 과정에서 **Filter와 Weigher**를 이용할 수 있습니다.

### Filter

Filter는 특정 조건을 만족하지 못하는 Host를 제외하는 역할을 합니다.

```
Compute-01  O
Compute-02  X
Compute-03  O

       ↓ Filter

Compute-01
Compute-03
```

즉 Filter는 Host에 점수를 주는 것이 아니라 **해당 Host가 조건을 만족하는지 판단하여 후보를 좁히는 역할**을 합니다.

### Weigher

Filter 이후에도 여러 Host가 남아 있다면 Weigher를 통해 Host의 우선순위를 계산할 수 있습니다.

```
Compute-01 ─ Weight
Compute-03 ─ Weight
      ↓
Selected Host
```

따라서 전체적인 Scheduling 흐름은 다음과 같이 이해할 수 있습니다.

`Resource 요구사항 → Placement 후보 → Filter → Weigher → Compute Node 선택`

---

## 7.6 Trait을 이용한 Capability 기반 배치

CPU나 Memory의 양만으로는 Compute Node의 모든 차이를 표현할 수 없습니다.

예를 들어 두 Compute Node가 동일한 CPU와 Memory를 가지고 있지만 특정 CPU 기능이나 Hardware Capability가 다를 수 있습니다.

이러한 **정성적인 Resource Provider의 특성**을 Placement에서는 Trait으로 표현할 수 있습니다.

```
Compute-01
├─ 16 vCPU
├─ 64GB RAM
└─ 특정 CPU Capability 지원

Compute-02
├─ 16 vCPU
├─ 64GB RAM
└─ 해당 Capability 미지원
```

Instance가 특정 Trait을 요구하도록 구성하면 Placement는 해당 Capability를 제공하는 Resource Provider를 후보로 찾을 수 있습니다.

> **Inventory가 "얼마나 가지고 있는가"를 표현한다면 Trait은 "어떤 특성을 가지고 있는가"를 표현합니다.**
> 

---

## 7.7 Availability Zone과 Host Aggregate

운영자는 Compute Host들을 논리적으로 구분하여 Instance가 배치될 범위를 제어할 수 있습니다.

### Availability Zone

Availability Zone은 사용자가 Instance를 생성할 때 선택할 수 있는 논리적인 배치 영역입니다.

예를 들어:

```
AZ-A
├─ Compute-01
└─ Compute-02

AZ-B
├─ Compute-03
└─ Compute-04
```

사용자가 `AZ-A`를 선택하면 해당 영역을 대상으로 Scheduling할 수 있습니다.

다만 Availability Zone이라는 이름 자체가 물리적인 장애 격리를 자동으로 보장하는 것은 아닙니다.

Rack이나 전원 계통 등을 기준으로 실제 장애 영역을 분리하려면 운영자가 Compute Host를 그에 맞게 설계하고 구성해야 합니다.

### Host Aggregate

Host Aggregate는 **운영자가 특정 기준에 따라 Compute Host를 그룹화하는 방법**입니다.

```
SSD Aggregate
├─ Compute-01
└─ Compute-02

GPU Aggregate
├─ Compute-03
└─ Compute-04
```

Availability Zone이 사용자에게 노출할 수 있는 논리적인 배치 영역이라면 Host Aggregate는 운영자가 Compute Host의 특성이나 정책에 따라 Host를 그룹화하여 Scheduling에 활용하는 데 사용할 수 있습니다.

---

## 7.8 Flavor Extra Specs를 이용한 배치 제어

Host Aggregate와 Flavor의 Extra Specs를 연결하면 특정 Flavor를 사용하는 Instance가 특정 종류의 Compute Host에 배치되도록 구성할 수 있습니다.

예를 들어 GPU가 설치된 Compute Host를 별도의 Aggregate로 묶었다고 가정합니다.

```
GPU Flavor
     ↓
Flavor Extra Specs
     ↓
GPU Host Aggregate
     ↓
Compute-03 / Compute-04
```

사용자는 개별 Compute Host의 이름을 직접 알 필요 없이 GPU용 Flavor를 선택하고, 운영자가 설정한 Scheduling 정책에 따라 적절한 Host에 VM이 배치되도록 구성할 수 있습니다.

즉 **사용자는 필요한 VM의 종류를 선택하고, 운영자는 실제 Infrastructure의 배치 정책을 관리하는 구조**를 만들 수 있습니다.

---

## 7.9 Server Group과 Affinity / Anti-Affinity

앞의 방법들이 **어떤 종류의 Compute Host에 VM을 배치할 것인지**에 초점을 맞췄다면 Server Group은 **여러 Instance 사이의 배치 관계**를 정의하는 데 사용할 수 있습니다.

### Affinity

Affinity는 Server Group에 속한 Instance들을 같은 Host에 배치하도록 하는 정책입니다.

```
Compute-01
├─ VM-A
├─ VM-B
└─ VM-C
```

### Anti-Affinity

Anti-Affinity는 Server Group의 Instance들을 서로 다른 Host에 배치하도록 하는 정책입니다.

```
Compute-01     Compute-02     Compute-03
   VM-A           VM-B           VM-C
```

또한 `soft-affinity`, `soft-anti-affinity`와 같이 조건을 반드시 만족시키기보다 **가능하면 해당 방향으로 배치하도록 선호하는 정책**도 사용할 수 있습니다.

| 정책 | 의미 |
| --- | --- |
| **affinity** | 같은 Host에 배치 |
| **anti-affinity** | 서로 다른 Host에 배치 |
| **soft-affinity** | 가능하면 같은 Host에 배치 |
| **soft-anti-affinity** | 가능하면 서로 다른 Host에 배치 |

---

## 7.10 실제 운영에서의 HA 배치

예를 들어 동일한 API Service를 제공하는 Instance 3대를 운영한다고 가정합니다.

별도의 배치 정책이 없다면 여러 Instance가 동일한 Compute Node에 배치될 가능성이 있습니다.

```
Compute-01
├─ API-01
├─ API-02
└─ API-03
```

이 경우 Compute-01에 장애가 발생하면 세 Instance가 동시에 영향을 받을 수 있습니다.

Anti-Affinity를 이용하여 Instance를 서로 다른 Compute Node에 분산하면 다음과 같이 구성할 수 있습니다.

```
Compute-01     Compute-02     Compute-03
  API-01         API-02         API-03
```

이렇게 하면 하나의 Compute Node 장애가 여러 Service Instance에 동시에 영향을 주는 위험을 줄일 수 있습니다.

반대로 특정 Hardware가 필요한 Workload라면 Trait이나 Host Aggregate 등의 조건을 이용하여 **특정 Capability를 가진 Compute Node만 배치 후보로 제한**할 수도 있습니다.

> **정리**
> 
> 
> Nova Scheduler는 단순히 여유 Resource가 가장 많은 Compute Node를 선택하는 것이 아니라 Placement의 Resource 정보와 Scheduling 조건을 바탕으로 적절한 Host를 결정합니다.
> 
> 운영자는 Availability Zone, Host Aggregate, Trait, Flavor Extra Specs, Server Group 등의 기능을 이용하여 **어떤 종류의 Host에 VM을 배치할지, 여러 VM을 서로 어떻게 배치할지까지 제어할 수 있습니다.**
>