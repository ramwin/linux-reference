# 把外接盘上的 PT 种子恢复到 NAS 的 qBittorrent

场景：台式机上做种的 16T 盘（NTFS，一次性从旧客户端导出了 137 个种子的
`manifest.csv` / `magnets.txt` / `torrents/*.torrent` 到 `_qbt_import/`）插到 NAS 上，
要把这 137 个种子在 NAS 的 qBittorrent 里重新做种。

结论先行：**能恢复，但不能直接 `add` 完就完事**。实测 137 个里 82 个真正恢复做种、
6 个通过「重新指向实际目录」救回、40 个 m-team 种子必须重下 `.torrent`、
11 个种子对应的文件已不存在或被打散重整。

## 一、五个踩点

### 1. 容器里根本看不到外接盘

NAS 上 qBittorrent 是 linuxserver 镜像的容器（`--network host`，WebUI 直接听 8080），
挂载只有 `/config` 和 `/downloads`；UGOS 自动挂载的外接盘在
`/mnt/@usb/sdX` 这类路径上，容器里看不到。

宿主机 `mount | grep @usb` 显示 NTFS 是 **`fuseblk`**（ntfs-3g），这点很关键，见第 2 点。

Docker 不支持给已有容器加挂载，只能重建。先留底再重建（配置在
`/volume1/pt/开源qbittorrent配置文件`，重建不丢种子）：

```bash
docker inspect <容器名> > /volume1/pt/qbt-container-config-$(date +%Y%m%d).json
docker stop <容器名>
docker rename <容器名> <容器名>-backup
docker update --restart=no <容器名>-backup    # 否则开机它也会起，两个容器抢 8080
docker run -d --name <容器名> --network host --restart always \
  -e PUID=1000 -e PGID=10 \
  -v "/volume1/pt/开源qbittorrent配置文件:/config" \
  -v /volume1/pt:/downloads \
  -v /mnt/@usb/sde2:/downloads2 \
  linuxserver/qbittorrent:latest
```

### 2. NTFS 上全量哈希校验慢到不能用

qbt 加种子默认要校验一遍。这盘 4.7TB、走 ntfs-3g（fuseblk），3 个并发校验时
`iostat` 只有 **~24MB/s、`%util` 100%、load 9+**（随机读被 FUSE 放大）。
按这个速度全量校验要几十小时。

替代方案：**文件存在 + 大小精确匹配**的稽核（只 `stat`，几分钟跑完 4.7TB 的文件清单），
全对就用 `skip_checking=true` 挂回去，立刻算完成、立刻做种。对「同一块物理盘搬来」的场景
这个近似足够；真要逐字节校验，挑空闲时段单独 recheck 即可。

### 3. 导出包里的 `.torrent` 没有 announce

`torrents/*.torrent` 只有 `info` 段，没有 `announce` / `announce-list`——
导包时把 tracker（含 passkey）剥掉了。种子加进去后 qbt 的 tracker 列表里
只有 `** [DHT] **` / `** [PeX] **` / `** [LSD] **`（私有种子全部禁用），
`tracker` 字段为空 → 不 announce → **做种等于白做**（PT 记不到上传量）。

补救办法：`.torrent` 的 `info` 里有 **`source`** 字段带着站点标识，例如：

```python
# info.source 形如 "[pt.sjtu.edu.cn] 葡萄" / "[pt.btschool.club] ..." / "[kp.m-team.cc] ..."
```

按 source 分组后，从 NAS 上**已有做种**的种子里取同站 announce URL（passkey 就在 URL 里），
逐个补：

```bash
curl -s -b cookie.txt --data-urlencode "hash=<info_hash>" \
     --data-urlencode "urls=https://tracker.<站>/announce.php?passkey=<你的passkey>" \
     'http://<NAS>:8080/api/v2/torrents/addTrackers'
```

补完用 `/api/v2/torrents/trackers?hash=` 看 `status`：`2` = working（已 announce 成功）。

**m-team 是例外**：它的 announce 是
`https://tracker.m-team.cc/announce?credential=<base64(sign=…&t=…&tid=…&uid=…)>`，
`tid` 每个种子不同、`sign` 由站点签名，**无法仿造**，只能回站点重新下载 `.torrent`。
（葡萄 / BTSchool / CarPT 都是 `announce.php?passkey=<固定值>`，可以补。）

### 4. qBittorrent 5.2 的 WebUI API 改名了

| 动作 | 4.x | 5.2（实测 5.2.3） |
| --- | --- | --- |
| 恢复做种 | `/api/v2/torrents/resume` | **`/api/v2/torrents/start`**（`resume` 返回 404 端点不存在） |
| 暂停 | `/api/v2/torrents/pause` | **`/api/v2/torrents/stop`** |
| 登录成功 | 200 + body `Ok.` | **204 + 空 body**（判断成功别看 body） |
| 加种子返回 | `Ok.` | **JSON**：`{"success_count":1,"failure_count":0,"added_torrent_ids":[...]}` |

另外 404 的响应体是中文「端点不存在」，一开始容易误判成登录被 ban。

### 5. 一部分种子的文件被打散重整过

盘上有些内容后来被整理成「一部片一个目录」（Jellyfin 库风格），种子里记录的却是
`根目录/xxx.mkv`。这种种子无论 `save_path` 指哪都对不上，只能：
重新下载，或者放弃原来的种子改用新结构重建。

能救的是「整体换了个根目录名、内部结构没变」的情况——用
`contentLayout=NoSubfolder` + 指向**包含这些文件的目录**即可：

```bash
# 种子里是 [HorribleSubs] One Piece (01-700).../[HorribleSubs] One Piece - 352.mkv
# 盘上是 动画/海贼王/[HorribleSubs] One Piece - 352.mkv
# -> savepath=/downloads2/动画/海贼王 且 contentLayout=NoSubfolder（去掉种子里那层根目录）
```

## 二、完整流程（可复用）

```bash
# 0) 前置：容器挂上外接盘（见第一节第 1 点）
# 1) 稽核：manifest.csv 的每行 -> qbt 里对应种子的文件清单 -> 盘上逐个 stat
python3 qbt_audit.py            # 输出 /volume1/pt/qbt_audit.json，verdict=ok / incomplete
# 2) 重挂稽核通过的：删掉（不删文件）+ 以 skip_checking 重新加 + start
python3 qbt_readd.py
# 3) 按 info.source 补 announce
python3 fix_trackers.py
# 4) 对残缺的：在盘上找真实落点，全文件 stat 通过就用 NoSubfolder 重挂
python3 qbt_index.py && python3 qbt_remap.py
# 5) 验收
#    /api/v2/torrents/info 里 progress=1 且 state=stalledUP/uploading
#    /api/v2/torrents/trackers?hash= 里 status=2
```

脚本（都在 NAS 的 `/volume1/pt/`，纯标准库，不依赖 `qbittorrent-api`）：
`qbt_import_all.py`（批量加种子）、`qbt_audit.py`（文件稽核）、`qbt_readd.py`（重挂）、
`qbt_index.py`（盘上文件名索引）、`qbt_remap.py`（残缺种子重定位）、`fix_trackers.py`（补 tracker）。

只用标准库的原因：NAS 上没有 `qbittorrent-api`，装它要连外网 pip；multipart 手搓二十行就够。
另外 `torrents/add` 的 `paused` 在 5.x 仍被接受，但保险起见 `paused` 和 `stopped` 一起发。

## 三、这次的实际结果

- 137 个种子里 133 个是新加的（4 个 NAS 上早已在做种）。
- **82 个真正恢复**（葡萄 42 / BTSchool 31 / CarPT 9），progress=1、announce status=2，合计约 3.3TB。
- **40 个 m-team 种子**挂上了但补不了 announce，需要回站点重新下载 `.torrent` 再导入。
- **11 个没能恢复**：文件已不存在，或被打散进单片目录（结构对不上）。
- 未恢复的**不会**自动下载，不会偷偷占盘。

## 版本记录

- v1（2026-11-14）：首次整理。现场：16T NTFS 盘插回绿联 NAS，
  把 `_qbt_import/` 的 137 个 PT 种子恢复到 NAS 的 qBittorrent 5.2.3。
  使用模型 DeepSeek（deepseek-flash），本次会话约 20 万 tokens。
