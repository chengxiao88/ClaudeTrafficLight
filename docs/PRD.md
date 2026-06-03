# PRD：Claude 红绿灯状态提醒工具

## 1. 概述

### 1.1 产品定位

在 Claude Code CLI 长时间执行任务时，用户无法一直盯着终端屏幕。本工具通过 Claude Code Hooks 机制实时捕获状态变化，在 Windows 桌面角落显示红黄绿灯，让用户一瞥即可知道当前状态。

### 1.2 目标用户

- Claude Code 的日常使用者
- 需要同时处理多任务的开发者
- 远程桌面或小屏幕场景下的用户

## 2. 状态模型

### 2.1 状态定义

| 状态 | 枚举值 | 灯效 | 说明 |
|------|--------|------|------|
| 未启动 | `Off` | 三灯全灰 | 程序启动后默认状态，或超过 30 分钟无更新自动进入 |
| 空闲 | `Idle` | 绿灯常亮 | Claude 等待用户输入 |
| 任务完成 | `Done` | 绿灯闪烁 10 次 → 常绿 | 由 `idle_prompt` 通知或 `Stop` 事件触发 |
| 思考中 | `Thinking` | 黄灯慢闪（1s 亮 1s 灭） | `UserPromptSubmit` / `PostToolUse` / `PostToolBatch` |
| 执行任务 | `Working` | 黄灯常亮 | `PreToolUse` 触发 |
| 等待授权 | `Permission` | 红灯闪烁 10 次 → 常红 | `PermissionRequest` 或 `permission_prompt` 通知触发 |
| 错误 | `Error` | 红黄交替快闪 | `PostToolUseFailure` / `StopFailure` 触发 |

### 2.2 状态流转

```
Off ──SessionStart──→ Idle ←── Stop/idle_prompt ──→ Done
                         │                              │
                     UserPromptSubmit               (10次闪烁后)
                         │                              │
                         ↓                              ↓
                     Thinking ←── PostToolUse ──→ Working
                         │
                    PostToolUseFailure/StopFailure
                         │
                         ↓
                       Error
                         │
                     PermissionRequest
                         │
                         ↓
                    Permission ──(用户授权)──→ Thinking/Working

任意状态超过 30 分钟无更新 ──→ Off
SessionEnd ──→ Off
```

## 3. 功能规格

### 3.1 桌面指示灯窗口

- 位置：屏幕右下角（WorkingArea 右下偏移 16px 水平、8px 垂直）
- 尺寸：固定，不随系统缩放变化
- 外观：深色背景（#1E1E1E）、细边框（#0A0A0A）、三颗 10px 圆点（间距 8px）
- 置顶显示（TopMost = true）
- 无标题栏，可拖拽移动
- 通过 `WS_EX_TOOLWINDOW` 隐藏于 Alt+Tab 切换列表
- 双缓冲渲染，动画流畅

### 3.2 系统托盘图标

- 运行时始终显示在系统托盘
- 图标实时反映当前灯色（64x64 三色圆点）
- 鼠标悬停显示状态文字提示
- 双击托盘图标 → 定位 Claude 终端窗口
- 右键菜单：
  - 「定位 Claude 终端」
  - 分隔线
  - 「退出」

### 3.3 终端定位功能

点击窗口或托盘图标时，遍历系统进程，按优先级匹配：

1. 窗口标题包含 `Claude Code - TrafficLight`（推荐用包装器启动）
2. 窗口标题包含 `claude` 且进程名为 WindowsTerminal/cmd/powershell/pwsh

匹配到后调用 `ShowWindow(SW_RESTORE)` + `SetForegroundWindow` 将终端带到前台。

### 3.4 动画系统

所有动画由 250ms 定时器驱动：

| 动画 | 机制 | 持续时间 |
|------|------|----------|
| 完成闪烁（Done） | 20 次 toggle 后切为 Idle 常亮 | ~5 秒 |
| 授权闪烁（Permission） | 20 次 toggle 后保持 Permission 常亮 | ~5 秒 |
| 思考慢闪（Thinking） | 4 tick 亮 / 4 tick 灭循环 | 无限 |
| 错误快闪（Error） | 2 tick 亮 / 2 tick 灭循环，红黄交替 | 无限 |
| 普通常亮 | flashVisible 恒为 true | — |

### 3.5 过期检测

- 每 30 秒检查一次最后更新时间戳
- 超过 30 分钟无状态更新 → 自动切换为 `Off`
- 确保程序退出或 Hook 失效时不留下误导状态

### 3.6 信号桥（signal.ps1）

- 输入：命令行参数 `$State` + stdin JSON context
- 功能：
  - 自动创建 `%LOCALAPPDATA%/ClaudeLight/` 目录结构
  - 自动检测并启动 `ClaudeTrafficLight.exe`（如未运行）
  - 状态标准化（`session_start` → `idle`）
  - 原子写入 `status.json`（`.tmp` + `Move-Item`）
  - 同时按 session_id 写入 `sessions/{session_id}.json` 保留历史
  - 静默失败，不干扰 Claude Code 主流程
- 输出：无 stdout/stderr（避免 Hook 误报）

### 3.7 单实例保护

- 使用命名互斥锁 `Global\ClaudeTrafficLight_UserInstance`
- 第二个实例启动时自动退出

## 4. 技术架构

### 4.1 技术栈

| 层 | 技术 |
|----|------|
| 桌面程序 | .NET 8 + WinForms |
| 信号桥 | PowerShell 7+ / 5.1 |
| Hooks 配置 | Claude Code settings.json |
| 构建 | dotnet publish + install.ps1 |

### 4.2 数据流

```
Claude Code Hook
    ↓ (事件触发)
powerShell.exe -File signal.ps1 <state> (通过 stdin 传入 JSON context)
    ↓
signal.ps1 解析 context，构造 StatusPayload
    ↓ (原子写入)
%LOCALAPPDATA%/ClaudeLight/status.json
    ↓ (FileSystemWatcher 通知)
ClaudeTrafficLight.exe 读取 → 解析 → 更新灯效
```

### 4.3 数据模型（StatusPayload）

```json
{
  "state": "idle|done|thinking|working|permission|error|off",
  "time": "2025-01-01T12:00:00.0000000+08:00",
  "session_id": "uuid-or-default",
  "cwd": "C:\\project\\path",
  "hook_event_name": "UserPromptSubmit",
  "tool_name": "Bash",
  "notification_type": "idle_prompt",
  "source": ""
}
```

## 5. 安装与配置

### 5.1 前置依赖

- Windows 10/11
- .NET 8 Runtime（非 SDK 也可）
- 构建时需要 .NET 8 SDK

### 5.2 安装步骤

1. 执行 `scripts\install.ps1`
2. 将生成的 `settings.generated.json` 中的 hooks 合并到 `%USERPROFILE%\.claude\settings.json`
3. 在 Claude CLI 中运行 `/hooks` 验证

### 5.3 启动方式

- **推荐**：使用 `start-claude.cmd`（设置终端标题为 `Claude Code - TrafficLight`，提高聚焦准确率）
- **自动**：只要 Hooks 配好，Claude 触发事件时 signal.ps1 会自动拉起状态灯

## 6. 约束与限制

- **Windows Only**：依赖 WinForms、Win32 API
- **不联网**：纯本地运行，不上传任何数据
- **只读不写**：不修改 Claude Code 的任何配置或对话内容
- **不自动授权**：仅显示等待授权状态，不会自动批准
- **单用户**：每个 Windows 用户独立实例
- **当前为 MVP**：状态以最近一次 Hook 事件为准，不进行多会话优先级聚合

## 7. 未来方向（非 MVP）

- 多会话优先级聚合（多个 Claude 实例同时运行时显示最紧急的状态）
- 自定义颜色/位置/动画配置 UI
- 声音提醒（任务完成时播放提示音）
- 状态历史图表（统计每 session 的等待/工作时间）
- 自定义 Hook 事件映射