# 干支日历 · 待办

一款面向 iPhone 的中文「干支日历 + 待办」应用：公历万年历上叠加**六十甲子四柱**换算，支持**中文语音录入待办**（不依赖 Siri 解析内容）、键盘编辑、本地通知提醒，以及主屏幕小组件。App 内全部界面为中文，与手机系统语言无关。

> 本仓库交付的是**完整 Xcode 工程源码**。由于 iOS 应用只能在装有 Xcode 的 Mac 上编译签名，请按下方步骤在 Mac 上打开运行。

---

## 功能对照

| 需求 | 实现 |
| --- | --- |
| 公历万年历视图 | 月视图 + 左右翻月 + 「今天」定位 |
| 年柱 / 月柱 | 月份标题旁浅灰小字：`丙午年 · 己亥月` |
| 日柱 | 每个日期格下方小字标注 |
| 时柱 + 四柱 | 页面上方四柱条，实时显示当前时辰，附十二时辰刻度 |
| 待办增删改 | 日历格圆点 + 当日摘要 + 单日详情页，支持新增/编辑/删除 |
| 提醒 | 每条待办可设多个提前量，本地通知定时推送 |
| 中文语音录入 | App 内语音转文字（讯飞 SDK 或系统中文识别），自动提取事件与时间，可键盘校正 |
| Siri 唤醒 | 快捷指令/App Shortcuts 只做「打开 App 并自动录音」，不做语义解析 |
| 小组件 | 中等尺寸：当月迷你日历 + 今日四柱 + 今日待办 |
| 本地存储 | JSON 存于 App Group 共享目录，无云同步 |

---

## 目录结构

```
GanZhiTodo/
├── project.yml                 # XcodeGen 工程描述（推荐）
├── README.md
├── Shared/                     # App 与小组件共用（纯逻辑，无 UI）
│   ├── GanZhi.swift            # 干支四柱换算 + 节气天文算法
│   ├── TodoItem.swift          # 待办数据模型 + 提醒预设
│   └── SharedConfig.swift      # App Group / URL Scheme / 偏好键
├── GanZhiTodo/                 # 主 App
│   ├── GanZhiTodoApp.swift     # 入口
│   ├── AppModel.swift          # 界面状态
│   ├── Theme.swift             # 视觉规范
│   ├── Data/                   # 本地存储、本地通知
│   ├── Parser/TodoParser.swift # 中文时间语义解析（离线规则）
│   ├── Speech/                 # 语音识别（讯飞 + 系统兜底）
│   ├── Intents/                # Siri 快捷指令入口
│   ├── Views/                  # 各界面
│   ├── Assets.xcassets/        # 图标（已含）
│   ├── Info.plist / entitlements
├── GanZhiTodoWidget/           # 桌面小组件扩展
├── Tools/verify_ganzhi.py      # 干支算法独立验证脚本（已全量校验）
└── Preview/index.html          # 界面预览（手机三屏示意）
```

---

## 一、快速开始

> **⚠️ 如果你的 Mac 是 macOS 14 Sonoma 或更早、而 iPhone 已是 iOS 26**：本机装不了 Xcode 26，请直接看 [INSTALL-iOS26.md](INSTALL-iOS26.md)（GitHub 云编译 + 侧载安装，零成本）。

### 方式 A：XcodeGen（推荐）

```bash
brew install xcodegen
cd GanZhiTodo
xcodegen generate
open GanZhiTodo.xcodeproj
```

### 方式 B：手动新建工程

1. Xcode → New → iOS App，命名 `GanZhiTodo`，Interface 选 SwiftUI，语言 Swift，最低版本 iOS 17。
2. 删除自动生成的 `ContentView.swift`，把本仓库 `Shared/`、`GanZhiTodo/` 下所有 `.swift` 文件拖入对应 target。
3. 新建 Widget Extension target（File → New → Target → Widget Extension），命名 `GanZhiTodoWidget`，把 `GanZhiTodoWidget/` 和 `Shared/`（三个纯逻辑文件）加入该 target。
4. 按下方第 2、3 节配置 App Group 与 Info.plist（仓库里已备好，直接替换即可）。

---

## 二、配置 App Group（必须）

小组件与 App 通过 App Group 共享待办数据，必须一致：

1. 选中 `GanZhiTodo` target → Signing & Capabilities → `+ Capability` → **App Groups**，添加 `group.com.workbuddy.ganzhitodo`。
2. 对 `GanZhiTodoWidget` target 重复同样操作。
3. 两个 target 的 **Signing Team** 选择你的开发者账号。

> 若想改名字，同步修改 `Shared/SharedConfig.swift` 里的 `AppGroupConfig.identifier` 与两份 `.entitlements`。

---

## 三、接入科大讯飞语音 SDK（可选，建议）

App 默认已能用**系统中文语音识别**直接运行（联网或下载离线模型即可识别普通话）。如需讯飞 SDK 获得更准的中文识别：

1. 在[讯飞开放平台](https://www.xfyun.cn/)创建应用，开通「语音听写（iat）」，拿到 AppID。
2. 下载 iOS SDK（`iflyMSC.framework`），拖入 Xcode 的 `GanZhiTodo` target，勾选 `Embed & Sign`。
3. 打开 `GanZhiTodo/Speech/IFlytekSpeechService.swift`，把 `IFlytekConfig.appID` 换成你的 AppID。
4. 在 `设置 → 语音识别 → 识别引擎` 选择「科大讯飞」（或「自动」）。

> 未集成 SDK 时该文件编译为空实现，App 自动使用系统中文识别，不影响编译。讯飞听写需联网；如需离线听写请在讯飞侧开通离线授权并自行补充模型加载代码。

---

## 四、设置 Siri 唤醒词（小记小记）

需求是「Siri 只负责打开 App 并自动录音，语义识别全在 App 内」。两种做法：

1. **App Shortcuts（内置短语）**：已注册 `语音记待办` 意图，短语含「小记一下」「语音记待办」等。Siri 学习后喊 `Hey Siri，小记一下` 即可。
2. **快捷指令 App（更可控）**：
   - 打开「快捷指令」→ 右上「+」→ 添加操作 → 搜索「语音记待办」（本 App 提供的意图）→ 添加到指令。
   - 长按指令改名「小记小记」。
   - 之后喊 `Hey Siri，小记小记`，App 会打开并**自动开始录音**。

> ⚠️ 注意：手机系统为英文时，Siri 对中文唤醒短语的命中率受系统语音识别影响。若「小记小记」不灵敏，建议用英文短语（如 "Log a task in 干支日历"）或改用「快捷指令 → 添加到主屏幕/背部轻点」触发。唤醒只负责打开 App，内容识别在 App 内部完成，不受 Siri 语义能力影响。

触发链路：唤醒 → App 激活 → 读到 `pendingVoiceCapture` 标记 → 自动弹出录音页。

---

## 五、通知与权限

- 首次启动会请求**通知**权限；在 `设置 → 待办提醒` 可查看/跳转开启。
- 语音录入首次使用会请求**麦克风**（及系统识别的**语音识别**权限）。
- Info.plist 已配置 `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription`。

---

## 六、干支算法说明与验证

- **日柱**：儒略日 `(JDN + 49) % 60`。
- **年柱**：以**立春**交节时刻为界；**月柱**：以十二「节」（立春、惊蛰…小寒）交节时刻为界。
- **时柱**：每两小时一个时辰，23:00 起为子时；晚子时（23:00–23:59）默认归次日（可在设置关闭）。
- **节气时刻**：Meeus 低精度太阳视黄经公式 + 二分法反解，误差约 **±15 分钟**；节气当天以正午 12:00 为界判定当日干支。
- 全部按**北京时间（UTC+8）**计算，与设备时区无关。

**已通过独立验证**（`Tools/verify_ganzhi.py`，对照 `lunar_python` 权威库）：

- 日柱：公历 1900–2100 共 **73 414 天，0 误差**；
- 时柱：随机 4 000 组，**0 误差**；
- 年/月柱：仅在节气当天因「正午/子夜」判定口径不同相差一天（属正常，见脚本说明）。

```bash
pip install lunar_python   # 可选，用于全量比对
python3 Tools/verify_ganzhi.py --compare
```

---

## 七、已知限制

- 语音识别的**内容语义解析**为离线规则引擎（今天/明天/下周/几月几号/几点等），不联网、无云服务；复杂表达可识别后用键盘校正。
- 日历展示范围按公历 1900–2100（算法本身可外推，但 ΔT 多项式在此区间最准）。
- 本版本无云同步、无账户、无分享（按需求明确排除）。

---

## 交付清单

- 完整 SwiftUI 工程源码（App + 小组件）
- 干支四柱换算内核（已全量校验）
- 中文待办语义解析器
- 讯飞 SDK 接入层 + 系统识别兜底
- 本地通知提醒
- Siri 快捷指令入口
- App 图标与界面预览
