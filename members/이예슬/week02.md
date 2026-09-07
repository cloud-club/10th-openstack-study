# 개요
> **주제: OpenStack 아키텍처**
> **세부 내용: 핵심 컴포넌트 6가지 ↔ AWS 대응 개념**

# 내용
## OpenStack이란?
 **공식 정의**
> “데이터센터 전반에 걸쳐 있는 대규모의 컴퓨팅, 스토리지, 네트워킹 자원 풀(pool)을 제어하는 클라우드 운영체제이며, 이 모든 자원은 공통된 인증 메커니즘을 갖춘 API를 통해 관리되고 프로비저닝된다.”

- IaaS 클라우드를 직접 구축하기 위한 오픈소스 플랫폼.
- 데이터센터에 **물리 서버가 실제로 여러 대 존재**하고, 해당 물리 서버를 각각 따로 쓰는 게 아니라 **하나의 거대한 자원 풀**처럼 묶어주는 역할.

**예시**
- 데이터센터에 아래와 같이 물리 서버가 존재.
```
물리 서버 A: CPU 32코어, RAM 128GB
물리 서버 B: CPU 32코어, RAM 128GB
물리 서버 C: CPU 64코어, RAM 256GB
```
- 사용자는 아래와 같은 식으로 요청.
	`"vCPU 4개, RAM 8GB짜리 Ubuntu VM 하나 만들어줘."`
- OpenStack이 알아서 빈 자원이 있는 물리 서버를 찾아서 VM을 생성해 줌.
```
사용자
  ↓
"VM 하나 주세요"
  ↓
OpenStack
  ↓
물리 서버 A/B/C 중 적절한 곳 선택
  ↓
VM 생성
  ↓
IP 주소 할당
  ↓
사용자에게 VM 제공
  ↓
ssh ubuntu@10.x.x.x
```

**일반 OS vs OpenStack**
- 일반 OS (예: 리눅스): 한 대의 컴퓨터 안에서 CPU, 메모리, 디스크 등의 리소스를 여러 프로세스에 나눠줌.
- OpenStack: 같은 일을 데이터센터 규모에서 실행. 서버 수십~수천 대의 CPU, 메모리, 디스크, 네트워크를 하나로 묶고, 여러 사용자에게 나눠줌. 따라서 클라우드 운영체제라고 부름.

**프로비저닝**
- 자원을 준비해서 사용 가능한 상태로 만들어 주는 것.
- 예: "VM 하나를 생성해 줘."라는 요청을 받으면 실제로 아래와 같은 과정이 필요함. 이 전체 과정을 수행하는 것.
```
VM을 실행할 Compute Node 선택
→ 이미지 가져오기
→ 가상 디스크 준비
→ vCPU/RAM 할당
→ 네트워크 포트 생성
→ IP 할당
→ VM 부팅
```

**공통된 인증 메커니즘을 갖춘 API**
- OpenStack에는 여러 인터페이스(웹 UI, 터미널 CLI, 파이썬 SDK)가 존재함. 어디에서 사용하든 최종적으로는 전부 같은 REST API가 호출됨.
- 모든 호출은 하나의 인증 서비스(Keystone)을 통과해 처리됨.
- **인증 구조**
```
           ① 인증
User ----------------> Keystone
 ^                        |
 |        Token           |
 +------------------------+

           ② API 호출
User ----------------> Nova API
       Token 포함
```

## 핵심 컴포넌트
OpenStack은 하나의 프로그램이 아니라, 역할이 다른 여러 서비스가 협력하는 구조임.
각 서비스는 별도의 프로세스로 돌고, 각각 API, DB 등을 가짐.

**핵심 컴포넌트**

| 컴포넌트      | 역할 한 줄  | API 포트 | AWS 대응                  |
| --------- | ------- | ------ | ----------------------- |
| Keystone  | 인증·인가   | 5000   | IAM                     |
| Nova      | VM 생명주기 | 8774   | EC2                     |
| Neutron   | 네트워크    | 9696   | VPC                     |
| Glance    | 부팅 이미지  | 9292   | AMI                     |
| Cinder    | 블록 스토리지 | 8776   | EBS                     |
| Horizon   | 웹 대시보드  | 80/443 | Console                 |
| Placement | 자원 인벤토리 | 8778   | AWS 내부 시스템이라 사용자에게 안 보임 |

## 서비스 간 통신 방법
OpenStack은 상황에 따라 두 가지 방법을 사용함.

### 서비스와 서비스 사이: REST API
사용자가 입력하는 CLI 명령은 전부 REST API로 변환됨.
이때, 모든 요청에 **Keystone이 발급한 토큰**이 붙음.

```bash
# 사용자의 명령
openstack server list

# 내부적으로 실제 전송되는 것
GET /v2.1/servers HTTP/1.1
Host: <nova-api 주소>:8774
X-Auth-Token: gAAAAAB...
```

#### 전체 인증 흐름 (X-Auth-Token)
1. 클라이언트 → Keystone(:5000)
	- ID/비밀번호 제출 (`POST /v3/auth/tokens`)
2. Keystone → 클라이언트
	- 토큰 발급 + **서비스 카탈로그** 전달
3. 클라이언트 → nova-api(:8774)
	- 실제 요청 + X-Auth-Token 헤더
4. nova-api → Keystone
	- "이 토큰 유효해?" 검증
5. 유효하면 요청 처리

**서비스 카탈로그**
- 전체 서비스의 API 주소 목록으로, 2단계에서 토큰과 함께 발급받음.
- 클라이언트가 각 서비스 주소를 미리 알 필요 없이 Keystone만 전체 서비스 주소를 알면 되는 구조.
- `openstack catalog list` 명령어로 직접 볼 수 있음.
- **흐름 예시**
```
Client
   |
   v
Keystone
   |
   └─ Service Catalog
       ├ Nova → XXX
       ├ Neutron → XXX
       ├ Glance → XXX
       └ Cinder → XXX
```

**Fernet 토큰**
- Keystone이 발급하는 토큰의 기본 방식.
- 대칭키로 암호화된 `stateless` 형태로, 검증할 때 DB를 조회하지 않고 키로 복호화만 하면 됨.

### 한 서비스 내부: 메시지 큐 (RabbitMQ)
같은 서비스에 속한 프로세스끼리는 **메시지 큐**로 대화함.

Nova라는 하나의 서비스 안에도 여러 개의 프로세스(예: `nova-api`, `nova-compute`)가 존재하는데, `nova-api`가 처음 REST 요청을 받고 **RabbitMQ**를 통해 다른 `Nova 프로세스`에 넘김.
이때 **AMQP**(Advanced Message Queuing Protocol)라는 표준 프로토콜을 사용함.

```
nova-api
   |
   | "VM 만들어"
   v
RabbitMQ
   |
   | 메시지 보관
   v
nova-compute
```

#### RabbitMQ 내부 구조
아래와 같은 구조로 되어 있음.
```
Producer → Exchange → (Binding 규칙) → Queue → Consumer
```

- **Producer**: 메시지를 보내는 프로그램. (예: "이 VM을 Compute Node에서 생성해"라고 하는 `nova-api` 쪽)
- **Exchange**: 규칙에 따라 메시지를 어디로 보낼지 판단하는 라우터.
- **Binding**: Exchange와 Queue 사이의 연결 규칙. (예: “이 라우팅 키가 붙은 메시지는 이 큐로”)
- **Queue**: 메시지가 소비될 때까지 보관함.
- **Consumer**: Queue의 메시지를 실제로 가져가서 처리하는 프로그램. (예: `nova-compute`)

#### RPC(Remote Procedure Call)
**다른 프로세스의 함수**를 로컬 함수처럼 호출하도록 추상화한 통신 방식임.
OpenStack에서는 이 RPC 요청을 메시지로 만들어 RabbitMQ를 통해 전달함.

**호출 패턴**
- `call`: 보내고 응답을 기다리는 동기 방식.
- `cast`: 요청만 보내고 바로 돌아오는 비동기 방식. VM 생성처럼 오래 걸리는 작업을 처리할 때 사용함.

#### REST 대신 Queue를 사용하는 이유
1. **비동기 처리**: VM 생성처럼 오래 걸리는 작업일 경우, API는 메시지를 던지고 즉시 다음 요청을 받을 수 있음.
2. **Decoupling**: `A -> B`로의 직접 호출인 경우, A가 B의 상태를 항상 신경 써야 하지만, `A → Queue → B`처럼 큐를 사이에 두면 A는 B가 어디에 있고 어떤 상태인지 몰라도 됨.
3. **수평 확장**: 같은 큐를 구독하는 compute 노드를 늘리면 작업이 자동으로 분산됨.

### 공용 인프라: OpenStack 외 서비스
OpenStack을 배포하면 다른 서비스들도 같이 배포됨.
OpenStack은 Nova, Neutron 같은 기능 자체만 담당하고, 데이터 저장, 메시징, 캐싱, 고가용성 등의 기능은 MariaDB, RabbitMQ, Memcached, HAProxy 같은 외부 소프트웨어에 의존함.

| 소프트웨어     | 역할                                                |
| --------- | ------------------------------------------------- |
| MariaDB   | OpenStack 서비스의 상태를 영구 저장. 예: 인스턴스 상태, 네트워크 정보 등  |
| RabbitMQ  | 서비스 내부에서 RPC 메시지를 전달.                             |
| Memcached | 토큰 검증 결과를 메모리에 캐싱하여, 요청마다 Keystone까지 왕복하는 비용이 절약. |
| HAProxy   | 다중 노드 배포일 경우 들어오는 API 요청을 로드밸런싱.                  |

## Nova
Nova는 최소 4개의 독립적인 프로세스로 이루어짐.

| 프로세스               | 역할                                         |
| ------------------ | ------------------------------------------ |
| **nova-api**       | REST 요청 수신, 인증/권한 확인. 내부 Nova 컴포넌트로 작업 전달. |
| **nova-scheduler** | VM을 어느 Compute Node에 배치할지 결정.              |
| **nova-conductor** | Compute Node와 중앙 DB 사이의 관리자.               |
| **nova-compute**   | 하이퍼바이저로 실제 VM 생성을 수행.                      |
**nova-scheduler의 배치 결정 방법**
- 결정에 필요한 각 서버의 자원 정보는 placement에서 가져옴.
1. **Filter**: 메모리 부족, 디스크 부족 등 조건에 안 맞는 서버 제외.
2. **Weigh**: 남은 후보에 점수를 매겨 가장 최적인 한 대를 선택. 예: 여유 메모리가 많을수록 높은 점수 부여.

**nova-conductor의 존재 이유**
- DB 커넥션 폭증 방지: Compute가 증가할수록 DB 연결 수도 늘어남.
- 보안 위험 방지: Compute Node 하나가 뚫리면 DB 전체가 노출될 수 있음.

### 하이퍼바이저
`nova-compute`도 직접 VM 생성을 수행하는 건 아님. 실제 생성은 하이퍼바이저가 담당함.
- Hypervisor: 물리 서버를 VM으로 만들어주는 가상화를 담당하는 소프트웨어

```
nova-compute → libvirt → QEMU/KVM → 실제 VM 프로세스
```

**libvirt**
- KVM, Xen, VMware 등 다양한 하이퍼바이저를 하나의 방식으로 제어할 수 있게 해주는 **추상화 계층**.
- Nova는 하이퍼바이저별 제어 방식을 직접 알 필요 없이 libvirt를 통해 VM 생성, 삭제 등을 요청함.

**KVM**
- 리눅스 커널에 내장된 **가상화 기능**.
- Intel VT-x / AMD-V 같은 하드웨어 가상화 기능을 이용해 VM의 CPU 명령을 실제 물리 CPU에서 빠르게 실행할 수 있게 함.

**QEMU**
- VM을 호스트 OS 위에서 프로세스로 실행하고, 가상 하드웨어(CPU, RAM, 디스크 등)을 에뮬레이션하는 소프트웨어.
 - KVM과 함께 쓰면 CPU 실행은 KVM이 하고, KVM이 없으면 QEMU가 CPU까지 소프트웨어로 에뮬레이션해서 훨씬 느림.

### 중첩 가상화(Nested Virtualization)
**실습 환경의 예상 구조**
- VM 안에 다시 VM을 생성하는 **중첩 가상화 구조**임.
```
가비아 데이터센터의 실제 물리 서버
  └─ 가비아에서 빌린 Ubuntu VM
       └─ OpenStack이 만들어주는 VM
```

OpenStack VM에서 KVM을 쓰려면, 가비아 VM에서 가상화 기능을 노출해 줘야 함.
퍼블릭 클라우드는 이 기능을 제한해 둔 경우가 많음. 하드웨어 가상화 기능을 사용할 수 없다면 KVM 가속을 사용할 수 없고, QEMU가 CPU 명령까지 소프트웨어로 에뮬레이션해야 하므로 인스턴스 실행이 매우 느릴 수 있음. (인스턴스 부팅에 1~2분 정도 소요)

**확인 방법**
```
egrep -c '(vmx|svm)' /proc/cpuinfo
```
- `vmx`: Intel CPU의 VT-x 지원 표시
- `svm`: AMD CPU의 AMD-V 지원 표시
- 결과가 0이면 가상화를 미지원하는 것.


### VM 메모리 16GB 권장 근거
현재 실습 환경에서는 OpenStack control plane과 OpenStack이 생성한 guest VM이 동일한 호스트 메모리를 사용함. 인스턴스를 띄우지 않아도 OpenStack 자체가 수 GB의 메모리를 사용하기 때문에, 충분한 메모리가 필요함.

리눅스 메모리가 부족해지면 OOM Killer가 프로세스를 강제 종료할 수 있음. 이때 `qemu-system-*` 프로세스가 종료되면 해당 인스턴스도 같이 꺼질 수 있음.

따라서 인스턴스가 갑자기 종료됐다고 해서 바로 Nova 문제라고 판단하지 말고, `dmesg` 등의 커널 로그를 확인해 **OOM 발생 여부 등의 원인부터 확인해야 함.**
