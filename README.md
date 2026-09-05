# Cloud Club 10기 — OpenStack 스터디 시즌1

> 퍼블릭 클라우드 뒤에는 뭐가 있을까.
> 이론으로 이해하고, 가비아 클라우드 VM 위에 Kolla-Ansible로 OpenStack을 직접 배포해서, 인스턴스에 SSH 접속하기까지 — 8주.

- 기간: 2026.08.31 ~ 10.19 (매주 월요일 22:00, 온라인 60분) · 시즌1 발표 10/24(토)
- 인원: 리더 포함 10명 · 1인 1 VM (가비아 클라우드, Ubuntu 24.04)
- 스택: Kolla-Ansible 22.0.0 · OpenStack 2026.1 Gazpacho · all-in-one · ML2/OVS
- 최종 목표: 내가 배포한 OpenStack의 인스턴스에 `ssh cirros@<Floating IP>`

## 8주 뒤 우리가 만드는 것

```
[가비아 클라우드 VM (Ubuntu 24.04)]              ← 3회차에 접속
   └── Docker 컨테이너 30개 = OpenStack           ← 5회차에 배포
        └── OpenStack이 만든 인스턴스              ← 6회차에 기동, SSH
```

## 일정

| 회차 | 날짜 | 내용 |
| --- | --- | --- |
| 1 | 8/31 (월) | 킥오프 — 여정 소개, 운영 규칙 합의 |
| 2 | 9/7 (월) | OpenStack 아키텍처 — 컴포넌트 6가지 ↔ AWS |
| 3 | 9/14 (월) | "버튼 뒤의 6단계" + 배포받은 VM에 SSH 접속·검증 |
| 4 | 9/21 (월) | 추석 전 라이트 — `setup.sh` 실행 |
| 5 | 9/28 (월) | deploy 데이 — pull → deploy, `docker ps`로 구조 읽기 |
| 6 | **10/6 (화)** | 인스턴스 생성 → Floating IP → SSH + netns로 라우터 실체 보기 |
| 7 | 10/12 (월) | 버퍼 — 미완주자 구제 + 심화(로그로 6단계 추적) |
| 8 | 10/19 (월) | KPT 회고 + 발표 자료 제작 |
| 발표 | 10/24 (토) | 시즌2 팀빌딩에서 시즌1 발표 |

6회차만 화요일 (10/5 대체공휴일). 유일한 예외.

## 자료 지도

| 경로 | 내용 |
| --- | --- |
| `weeks/weekNN/` | 회차별 예습 자료 · 세션 자료 · 세션 기록 |
| `docs/rules.md` | 1회차에 합의한 운영 규칙 |
| `docs/kolla-deploy.md` | Kolla-Ansible 배포 절차 (가비아 VM · OVS) — `setup.sh`/`init.sh`가 하는 일의 설명서 |
| `docs/leader-study-notes.md` | 스터디장 공부 노트 공유본 (참고용) |
| `scripts/` | `setup.sh` (4회차) · `init.sh` (6회차) — 리더가 검증 후 공개 |
| `members/<github-id>/` | 참가자 주차별 정리 (PR로 제출) |
| `issue/` | 트러블슈팅 내용 정리 |

## 참여 방법

- **예습**: 주초에 `weeks/weekNN/prestudy-*.md`와 "알고 오기" 질문을 톡방에 공지. Part A(필수) + Part B(심화)
- **인증**: 매주 완료 기준 스크린샷을 톡방에, 다음 세션 전까지
- **주차별 정리**: `members/<본인 github id>/weekNN.md`로 PR → [PR 템플릿](https://github.com/cloud-club/template/tree/main/PR)
- **트러블슈팅**: 막혔던 지점은 `issue/weekNN-증상.md`로 정리 → [ISSUE 템플릿](https://github.com/cloud-club/template/tree/main/ISSUE)

