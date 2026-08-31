# scripts

- `setup.sh` — 4회차. 환경 점검 → 패키지 → hosts/sysctl → veth → venv → /etc/kolla → bootstrap → prechecks → `READY ✅`
- `init.sh` — 6회차. deploy 확인 → post-deploy → br-ex 게이트웨이·NAT → 네트워크·라우터·이미지·플레이버·보안그룹 → `INIT`

리더의 리허설(신규 VM 2회 완주) 통과 후 이 폴더에 공개됩니다. 무엇을 하는지는 [docs/kolla-deploy.md](../docs/kolla-deploy.md) 참고.
