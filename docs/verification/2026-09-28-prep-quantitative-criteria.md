# PREP / PREHEAT：可以核对的判据，每条都有出处

Verified on 2026-09-28 with Xcode 26.2 / Swift 6.2, iOS 26.2, one iPhone 17
simulator, English and Simplified Chinese.

## 改了什么

**只改文案，时间模型未动。** 改动文件只有 `CookingSessionView.swift`（PREP/PREHEAT
的标题与说明行）、`Localizable.xcstrings`（六条中文）、以及中文 UI 测试的两个断言 +
截图；`CookingEngine`、`CookingProfile`、`Config/production.yaml` 均未出现。

| 屏幕 | 状态 | 标题 | 说明行 |
| --- | --- | --- | --- |
| PREP | 未擦干 | 擦干每一面 | 用厨房纸按到不出湿痕：表面水没汽化完，几乎不会上色。 |
| PREP | 已擦干、未撒盐 | 两面调味 | 有条件就提前约 40 分钟撒盐：盐先析出水分，表面随后回干。 |
| PREP | 两步都完成 | 可以预热锅了 | 时间估算按下锅时中心 20°C 为前提；刚从冰箱取出会偏生。 |
| PREHEAT | — | 等到水珠打转 | 嘶嘶蒸发只说明锅过了 100°C；水珠打转、悬浮不沸腾才是够热，肉也不容易粘锅。 |

原来的两句（`A dry surface gives you a deeper, faster crust.` 与
`Oil should shimmer and the steak should sizzle immediately on contact.`）都不再出现在
界面里；它们只是形容词，没有可核对的判据，也没有出处。旧词条留在词表里（Xcode 会把它
标成 stale），`LocalizationTests` 仍在断言其中一条，所以没有删除。

## 出处

| 判据 | 出处 | 原文关键句 |
| --- | --- | --- |
| 擦干：厨房纸按到不出湿痕；表面水没汽化完几乎不上色 | [Hawaii Tribune-Herald，转述 J. Kenji López-Alt 的实测与能量分析](https://www.hawaiitribune-herald.com/2019/02/19/features/lets-talk-food-steaks-at-room-temperature-or-not/) | "What really matters is **how dry the steak is**. Simply **blotting your steak with paper towels** … will improve it far better than any amount of room temperature resting."；"Until the temperature rises to 212 degrees, no evaporation occurs, and **until most of the surface moisture has evaporated, very little browning occurs**." |
| 盐：约提前 40 分钟 | 同上 | "salting the steak about **40 minutes in advance** — long enough to let salt draw out liquid and then for that liquid to be re-absorbed leaving a **dryer surface**" |
| 锅够热：水珠要悬浮打转，不是嘶嘶蒸发 | [Mathijssen et al., *Culinary fluid mechanics and other currents in food science*, Rev. Mod. Phys. **95**, 025004 (2023), §V.2；arXiv:2201.12128v2](https://arxiv.org/abs/2201.12128) | "a simple way to assess whether the frying pan is sufficiently hot is to sprinkle a handful of water droplets onto it. When the surface temperature **slightly exceeds the water boiling point**, the droplets start vigorously evaporating, producing a **sizzling sound**. However, if the pan … becomes **considerably hotter**, small droplets … start **levitating above the hot surface without boiling**."；"This levitation can help with **preventing the meat from sticking**." |

说明行里出现的三个数字都是这样来的：**212°F≈100°C** 是上表第一句里的"水的沸点"；
**40 分钟**直接来自第二句；**100°C** 同样来自第三句（"slightly exceeds the water
boiling point"）。20°C 见下。

## 因为查不到出处，所以刻意没有写进界面

| 参数 | 尝试过且失败的来源 |
| --- | --- |
| 盐量 0.5–1% 肉重 | Serious Eats → HTTP 402 付费墙；AmazingRibs → 403 Cloudflare；[SHAREOK 上那篇牛外脊盐分渗透学位论文](https://shareok.org/handle/11244/20997) → Angular SPA，OAI 端点只回前端 HTML；K-State 报告 PDF 是扫描件、无文本层 |
| 锅面 200–230°C（"最佳区间"） | 只能引到[被研究过的锅温档位：120/160/180/200/220°C](https://www.jstage.jst.go.jp/article/jhej1987/50/2/50_2_147/_article/-char/en)，该文只说"锅温强烈影响表面颜色、存在良好上色时间窗"，没有给出最佳值 |
| Leidenfrost ≈190°C | 综述只给"远高于沸点"的定性描述，没有数字 |
| Maillard 起始 ≈140–165°C | 综述有引文编号但正文没给温度；相关学校 PDF 已迁移、跳转被拒 |
| 油量 5–8 g / 1 茶匙 | 无可引用来源 |
| 铸铁锅空烧 4–6 分钟 | 无可引用来源 |

另外几个环境层面的原因，也记在这里：Wikipedia 在本机 DNS 解析到非公网地址（工具直接
拒绝）；fsis.usda.gov / foodsafety.gov / fda.gov 都是 JS 渲染，取不到正文。所以**官方
"室温不超过 2 小时"那条也没有写进界面**。

## 被来源反证、因此撤回的一条

先前提出的「回温 15 分钟/厘米、必须回温」在同一篇里被实测反证：厚切西冷从冰箱取出后
**20 分钟中心升不到 2°F**、**整整 2 小时也只升约 10°F**；作者另测 3/4 英寸牛排中心回到
室温要一个多小时、3⅓ 英寸猪肩要 10 小时。原文结论是"起锅温度影响可忽略，干爽才是关键"。
所以 PREP 里**没有**加回温倒计时。

## 保留的、属于本项目自己的前提

第三步说明行里的 **20°C** 不是外部文献，而是本项目 `Config/production.yaml` 的
`thermal.initialCentreTemperatureC: 20`——时间估算就是按它标定的。写出来的目的是让"刚从
冰箱拿出来"这件事不至于悄悄让估算偏短。它是一句**前提说明**，不是操作指令。

## 测试

按改动范围只跑了三个，没有跑全量：

| 测试 | 覆盖 |
| --- | --- |
| `-only-testing:SteakCopilotTests/LocalizationTests` | 编译后的 `zh-Hans` 包能解析（新增六条中文都已进包，用 `plutil` 复核过） |
| `-only-testing:.../testStageControlsSkipEveryStageAndExitToSetup` | PREP 与 PREHEAT 两屏真实渲染，产出英文截图 |
| `-only-testing:.../testSimplifiedChineseFollowsSystemLanguage` | 中文下逐步断言：两面调味 → 40 分钟说明 → 可以预热锅了 → 20°C 前提，并各留一张截图 |

没有跑全量套件的理由：这次只改文案与词表，不触碰引擎、排期或布局常量；两屏的固定槽高度
也没有变（说明行仍是预留的那一行，英文最长的一句恰好两行，见截图）。

## 截图

`docs/verification/screenshots/prep-criteria/`：

- `prep-dry-en.png` — PREP 第一步（英文，说明行两行）；
- `prep-salt-zh.png` — PREP 第二步「两面调味」+ 40 分钟说明（中文，一行）；
- `prep-ready-zh.png` — PREP 第三步「可以预热锅了」+ 20°C 前提（中文，一行，CTA 已可用）；
- `preheat-en.png` — PREHEAT「Wait until droplets dance」+ 水珠判据（英文，两行）。

全部由 UI 测试自动产出，不是手工拼的。
