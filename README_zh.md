# proofmark

[English](README.md) · **[在线站点与做完的页面 →](https://doc.tbusos.com/proofmark/)**

**九套设计语言给编程 agent 用，外加一道会把不合格产物打回来的验收检查。**

给编程 agent 的设计 skill，别人发的是提示词。这个仓发的是提示词，**加上检查提示词有没有被照做的那个东西**。

下面这个页面：结构检查过了，渲染视觉审计也过了，在浏览器里看完全正常。

```console
$ bin/design-review examples/looks-fine.html

━━ [1/5] verify.py (structural)
design-review verify: OK — 1 file(s) passed (auto-detected skill)

━━ [2/5] visual-audit.mjs (rendered + brand + italic + smell)
visual-audit: OK  (examples/looks-fine.html)

━━ [3/5] axe-audit.mjs (accessibility · axe-core)
axe-audit: 1 rule(s), 34 element(s)
  [error] color-contrast (serious) ×34 — Elements must meet minimum color contrast ratio thresholds
      .anth-hero > .anth-container > p > .lang-en
         Element has insufficient color contrast of 2.31 (foreground #a8a69c,
         background #faf9f5, font size 14.3pt, weight normal). Expected 4.5:1
      … and 33 more

✗ axe-audit found blocking violations — fix before continuing
$ echo $?
1
```

它和一张合格样张的差别只有两个颜色值，调到刚好不满足 4.5:1 为止。**看不出哪里不对**。这正是提示词管不住、人快速过一眼也会放过去的那一类。

## 九套

每一套都是完整的设计语言：字号阶梯、颜色 token、版面节奏、动效、图表画法，外加一批做好的参考页面，生成器拿它们当标尺。

| Skill | 声音 | 参考页数 |
|---|---|---|
| `anthropic-design` | 暖色杂志感。米色底、衬线正文、橙色重点 | 10 |
| `apple-design` | 产品营销式极简。白底、SF 字体、数字当标题 | 10 |
| `ember-design` | 手作感的暖。米色、巧克力棕、金 | 10 |
| `sage-design` | 北欧的安静。米色、鼠尾草绿、深靛 | 10 |
| `atelier-design` | 暖玻璃产品界面。九套里唯一画应用本身的，而且真的能点 | 6 |
| `glass-design` | 极光玻璃拟态。深藏青、磨砂面板、明暗双主题 | 4 |
| `eclat-design` | 发布会舞台，哑光电影底 | 3 |
| `lectern-design` | 会议室简报。纸白、衬线、数据前置 | 3 |
| `primer-design` | 技术图解。让图承载论证 | 3 |

一共 59 张参考样张，在 `skills/*/references/canonical/` 下。它们能独立打开，59 张全部能过检查链，所以生成器可以直接拿它们做标尺。

## 做完的页面

用这些 skill 做完、并且过了检查链的 26 张页面，在 `demos/` 下。

| | |
|---|---|
| 9 份图例库 | 每套设计语言一份。架构、流程、层次、时序波形、寄存器位域、SoC 框图、调用图、封包分层。每张图带一个 Copy SVG 按钮，能直接抠走。 |
| 6 篇技术长文 | [一个比特是怎么被存住的](https://doc.tbusos.com/proofmark/demos/anthropic-design/one-bit.html)、[一颗芯片怎么封装出来](https://doc.tbusos.com/proofmark/demos/anthropic-design/packaging.html)、[一张画面怎么到屏幕上](https://doc.tbusos.com/proofmark/demos/anthropic-design/hardware.html)，另有三篇。图是用来承载论证的，不是装饰。 |
| 10 页技术图解 | primer-design 的短页，一页讲一个机制：地址映射、互连拓扑、协议分层、寄存器解码、调度时序。 |

## 那道检查

`bin/design-review <page.html>` 按顺序跑五道，第一道不过就停。

| | 它判什么 |
|---|---|
| `verify.py` | 结构：占位符残留、缺 viewport、未定义的 class、BEM 修饰符缺基类、SVG 标签不配对、hero 容器宽度、已经有 token 却写死的颜色 |
| `visual-audit.mjs` | 渲染后的页面：对比度、品牌存在感、图表标签字号、孤立卡片、SVG 文字可读性、以及借用了别家调色板的颜色 |
| `axe-audit.mjs` | 可访问性，走 axe-core。四条规则阻断：`color-contrast`、`link-name`、`aria-prohibited-attr`、`svg-img-alt` |
| `interaction-audit.mjs` | 点开之后才存在的状态：控制台报错、点击之后才出现的 axe 违规、死控件、断锚点、新露出来压住别的内容。其余每一道判的都是同一个静止画面 |
| `screenshot.mjs` | 整页 PNG，留给人眼那一部分 |

`--pixel` 是第六道，拿渲染像素跟提交过的基线比。它是选配，因为**有意的改版和真正的回退一样会让它报错**。

口味另外判。`design-critic` 一个评审员看整页；也可以四个专家并行看——版式、文案、插画、品牌，权重 25/25/20/30。

## 告诉它这个项目定了什么

九套语言是通用的，用它们的项目不是：它写其中一套，它看过某些提示并决定就这样，
它想让某一类读者看懂某一件事。这些都猜不出来，所以没有它，**每次跑都在重新争
同样的 warning**，而口味评审判的是一个虚构记事本应用的样张。

`DESIGN.md`，放页面旁边或往上任一层：

```markdown
---
skill: anthropic
waivers:
  - check: interaction:broken-anchor
    reason: 这些是参考样张，链接指向一个真实产品站才会有的章节
    until: 2026-12-31
---

# 这个项目的设计决定

散文。评审读它，没有解析器读它。
```

豁免是**把 error 降成 warn，不是把它藏起来**——那条发现照样打出来，理由跟在下面。
三条规矩各有检查：理由必填且要写成句；`check` 必须是真实存在的 id，而 id 是从
检查器自己的源码里现读的，所以上游改名会在这里报错、不会让豁免安静地什么都不做；
`until` 过期就校验失败，逼你重新决定。**豁免了一条没触发的检查也会被报出来**，
因为那行字在骗下一个读者。

`DESIGN.md` 写坏了，整轮在第一道之前就停。它决定检查怎么做，半读半猜比直接拒绝更坏。

```bash
node skills/design-review/scripts/design-md.mjs --check DESIGN.md
```

## 让它不靠记性

五道跑一页 17-25 秒，因为三道要开浏览器。没人会每次改动都付这个代价，
于是实际情况是发布前才想起来跑一次 —— 而那正是结构问题最难改的时刻。

`verify.py` 不用浏览器，**0.05 秒**。所以 `hooks/design-gate/` 让它在每次写
HTML 时都跑，不过就把结果直接送回来。它同时记下这一版的内容哈希；
`bin/design-review` 五道全过时记同一个哈希，回合结束时 hook 报出
"哈希对不上任何一次通过运行"的文件。改了文件哈希就变，回执自动失效。

```bash
hooks/design-gate/install.sh --dry-run   # 先看它要改什么
hooks/design-gate/install.sh             # 写进 ~/.claude/settings.json
hooks/design-gate/selftest.sh            # 15 项自检
```

**它只拦一次然后清账。** 一个"条件不满足就一直不放行"的 hook，
在条件根本达不到时会一直不放行，记录里就是 hook 和模型互相重复。

## 它不判什么

这道检查只回答一个问题：**这一页有没有照着它声称的那套设计语言写**。它不回答页面好不好、内容对不对、读者能不能跟上论证。全部检查通过，和这一页该扔掉，两件事可以同时成立。

对比度、class 有没有定义、标签多大，这些有数值答案。版面留白是否用得其所没有，早几轮试着把它机械化，误报率高到那条检查没法用。

## 它怎么做到不重复犯错

`skills/design-review/references/known-bugs.md` 里有 93 条。每一条都是某次被评审员抓到的毛病。`design-learner` 把一次抓到变成两样东西：那个文件里的一行，以及只要机器能判，就在 `visual-audit.mjs` 里加一条新检查。93 条里配上了检查的那些，不再需要经过评审员。

## 装

```bash
npx github:TbusOS/proofmark install
```

十二个 skill、六个评审 agent、两个命令，放到 Claude Code 找得到的地方。
**不下浏览器，不装任何依赖**——设计语言是 markdown，读它们什么都不需要。
大约 13 秒。

**它不会覆盖不是自己装的东西。** 同名的 skill 已经在那儿（你自己的东西，
或者指向你自己库的链接），它会说出来然后让开。`--force` 才替换，
`--dir=<路径>` 装到别处，`--dry-run` 只看不动。

```bash
npx github:TbusOS/proofmark doctor      # 装了什么、缺什么
npx github:TbusOS/proofmark hook        # 接编辑触发的检查
npx github:TbusOS/proofmark uninstall   # 只删自己装的那些
```

检查那一半是单独的重活：要 Node、Python 3，还要下大约 150MB 的 Chromium，
而且得从 clone 出来的目录跑——它要在页面旁边写截图、读基线。

```bash
git clone https://github.com/TbusOS/proofmark.git
cd proofmark && npm run setup-gate
bin/design-review examples/looks-fine.html   # 退出码 1,本该如此
```

npm 上 `proofmark` 是别人的包，所以真要发布的话叫 `proofmark-design`。
上面那个 `npx github:` 写法不需要发布，而且永远跑 `main`。

## 上游

这些 skill 同时活在 [sky-skills](https://github.com/TbusOS/sky-skills) 里，跟内核和文档工具放在一起。那份是源，本仓单独拿出设计这一半，好让人不用装其余部分。`bin/sync-from-upstream.sh --check` 会报出两边的差异。

MIT。
