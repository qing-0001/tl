# EM Toggle「关闭 IMS」失败调试记录（2026-11-16）

## 环境

| 项目 | 值 |
|---|---|
| 项目/机型 | Claro MLD-NX3（device=HNMLD-M1） |
| Build | MLD-NX3-Claro-16-261110V94 |
| Modem | MOLY.NR17.R2.MP2.RC.MP.V45.10.P5（两 slot 相同） |
| SIM | SIM1：中国电信 NR SA（PLMN 46011），phoneId=0 / subId=3 |

## 现象

EM Toggle APK 点击「关闭 IMS」失败；同界面的 SAR 按钮也失败。

## 结论

1. **不是 APK 权限 / UID / slot 问题，也不是 RIL 未转发。**
   `AT+EIMSTESTMODE=1` 已经过 `MtkPhoneIntfMgrEx` → `RpOemCtlr.onHandleOemHookRaw` → AT 通道 0（RIL_CMD_READER_1），modem 返回裸 ERROR（OEM_HOOK_RAW ret 字节 = `"\r\nERROR\r\n"`）。
2. **ATCI 直连验证（绕过 APP/RIL）。**
   通过 `/dev/socket/adb_atci_socket` 直连 modem：`AT+CGMR`、`AT+CPIN?` 正常，但 `AT+EIMSTESTMODE=1 / =0 / =?` 全部 ERROR；飞行模式下同样失败，与 IMS 注册状态无关。
3. **决定性证据：`AT+CLAC` 全量 1042 条命令表中不含 `AT+EIMSTESTMODE`**（也不含 `AT+TASARCRL`）；`AT+EIMSCFG` 等其余 EIMS 命令均正常。说明当前 modem 固件未注册该命令（`md1img` 里的字符串只是残留，运行时不可用）。
4. **APK 无 bug。** APK 与 MTK 官方 `EngineerMode.apk` 使用的是同一条 `AT+EIMSTESTMODE=1/0`。
5. **SAR 按钮失败是另一个原因。** RIL 的 `RmmOemHandler` 白名单拒绝转发 `AT+TASARCRL`（`OEM_HOOK_RAW not send ... fail`），详见日志摘录。

## 建议（尚未执行）

- 请 MTK / 项目在 modem 侧放开 `AT+EIMSTESTMODE`（随附 modem 版本 + CLAC 证据）。
- 或 APK 改走框架 IMS 接口 / 其他受支持的私有命令。
- SAR 可评估 `AT+ERFTASARENABLE`（语义待 MTK 确认；该命令在 CLAC 表中存在）。

## 日志中的额外观察（待确认）

EmToggle 同时下发的 `AT+EIWLCFGSET="ipol_ims_md_supporting_rat","0"/"65"` 也全部失败，是否与 `EIMSTESTMODE` 属同一根因（命令/参数不受支持）仍需进一步确认。

## 证据文件

| 文件 | 说明 |
|---|---|
| `evidence/clac.txt` | `AT+CLAC` 全量输出（1042 行），证明 `AT+EIMSTESTMODE` / `AT+TASARCRL` 未注册 |
| `evidence/clac_eims_grep.txt` | CLAC 中 EIMS / TASAR 相关命令检索结果（含缺失结论） |
| `evidence/telreg.txt` | telephony registry dump（已确认不含 IMSI / ICCID / IMEI 等标识） |
| `evidence/radio_log_tasarctl_excerpt.txt` | radio log：`AT+TASARCRL` 经 MtkRILJ → RpOemCtlr → RmmOemHandler 被拒的完整链路 |
| `evidence/main_log_emtoggle_excerpt.txt` | main log：EmToggle AT 收发及 `MtkPhoneIntfMgrEx` 回调 |
| `evidence/device_info.txt` | 设备 / 版本信息 |

## 说明

- 完整 mobilelog 约 1.3 GB（含 modem log），因体积原因未入库，仅保留相关文本摘录。
- 设备已恢复原状：飞行模式关闭、`atcid-daemon-u` 已停止、语音 / 数据 IN_SERVICE（中国电信 NR SA / 46011）。