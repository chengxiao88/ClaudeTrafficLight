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

### 3.8 Hooks 持久化（ensure-hooks.ps1）

- 输入：无（自动读取项目级 `.claude/settings.json` 和用户级 `~/.claude/settings.json`）
- 功能：
  - 检测用户级 `settings.json` 是否已包含 hooks
  - 如未包含，将项目级 hooks 模板合并追加到用户级 `settings.json` 末尾
  - 幂等执行——hooks 已存在时直接跳过，不重复写入
  - 保留 `settings.json` 中已有的所有配置（env、theme 等）
- 输出：无 stdout/stderr（保持静默）
- 调用时机：由 `start-claude.cmd` 在启动 Claude 之前调用

## 4. 技术架构

### 4.1 技术栈

| 技术栈 | 涉及模块 |
|--------|----------|
| 桌面程序 | .NET 8 + WinForms |
| 信号桥 | PowerShell 7+ / 5.1（signal.ps1） |
| Hooks 持久化 | PowerShell + JSON 合并（ensure-hooks.ps1） |
| Hooks 配置 | Claude Code settings.json |
| 构建 | dotnet publish + install.ps1 |

### 4.2 数据流

```
启动阶段：
start-claude.cmd
  ├─ ensure-hooks.ps1 → 将 hooks 注入 ~/.claude/settings.json
  ├─ 启动 ClaudeTrafficLight.exe
  └─ 启动 claude

运行阶段：
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
- .NET 8 SDK（用于编译，**不是 Runtime**）
- .NET 8 Desktop Runtime（用于运行已编译的程序）

> ⚠️ **SDK vs Runtime**：编译时需要 SDK，运行时只需要 Runtime。如果提示 "No .NET SDKs were found"，请安装 .NET 8 SDK x64。

### 5.2 安装步骤

1. **构建与安装**：在项目根目录执行：

   ```powershell
   .\scripts\install.ps1
   ```

   如果 PowerShell 执行策略阻止脚本运行，使用：

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
   ```

   安装脚本会自动：
   - 检测 .NET 8 SDK 并执行 `dotnet publish` 发布为单文件 exe
   - 将 `ClaudeTrafficLight.exe` 复制到 `%LOCALAPPDATA%\ClaudeLight\app\`
   - 复制 `signal.ps1`、`start-claude.cmd`、`ensure-hooks.ps1`、`manual-test.ps1` 到 `%LOCALAPPDATA%\ClaudeLight\scripts\`
   - 调用 `ensure-hooks.ps1 -Force` 将 Hooks 写入 `%USERPROFILE%\.claude\settings.json`
   - 生成参考配置文件 `%LOCALAPPDATA%\ClaudeLight\settings.generated.json`

2. **验证安装**：在 PowerShell 中检查：

   ```powershell
   # 检查程序文件
   Test-Path "$env:LOCALAPPDATA\ClaudeLight\app\ClaudeTrafficLight.exe"

   # 检查进程
   Get-Process ClaudeTrafficLight -ErrorAction SilentlyContinue

   # 手动测试状态灯
   & "$env:LOCALAPPDATA\ClaudeLight\scripts\signal.ps1" permission
   & "$env:LOCALAPPDATA\ClaudeLight\scripts\signal.ps1" done
   ```

### 5.3 Hooks 注入机制

本工具通过 `ensure-hooks.ps1` 动态注入 Hooks，**不再使用硬编码路径**：

- `ensure-hooks.ps1` 在运行时读取自身所在目录的 `signal.ps1` 完整路径
- 将该路径动态写入 `%USERPROFILE%\.claude\settings.json` 的 hooks 配置
- 幂等执行：如果 hooks 已指向当前 `signal.ps1`，则跳过写入
- 安全保护：如果 `settings.json` 不是合法 JSON，会备份后重新创建

这种设计确保：
- Hooks 路径自动适应用户的实际安装目录
- 即使 `settings.json` 被其他工具（如代理工具）覆写，启动时也会自动修复

### 5.4 启动方式

**唯一推荐**：使用安装目录下的启动器

```cmd
%LOCALAPPDATA%\ClaudeLight\scripts\start-claude.cmd
```

启动流程：
1. 如果从源码目录运行，自动转发到安装目录版本
2. 执行 `ensure-hooks.ps1` 检查并注入 Hooks 到 `%USERPROFILE%\.claude\settings.json`
3. 启动 `ClaudeTrafficLight.exe`（桌面右下角红绿灯窗口）
4. 设置终端标题为 `Claude Code - TrafficLight`
5. 启动 `claude`（加载带 hooks 的配置）

> ⚠️ **不要直接运行源码目录的 `scripts\start-claude.cmd`**。如果已安装，源码版本会自动转发到安装目录版本。直接运行源码版本会导致 Hooks 路径指向源码目录的 `signal.ps1`，移动或删除源码后 Hooks 会失效。

**备选**：如果已通过其他方式确保 Hooks 配置正确，直接运行 `claude` 也可触发 `signal.ps1` 自动拉起状态灯。

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

## 8. 常见问题

### 8.1 PowerShell 执行策略导致脚本无法运行

如果 Windows 执行策略限制 PowerShell 脚本运行，有两种解决方法：

**方法 1：使用绕过参数（推荐，不影响系统设置）**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

**方法 2：修改当前用户的执行策略**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 8.2 缺少 .NET 8 SDK 导致 exe 无法生成

如果 `install.ps1` 输出：

```
No .NET SDKs were found. Scripts and Hooks will be installed, but ClaudeTrafficLight.exe cannot be built.
```

说明缺少 .NET 8 SDK。请注意：

- 编译需要 **SDK**，不是 Runtime
- Runtime 只能运行已编译的程序，无法编译新程序

解决步骤：

1. 访问 [.NET 8 SDK 下载页面](https://dotnet.microsoft.com/download/dotnet/8.0)
2. 下载 **SDK (x64)** 版本
3. 安装后重新打开 PowerShell
4. 验证：`dotnet --list-sdks` 应显示 `8.0.xxx`
5. 重新运行 `.\scripts\install.ps1`

### 8.3 Hooks 已安装但桌面红绿灯不显示

排查步骤：

1. **确认 exe 存在**：
   ```powershell
   Test-Path "$env:LOCALAPPDATA\ClaudeLight\app\ClaudeTrafficLight.exe"
   ```
   如果返回 `False`，说明编译失败，请先解决 .NET SDK 问题

2. **手动启动程序**：
   ```powershell
   & "$env:LOCALAPPDATA\ClaudeLight\app\ClaudeTrafficLight.exe"
   ```

3. **检查 .NET Runtime**：如果手动启动提示缺运行时，安装 [.NET 8 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/8.0)

4. **手动测试 signal.ps1**：
   ```powershell
   & "$env:LOCALAPPDATA\ClaudeLight\scripts\signal.ps1" thinking
   ```
   执行后红绿灯应变黄并闪烁

### 8.4 settings.json 非法 JSON 被备份

如果 `ensure-hooks.ps1` 检测到 `%USERPROFILE%\.claude\settings.json` 不是合法的 JSON 文件，它会：

1. 备份原文件为 `settings.json.invalid-YYYYMMDD-HHmmss.bak`
2. 创建新的有效 `settings.json`

这是正常的安全保护机制。用户可以从备份文件恢复其他配置项。

### 8.5 不要直接运行源码目录的 start-claude.cmd

源码目录的 `scripts\start-claude.cmd` 会检测并转发到安装目录版本。如果直接运行源码版本：

- Hooks 路径会被写入源码目录的 `signal.ps1` 路径
- 移动或删除源码目录后 Hooks 会失效
- `start-claude.cmd` 中的转发逻辑确保始终使用安装版本

**始终使用安装目录下的启动器**：

```cmd
%LOCALAPPDATA%\ClaudeLight\scripts\start-claude.cmd
```

### 8.6 Hook 没有触发

1. **是否使用了安装目录的 `start-claude.cmd` 启动？**
2. 在 Claude 中输入 `/hooks` 查看已注册事件列表
3. 手动运行 `ensure-hooks.ps1` 检查 hooks 是否已注入：
   ```powershell
   & "$env:LOCALAPPDATA\ClaudeLight\scripts\ensure-hooks.ps1"
   ```
4. 检查 `%LOCALAPPDATA%\ClaudeLight\status.json` 是否存在以及内容是否正确

### 8.7 重启后 hooks 丢失

某些代理工具（配置了 `ANTHROPIC_BASE_URL`）在 Windows 启动时会覆写 `%USERPROFILE%\.claude\settings.json`，清除所有 hooks。解决方式：

- **始终使用安装目录的 `start-claude.cmd` 启动 Claude**
- 它会在 `claude` 运行前自动注入 hooks