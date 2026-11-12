# 在 macOS 14 Sonoma + iPhone (iOS 26) 上安装本 App

> 适用场景：Mac 无法升级到 macOS 26（装不了 Xcode 26），但 iPhone 已是 iOS 26。

## 一、为什么本机走不通

| 环节 | 现状 | 结果 |
| --- | --- | --- |
| Xcode 26 | 要求 macOS 26 | Sonoma 装不上 |
| Xcode 16.2（Sonoma 能装的最高版） | 自带 iOS 18 SDK | 无法部署到 iOS 26 设备，报 `unsupported OS` |

结论：**必须把「编译」搬到云端**。编译在云端完成，签名和安装仍在你的 Mac 上（不需要 Xcode）。

## 二、两条路，先看对比

| | 路线 A：GitHub 云编译 + 免费签名 | 路线 B：付费开发者账号 + TestFlight |
| --- | --- | --- |
| 花费 | 0 元 | ￥688 / 年 |
| 有效期 | **7 天**，到期需重签 | 90 天 / 版本，可续 |
| 需要电脑 | 是（重签时连 Mac） | 否，手机直接装 |
| App Group / 小组件共享数据 | ❌ 不可用 | ✅ 完整可用 |
| 适合 | 先试用、短期自用 | 长期日常使用 |

建议：**先用路线 A 把 App 跑起来验证效果**，确认好用再考虑路线 B。

---

## 三、路线 A 详细步骤

### 第 1 步：把代码放到 GitHub（约 5 分钟）

1. 打开 [github.com](https://github.com) 注册账号（免费）；
2. 右上角 `+` → **New repository** → 名称随意（如 `ganzhi-todo`）→ 选 **Private** → Create；
3. 进入新仓库，点 **uploading an existing file**；
4. 把 `/workspace/GanZhiTodo/` 里的**所有内容**拖进浏览器窗口。

> ⚠️ 关键细节：`.github` 是隐藏文件夹。在 Finder 里按 `Command + Shift + .` 让隐藏文件显示出来，确认 `.github` 也被一起上传了（它是云端编译的入口，缺了就点不了构建）。

5. 点 **Commit changes**。

### 第 2 步：云端编译（约 8 分钟，全自动）

1. 仓库顶部点 **Actions** 标签；
2. 左侧选 **Build IPA** → 右侧 **Run workflow** → 绿色按钮 **Run workflow**；
3. 等 5–10 分钟，出现绿勾即成功；
4. 点进这次运行记录，页面底部 **Artifacts** → 下载 `GanZhiTodo-unsigned-ipa`（一个 zip）；
5. 解压得到 `GanZhiTodo.ipa`。

> 如果报 `macos-26 not found`：把 `.github/workflows/build-ipa.yml` 里的 `runs-on: macos-26` 改成 `macos-15`，重新运行。

### 第 3 步：在 Mac 上签名安装（约 5 分钟）

1. 下载 [Sideloadly](https://sideloadly.io/)（选 macOS 版，需要 macOS 12+，你的 Sonoma 没问题）；
2. iPhone 用数据线连 Mac，手机上点「信任此电脑」；
3. 打开 Sideloadly：`IPA` 处拖入 `GanZhiTodo.ipa`，`Apple ID` 填你的 Apple ID；
4. 点 **Start**，输入 Apple ID 密码。
   - 若提示需要专用密码：登录 [appleid.apple.com](https://appleid.apple.com) → 登录与安全 → App 专用密码 → 生成一个，填到 Sideloadly；
5. 进度到 100% 即安装完成。

### 第 4 步：iPhone 上允许运行

1. 打开 App，若提示「未受信任的开发者」：
   `设置 → 通用 → VPN 与设备管理 → 开发者 App → 你的 Apple ID → 信任`；
2. **iOS 16 及以上必须开启开发者模式**，否则 App 闪退：
   `设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启手机 → 重启后点「打开」确认`；
3. 首次打开 App 时，允许**麦克风**和**通知**权限。

### 第 5 步：7 天后续签

免费签名 7 天后 App 会打不开（数据不会丢）。续签方法：
连上 Mac → Sideloadly 里重新拖入**同一个 ipa**、用**同一个 Apple ID** → Start。覆盖安装，待办数据保留。

> 同一套免费账号最多同时保留 3 个自签 App。

---

## 四、路线 B：TestFlight（长期自用推荐）

如果 App 用着顺手、打算天天用，值得花 ￥688 买个人开发者账号：

1. [developer.apple.com/programs](https://developer.apple.com/programs/) 注册（个人身份，1–2 天审核）；
2. 在 App Store Connect 建一个 App 记录；
3. 用 Xcode Cloud（网页端即可，**不需要本地 Mac 装 Xcode**）连接你的 GitHub 仓库，点一下就云端构建并上传 TestFlight；
4. 手机装 TestFlight App，用邀请链接安装，**90 天有效、无需连电脑、小组件和 App Group 全部正常**。

这条路同样绕开了「本机装不了 Xcode」的问题，因为构建完全在苹果的云端完成。

---

## 五、免费签名下的已知限制（提前说明，避免误会）

| 项目 | 状态 | 原因 |
| --- | --- | --- |
| 主 App 全部功能 | ✅ 正常 | 日历、干支四柱、待办、提醒、语音录入都不依赖 App Group |
| 桌面小组件的日历 + 干支 | ✅ 显示正常 | 干支由算法本地计算，不读共享数据 |
| 桌面小组件的今日待办 | ❌ 显示为空 | 免费账号无法创建 App Group，App 与小组件无法共享数据文件 |
| 数据存续 | ✅ 保留 | 重签是同 bundle id 覆盖安装 |
| 有效期 | ⚠️ 7 天 | 苹果对免费签名的硬限制 |

小组件待办为空不影响主 App 使用；若这块对你重要，直接上路线 B。

---

## 六、替代方案（如果上面的都不合适）

- **借用一台 macOS 26 的 Mac**：朋友/同事的机器上打开工程点 ▶ 即可，5 分钟搞定，之后仍需 7 天重签（除非用付费账号）。
- **租云 Mac**：[MacinCloud](https://www.macincloud.com/) 按小时计费，远程桌面里跑 Xcode 26，构建后导出 ipa，再回本地用 Sideloadly 安装。
- **先看界面效果**：`Preview/index.html` 用 AirDrop 传到 iPhone，Safari 打开即可看到三屏排版，无需安装。
