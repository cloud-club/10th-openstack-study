#!/usr/bin/env bash
# chaos.sh — 7회차 장애 주입/복구 스크립트 (리더 VM에서 실행)
#
#   ./chaos.sh break <시나리오|random> [이름]   장애 주입 (이름 생략 시 전원)
#   ./chaos.sh heal [이름]                      전부 원복 (멱등, 여러 번 돌려도 안전)
#   ./chaos.sh status [이름]                    죽은 컨테이너 확인
#
# 시나리오: keystone | scheduler | ovs_agent | quota | sg22
# hosts.txt 형식: 이름 IP   (한 줄에 하나, # 주석 가능)

set -uo pipefail

HOSTS_FILE="${HOSTS_FILE:-./hosts.txt}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
SSH_USER="${SSH_USER:-root}"
ANSWERS="./answers.log"

SCENARIOS=(keystone scheduler ovs_agent quota sg22)
RANDOM_POOL=(scheduler ovs_agent quota)   # random일 때 뽑을 후보

SSH_OPTS=(-i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new)

# ---------- 참가자 VM에서 실행될 코드 ----------
read -r -d '' REMOTE <<'EOF'
set -u
S=""; [ "$(id -u)" -ne 0 ] && S="sudo"
# Kolla는 컨테이너를 systemd 유닛으로 관리 → docker stop은 바로 재시작됨
svc() { $S systemctl "$1" "kolla-$2-container.service"; }
os() { ( source ~/kolla-venv/bin/activate && source /etc/kolla/admin-openrc.sh && openstack "$@" ); }
default_sg() { os security group list --project admin -f value -c ID -c Name | awk '$2=="default"{print $1; exit}'; }

case "$ACTION:$SCN" in
  break:keystone)  svc stop keystone ;;
  break:scheduler) svc stop nova_scheduler ;;
  break:ovs_agent) svc stop neutron_openvswitch_agent ;;
  break:quota)     os quota set --instances 0 admin ;;
  break:sg22)
    SG=$(default_sg)
    for R in $(os security group rule list "$SG" --ingress --protocol tcp -f value -c ID -c "Port Range" | awk '$2=="22:22"{print $1}'); do
      os security group rule delete "$R"
    done ;;
  heal:*)
    for C in keystone nova_scheduler neutron_openvswitch_agent; do svc start "$C"; done
    # keystone이 다시 토큰을 줄 때까지 대기 (최대 60초)
    for _ in $(seq 1 20); do os token issue >/dev/null 2>&1 && break; sleep 3; done
    os quota set --instances 10 admin
    SG=$(default_sg)
    os security group rule create --ingress --protocol tcp --dst-port 22 "$SG" >/dev/null 2>&1 || true
    echo "healed" ;;
  status:*)
    echo "exited: $($S docker ps -a --filter status=exited --format '{{.Names}}' | tr '\n' ' ')" ;;
esac
EOF
# ---------------------------------------------

usage() { sed -n '3,9p' "$0"; exit 1; }

run() {
  local name=$1 ip=$2 action=$3 scn=$4
  if ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "ACTION=$action SCN=$scn bash -s" <<<"$REMOTE" > "logs/$name.log" 2>&1; then
    echo "[OK]  $name"
  else
    echo "[ERR] $name  (logs/$name.log 확인)"
  fi
  [ "$action" = status ] && sed "s/^/      /" "logs/$name.log"
}

ACTION=${1:-}; [ -z "$ACTION" ] && usage
mkdir -p logs
mapfile -t HOSTS < <(grep -vE '^\s*(#|$)' "$HOSTS_FILE")

case "$ACTION" in
  break)
    ARG=${2:-}; TARGET=${3:-}
    [[ " ${SCENARIOS[*]} random " == *" $ARG "* ]] || usage
    pool=()
    if [ "$ARG" = random ]; then
      while [ ${#pool[@]} -lt ${#HOSTS[@]} ]; do pool+=($(printf '%s\n' "${RANDOM_POOL[@]}" | shuf)); done
    fi
    echo "# $(date '+%F %T') break $ARG ${TARGET}" >> "$ANSWERS"
    i=0
    for line in "${HOSTS[@]}"; do
      read -r name ip <<<"$line"
      scn=$ARG; [ "$ARG" = random ] && scn=${pool[$i]}; i=$((i+1))
      [ -n "$TARGET" ] && [ "$name" != "$TARGET" ] && continue
      echo "$name $ip $scn" >> "$ANSWERS"
      run "$name" "$ip" break "$scn" &
    done
    wait
    echo "정답은 $ANSWERS 에 기록됨 — 화면 공유 중엔 열지 말 것" ;;
  heal|status)
    TARGET=${2:-}
    for line in "${HOSTS[@]}"; do
      read -r name ip <<<"$line"
      [ -n "$TARGET" ] && [ "$name" != "$TARGET" ] && continue
      run "$name" "$ip" "$ACTION" - &
    done
    wait ;;
  *) usage ;;
esac
