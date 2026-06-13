# Claude 红绿灯 — Claude Code 状态指示灯

> 一个 Windows 小工具：在你用 Claude Code（AI 编程助手）时，在屏幕右下角显示**红黄绿状态灯**，让你不用盯着终端也能知道 Claude 当前在干什么。

## 🎯 它是什么？

当你用 Claude Code 时，它会长时间思考、调用工具、等待确认……你没法一直盯着终端窗口看。**这个工具就在屏幕右下角给你一盏"红绿灯"：**

| 灯色 | 含义 |
|------|------|
| 🟢 **绿灯常亮** | Claude 在等你说话（空闲） |
| 🟢 **绿灯闪烁** | 任务完成，等你查看（闪烁 10 次后转常亮） |
| 🟡 **黄灯慢闪** | Claude 正在思考 |
| 🟡 **黄灯常亮** | Claude 正在执行任务（调用工具） |
| 🔴 **红灯闪烁** | Claude 需要你确认（需要你去点"是"或"否"） |
| 🔴 **红灯常亮** | 刚才出错了 |
| ⚫ **三灯全灭** | Claude 会话已结束或超过 30 分钟无更新 |

灯会在**桌面小窗口**和**系统托盘**（右键任务栏附近那个小图标）同时显示。

> ⚠️ **这是一个给 Claude Code 用户用的辅助工具**。你需要先安装并会使用 [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/overview) 才能使用它。

## ⚡ 快速开始

### 第 1 步：确认已安装 Claude Code

打开 **PowerShell**（右键"开始"菜单 → "终端" 或搜索 "PowerShell"），输入：

```powershell
claude --version
```

如果能显示版本号（如 `0.5.10`），说明已安装。如果提示"不是内部或外部命令"，请先去安装 [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)。

### 第 2 步：下载本项目

1. 打开 [github.com/chengxiao88/ClaudeTrafficLight](https://github.com/chengxiao88/ClaudeTrafficLight)
2. 点击绿色的 **`Code`** 按钮
3. 选择 **`Download ZIP`**
4. 解压到你想放的地方，比如 `C:\ClaudeTrafficLight\`

### 第 3 步：一键安装

1. **右键**解压后的文件夹 → **"在终端中打开"**（或在 PowerShell 中 `cd` 进入该目录）
2. 粘贴运行以下命令：

```powershell
.\scripts\install.ps1
```

安装脚本会自动：
- 检测 .NET 8 SDK 并编译生成 `ClaudeTrafficLight.exe`
- 将程序部署到 `%LOCALAPPDATA%\ClaudeLight\app\`
- 复制脚本到 `%LOCALAPPDATA%\ClaudeLight\scripts\`
- 通过 `ensure-hooks.ps1` 自动将 Hooks 写入 `%USERPROFILE%\.claude\settings.json`

> 💡 **如果提示"不允许运行脚本"或"此系统上禁用了脚本运行"**，使用以下命令绕过执行策略：
> ```powershell
> powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
> ```

> ⚠️ **如果提示"No .NET SDKs were found"或"dotnet was not found"**，说明缺少 .NET 8 SDK（注意是 **SDK**，不是 Runtime）。请安装：
> 👉 [.NET 8 SDK x64 下载页面](https://dotnet.microsoft.com/download/dotnet/8.0)
> - 选择 **`.NET 8.0.xx SDK`**（x64）
> - 下载安装后**重新打开 PowerShell**，再运行安装命令

### 第 4 步：启动 Claude 红绿灯

**推荐方式**：运行安装目录下的启动器

```cmd
%LOCALAPPDATA%\ClaudeLight\scripts\start-claude.cmd
```

你可以：
- 按 `Win + R`，粘贴上面的路径，回车
- 或在文件资源管理器地址栏粘贴该路径，双击 `start-claude.cmd`

启动后你会看到：
- **屏幕右下角出现一个深灰色小条**，里面**绿灯亮起** ← 这就是红绿灯！
- Claude Code 开始运行

> ⚠️ **不要直接运行源码目录里的 `scripts\start-claude.cmd`**。如果已安装，它会自动转发到安装目录的版本。请始终使用安装目录下的启动器。

### 第 5 步：验证安装是否成功

在 PowerShell 中依次运行以下命令检查：

```powershell
# 1. 检查程序文件是否存在
Test-Path "$env:LOCALAPPDATA\ClaudeLight\app\ClaudeTrafficLight.exe"

# 2. 检查进程是否在运行
Get-Process ClaudeTrafficLight -ErrorAction SilentlyContinue

# 3. 手动测试状态灯（应看到黄灯闪烁）
& "$env:LOCALAPPDATA\ClaudeLight\scripts\signal.ps1" thinking

# 4. 测试完成后恢复空闲状态
& "$env:LOCALAPPDATA\ClaudeLight\scripts\signal.ps1" idle
```

预期结果：
- 第 1 条返回 `True`
- 第 2 条显示进程信息（如果没有则在启动后检查）
- 第 3 条执行后桌面红绿灯变黄并闪烁
- 第 4 条执行后恢复绿灯常亮

### 第 6 步：开始使用！

现在正常对 Claude 说话即可。观察右下角的红绿灯：

- 🟢 绿灯常亮 = 我在等你
- 🟡 黄灯闪 = 我在思考/干活
- 🔴 红灯闪 = 快来确认一下！

---

## 📂 项目结构

```
ClaudeTrafficLight/
├── scripts/
│   ├── install.ps1              一键安装（编译 + 部署 + 注入 Hooks）
│   ├── start-claude.cmd         启动器（启动 Claude + 红绿灯）← 你主要用这个
│   ├── ensure-hooks.ps1         自动注入 Hooks 到 settings.json
│   ├── manual-test.ps1          手动测试（调试用）
│   └── signal.ps1               状态信号桥（接收 Claude 事件）
├── src/ClaudeTrafficLight/      源代码（.NET 8 WinForms）
├── hooks/
│   └── settings.template.json   Hooks 配置模板（路径占位符）
├── .claude/
│   └── settings.example.json    Hooks 配置示例
└── docs/
    └── PRD.md                   产品需求文档
```

安装后的目录结构：

```
%LOCALAPPDATA%\ClaudeLight\
├── app\
│   └── ClaudeTrafficLight.exe  桌面红绿灯程序
├── scripts\
│   ├── start-claude.cmd        启动器（推荐使用）
│   ├── ensure-hooks.ps1        Hooks 注入脚本
│   ├── signal.ps1              状态信号桥
│   └── manual-test.ps1         手动测试脚本
└── settings.generated.json     生成的 Hooks 配置参考
```

---

## ❓ 常见问题

### Q: PowerShell 提示"此系统上禁用了脚本运行"？

Windows 默认可能限制 PowerShell 脚本执行。解决方法：

**方法 1：使用绕过参数（推荐，不影响系统设置）**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

**方法 2：修改当前用户的执行策略**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

输入 `Y` 确认，之后就可以直接运行 `.\scripts\install.ps1`。

### Q: 提示"No .NET SDKs were found"或无法生成 exe？

安装脚本需要 **.NET 8 SDK**（不是 Runtime）来编译程序。请：

1. 访问 [.NET 8 SDK 下载页面](https://dotnet.microsoft.com/download/dotnet/8.0)
2. 下载 **SDK (x64)** 版本（注意是 SDK，不是 Runtime）
3. 安装后**重新打开 PowerShell**
4. 验证安装：`dotnet --list-sdks` 应显示 `8.0.xxx`
5. 重新运行 `.\scripts\install.ps1`

> 💡 **SDK vs Runtime 区别**：
> - **SDK**：用于开发编译，包含编译器、Runtime 等
> - **Runtime**：仅用于运行已编译的程序
> - 本工具编译需要 SDK，运行只需要 Runtime

### Q: Hooks 已安装但桌面红绿灯不显示？

检查步骤：

1. **确认 exe 存在**：
   ```powershell
   Test-Path "$env:LOCALAPPDATA\ClaudeLight\app\ClaudeTrafficLight.exe"
   ```
   如果返回 `False`，说明编译失败，请安装 .NET 8 SDK 后重新运行 `install.ps1`

2. **手动启动程序**：
   ```powershell
   & "$env:LOCALAPPDATA\ClaudeLight\app\ClaudeTrafficLight.exe"
   ```

3. **检查 .NET Runtime**：
   如果手动启动提示缺运行时，安装 [.NET 8 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/8.0)

4. **手动测试 signal.ps1**：
   ```powershell
   & "$env:LOCALAPPDATA\ClaudeLight\scripts\signal.ps1" thinking
   ```
   执行后红绿灯应变黄并闪烁

### Q: settings.json 被备份了？

如果 `ensure-hooks.ps1` 检测到 `%USERPROFILE%\.claude\settings.json` 不是合法的 JSON 文件，它会：

1. 备份原文件为 `settings.json.invalid-YYYYMMDD-HHmmss.bak`
2. 创建新的有效 `settings.json`

这是正常的安全保护机制，防止损坏的配置文件导致 Claude Code 无法工作。

### Q: 为什么不推荐直接运行源码目录的 start-claude.cmd？

源码目录的 `start-claude.cmd` 会检测并转发到安装目录版本。如果直接运行源码版本：

- Hooks 路径会被写入源码目录的 `signal.ps1` 路径
- 移动或删除源码目录后 Hooks 会失效

**始终使用安装目录下的启动器**：

```cmd
%LOCALAPPDATA%\ClaudeLight\scripts\start-claude.cmd
```

### Q: 重启电脑后红绿灯又没了？

正常。每次开机后你需要：

1. 运行 `%LOCALAPPDATA%\ClaudeLight\scripts\start-claude.cmd`
2. 红绿灯会自动跟着出现

> **为什么不用每次都配 hooks？** 因为 `start-claude.cmd` 会在启动时自动调用 `ensure-hooks.ps1` 注入 Hooks，即使 `settings.json` 被其他工具覆写也能自动修复。

### Q: 红绿灯窗口可以移到屏幕其他地方吗？

可以。**用鼠标按住窗口拖走**就行，它在哪都行。

### Q: 点一下窗口，Claude 终端跑到了前面？

对，点击红绿灯窗口或托盘图标会**自动把 Claude 终端窗口带到最前面**，方便你继续操作。

### Q: 这个工具安全吗？会窃取我的对话内容吗？

不会。这个工具：
- **纯本地运行**，不联网
- **不读取** Claude 的任何对话内容
- 只记录：当前状态、时间戳、会话 ID、工作目录（就是让你知道"Claude 在干嘛"）

### Q: 我怎么退出红绿灯程序？

右键系统托盘的小灯图标 → 选择 **"退出"**。

---

## 🔧 运行原理

### Hooks 注入机制

本工具通过 `ensure-hooks.ps1` 动态注入 Hooks，**不再使用硬编码路径**：

1. `install.ps1` 运行时调用 `ensure-hooks.ps1 -Force`
2. `ensure-hooks.ps1` 读取当前脚本所在目录的 `signal.ps1` 完整路径
3. 将该路径写入 `%USERPROFILE%\.claude\settings.json` 的 hooks 配置中
4. 每次通过 `start-claude.cmd` 启动时，都会检查并修复 Hooks 配置

这种设计确保：
- Hooks 路径自动适应用户的实际安装目录
- 即使 `settings.json` 被其他工具（如代理工具）覆写，启动时也会自动修复

### 状态流转

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

---

## 📖 详细文档

| 文档 | 说明 |
|------|------|
| [README](README.md) | 本文档 |
| [PRD](docs/PRD.md) | 产品需求文档（给开发者看） |

---

## ❌ 已知限制

- 仅支持 **Windows**
- 仅支持 **单个 Claude 会话**（不支持多 Claude 实例同时显示）
- 状态灯**不是图标**，而是一个小窗口 — 因为 Windows 任务栏图标上画 3 颗圆点太不清晰了

## 🛠️ 给开发者

想编译源码？确保安装了 [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)，然后：

```powershell
.\scripts\install.ps1
```

这个脚本会自动 `dotnet publish` 发布为单文件 exe，一步到位。