#!/usr/bin/env bash
# certbot 续期后置钩子(deploy hook): 重载 nginx,并校验线上真的换成了新证书。
#
# 安装(在 nginx 所在机器上,root):
#   sudo install -m 755 script/certbot-reload-nginx.sh \
#        /etc/letsencrypt/renewal-hooks/deploy/50-reload-nginx.sh
# 触发: certbot renew 真正续期成功后自动执行(--dry-run 默认不跑 deploy hook)。
# 退出码非 0 时 certbot 会记错误、systemd 单元标记失败,便于发现"续期成功但没生效"。
set -uo pipefail

LOG=/var/log/certbot-deploy-nginx.log
log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG"; }

lineage="${RENEWED_LINEAGE:-}"
domains="${RENEWED_DOMAINS:-}"
log "== trigger lineage=${lineage:-?} domains=${domains:-?}"

# 1) 配置语法不过关就不要 reload(否则可能把线上 master 带坏)
tmp=$(mktemp)
if ! nginx -t >"$tmp" 2>&1; then
    log "!! nginx -t 失败,跳过 reload"
    sed 's/^/   /' "$tmp" >>"$LOG"
    rm -f "$tmp"
    exit 1
fi
rm -f "$tmp"

# 2) reload: 失败时 nginx 继续跑旧配置,访问不中断,但这里要报错
if ! systemctl reload nginx; then
    log "!! systemctl reload nginx 失败"
    exit 1
fi
log "reload nginx ok"

# 3) 校验: 每个续期域名在 443 上实际服务的证书必须等于 live/ 下的新证书
#    (按 SNI 命中本地 443,不需要改 DNS/走公网)
rc=0
for d in $domains; do
    served=$(echo | openssl s_client -connect 127.0.0.1:443 -servername "$d" 2>/dev/null \
        | openssl x509 -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//')
    if [ -z "$served" ]; then
        log "!! $d 无法从 127.0.0.1:443 取到证书"
        rc=1
        continue
    fi
    if [ -n "$lineage" ] && [ -r "$lineage/fullchain.pem" ]; then
        want=$(openssl x509 -in "$lineage/fullchain.pem" -noout -fingerprint -sha256 | sed 's/^.*=//')
        if [ "$served" = "$want" ]; then
            log "ok  $d 线上已生效 ${served:0:20}"
        else
            log "!! $d 线上证书与 $lineage 不一致 (served=${served:0:20} want=${want:0:20})"
            rc=1
        fi
    fi
done

[ "$rc" -eq 0 ] && log "== done ok"
exit "$rc"
