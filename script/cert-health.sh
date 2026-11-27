#!/usr/bin/env bash
# 证书健康检查: (1) 每张 LE 证书剩余天数; (2) 每个域名 443 上服务的证书
# 是否就是 live/ 下的那张; (3) nginx 配置能否通过 -t。
#
# 安装(在 nginx 所在机器上,root):
#   sudo install -m 755 script/cert-health.sh /usr/local/bin/cert-health
#   sudo systemd-analyze verify 之后用 timer 每天跑一次(cert-health.timer)。
# 退出码: 0 = 全部正常; 1 = 有问题(写 /var/log/cert-health.log,systemd 单元失败)。
set -uo pipefail

LOG=/var/log/cert-health.log
WARN_DAYS=${WARN_DAYS:-20}
log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG"; }

rc=0
now=$(date +%s)

# 1) nginx 配置
if ! nginx -t >/dev/null 2>&1; then
    log "FAIL nginx -t 不通过"
    rc=1
fi

# 2) 每张证书
for cif in /etc/letsencrypt/live/*/fullchain.pem; do
    [ -r "$cif" ] || continue
    name=$(basename "$(dirname "$cif")")
    end=$(openssl x509 -in "$cif" -noout -enddate | cut -d= -f2)
    left=$(( ( $(date -d "$end" +%s) - now ) / 86400 ))
    if [ "$left" -lt "$WARN_DAYS" ]; then
        log "FAIL $name 剩余 ${left} 天(<${WARN_DAYS}),续期可能失败了"
        rc=1
    fi

    # 3) 线上一致性(按 SNI 逐个域名比对指纹)
    want=$(openssl x509 -in "$cif" -noout -fingerprint -sha256 | sed 's/^.*=//')
    for d in $(openssl x509 -in "$cif" -noout -ext subjectAltName 2>/dev/null \
            | grep -o 'DNS:[^,[:space:]]*' | cut -d: -f2); do
        served=$(echo | openssl s_client -connect 127.0.0.1:443 -servername "$d" 2>/dev/null \
            | openssl x509 -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//')
        if [ -z "$served" ]; then
            log "FAIL $d 无法从 443 取到证书"
            rc=1
        elif [ "$served" != "$want" ]; then
            log "FAIL $d 线上证书不是 $name 那张(证书没 reload 或配置没指向它)"
            rc=1
        fi
    done
done

if [ "$rc" -eq 0 ]; then
    log "OK 全部证书 >= ${WARN_DAYS} 天且线上一致"
fi
exit "$rc"
