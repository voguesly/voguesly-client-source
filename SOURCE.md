# 易联 Voguesly 客户端 · 源代码 / Corresponding Source

本仓库提供易联(Voguesly)客户端**已发布版本**的对应源代码,以履行 GNU GPL v3 授权义务。
This repository provides the Corresponding Source for released builds of the Voguesly client, as required by the GNU General Public License v3.

| 发布版本 Release | 对应源码 Source | 发布日期 Date |
|---|---|---|
| 0.9.99 (`0.9.99+2026101301`) | 本仓库 tag `v0.9.99` | 2026-10-13 |
| 0.9.98 (`0.9.98+2026100602`) | 本仓库 tag `v0.9.98` | 2026-10-06 |
| 0.9.97 (`0.9.97+2026100101`) | 本仓库 tag `v0.9.97` | 2026-10-01 |

## 来源 Upstream
- 客户端基于 **FlClash**(作者 chen08209,GPL-3.0):https://github.com/chen08209/FlClash
- 内核基于 **mihomo**(MetaCubeX,GPL-3.0)。本版本所用内核改动已公开于 https://github.com/kisssam6886/Clash.Meta/commit/4a78ebc39f6e1fdb04b82c28606c9fcaede6a71b ,并同时收录在本仓库 `core/Clash.Meta/`。
  - 本版本另在 `core/third_party/sing-tun/`(sing-tun v0.4.24 副本,已加 Windows 诊断日志钩子)以 `replace` 指令引入,来源 https://github.com/metacubex/sing-tun 。
- 打包插件 `plugins/flutter_distributor`(chen08209 fork)收录于本仓库。

## 授权 License
本仓库代码以 **GPL-3.0** 授权(见 `LICENSE`),各上游项目版权归原作者所有。
This code is licensed under GPL-3.0 (see `LICENSE`). Upstream copyrights belong to their respective authors.

## 品牌 Trademarks
「易联」「Voguesly」名称及标志不随 GPL 授权提供;再发行修改版本请使用自己的名称与标志。
The names "易联" / "Voguesly" and their logos are not licensed under the GPL. If you redistribute a modified version, please use your own name and logo.

## 说明 Notes
- 仅收录编译所需源码与构建脚本;内部开发文档不属于对应源码,未收录。
- 测试数据与代码注释中的客户标识、示例凭据已做脱敏替换(不影响编译产物)。
- 构建方式参见 `README.md` 与 `.github/workflows/build.yaml`(签名、发布所需的密钥不在本仓库)。
