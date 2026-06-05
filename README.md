# Claude 红绿灯 — Claude Code 状态指示灯

> 一个 Windows 小工具：在你用 Claude Code（AI 编程助手）时，在屏幕右下角显示**红黄绿状态灯**，让你不用盯着终端也能知道 Claude 当前在干什么。

## 🎯 它是什么？

当你用 Claude Code 时，它会长时间思考、调用工具、等待确认……你没法一直盯着终端窗口看。**这个工具就在屏幕右下角给你一盏"红绿灯"：**

| 灯色 | 含义 |
|------|------|
| 🟢 **绿灯常亮** | Claude 在等你说话（空闲） |
| 🟡 **黄灯慢闪** | Claude 正在思考 / 写代码 |
| 🟡 **黄灯常亮** | Claude 正在执行任务（调用工具） |
| 🔴 **红灯闪烁** | Claude 需要你确认（需要你去点"是"或"否"） |
| 🔴 **红灯常亮** | 刚才出错了 |
| **全灭** | Claude 没在运行

灯会在**桌面小窗口**和**系统托盘**（右键任务栏附近那个小图标）同时显示。

> ⚠️ **这是一个给 Claude Code 用户用的辅助工具**。你需要先安装并会使用 [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/overview) 才能使用它。

## ⚡ 快速开始（推荐）

### 第 1 步：确认已安装 Claude Code

打开 **PowerShell**（右键"开始"菜单 → "终端" 或搜索 "PowerShell"），输入：

```
claude --version
```

如果能显示版本号（如 `0.5.10`），说明已安装。如果提示"不是内部或外部命令"，请先去安装 [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)。

### 第 2 步：下载本项目

1. 打开 [github.com/chengxiao88/ClaudeTrafficLight](https://github.com/chengxiao88/ClaudeTrafficLight)
2. 点击绿色的 **`Code`** 按钮
3. 选择 **`Download ZIP`**
4. 解压到你想放的地方，比如 `C:\ClaudeTrafficLight\`

### 第 3 步：一键安装

1. **右键**解压后的文件夹 → **PowerShell 终端在此处打开**（或在 PowerShell 中 `cd` 进入该目录）
2. 粘贴运行以下命令：

```powershell
.\scripts\install.ps1
```

安装脚本会自动：
- 编译并生成 `ClaudeTrafficLight.exe`
- 放到 `C:\Users\你的用户名\AppData\Local\ClaudeLight\` 下
- 配置好所有文件

> 💡 **第一次运行 `install.ps1` 时如果提示"不允许运行脚本"**，先运行：
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```
> 输入 `Y` 确认即可。

### 第 4 步：启动 Claude 红绿灯

用项目自带的启动器来启动 Claude：

1. 在项目根目录（刚才解压的文件夹）中，**右键 `scripts\start-claude.cmd`**
2. 选择 **"使用 PowerShell 运行"**（或用文件管理器双击也行）

你会看到：
- **屏幕右下角出现一个深灰色小条**，里面**绿灯亮起** ← 这就是红绿灯！
- Claude Code 开始运行

### 第 5 步：开始使用！

现在正常对 Claude 说话即可。观察右下角的红绿灯：

- 🟢 绿灯常亮 = 我在等你
- 🟡 黄灯闪 = 我在思考/干活
- 🔴 红灯闪 = 快来确认一下！

---

## ❓ 常见问题

### Q: 我不用命令行，怎么启动？

`scripts\start-claude.cmd` 支持双击运行。如果双击没反应：
1. 右键该文件 → **"打开方式"** → 选择 **PowerShell**

### Q: 红绿灯不亮怎么办？

**5 秒自查清单：**

1. **安装了吗？** 运行过 `.\scripts\install.ps1` 吗？
2. **启动方式对吗？** 必须用 `scripts\start-claude.cmd` 启动，**不要**直接输入 `claude` 命令
3. **灯窗口消失了吗？** 看屏幕右下角有没有灰色小条（可能在屏幕边缘外面），也可以看系统托盘（右键任务栏附近的小图标）
4. **手动测试一下：** 在 PowerShell 中运行：
   ```powershell
   .\scripts\manual-test.ps1 thinking
   ```
   如果黄灯闪了，说明程序正常，只是 hooks 没触发 — 回头检查启动方式
5. **安装 .NET 8 Runtime 了吗？** 见下方

### Q: 提示"需要 .NET 8 Runtime"？

这个工具需要 .NET 运行环境。请根据你的系统选择：

**大部分电脑** → 安装 .NET 8 Desktop Runtime：
👉 [.NET 8 Desktop Runtime 下载页面](https://dotnet.microsoft.com/download/dotnet/8.0)
- 选择 **`.NET 8.0.xx Desktop runtime`**（x64）
- 下载安装，安装完**重启电脑**

**部分电脑（如较新 Windows 11 版本）** → 还需安装 .NET 10 Runtime：
👉 [.NET 10 Desktop Runtime 下载页面](https://dotnet.microsoft.com/en-us/download)
- 在页面中选择 **`.NET 10 Desktop runtime`**（x64）
- 安装后重启

> 💡 不确定装哪个？先装 .NET 8，如果启动时还提示缺运行时，再补装 .NET 10。

### Q: 重启电脑后红绿灯又没了？

正常。每次开机后你需要：
1. 启动 Claude Code：双击 `scripts\start-claude.cmd`
2. 红绿灯会自动跟着出现

> **为什么不用每次都配 hooks？** 因为我们用的 `start-claude.cmd` 会在启动时自动完成配置注入，不用手动操作。

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

## 📖 详细文档

| 文档 | 说明 |
|------|------|
| [README](README.md) | 本文档 |
| [PRD](docs/PRD.md) | 产品需求文档（给开发者看） |

## 📂 项目结构

```
ClaudeTrafficLight/
├── scripts/
│   ├── install.ps1              一键安装（编译 + 部署）
│   ├── start-claude.cmd         启动器（启动 Claude + 红绿灯）← 你主要用这个
│   ├── ensure-hooks.ps1         自动注入配置（保证每次启动都正常）
│   ├── manual-test.ps1          手动测试（调试用）
│   └── signal.ps1               状态信号桥（接收 Claude 事件）
├── src/ClaudeTrafficLight/      源代码
├── .claude/
│   └── settings.json            Hooks 配置模板
└── docs/
    └── PRD.md                   产品需求文档
```

## ❌ 已知限制

- 仅支持 **Windows**
- 仅支持 **单个 Claude 会话**（不支持多 Claude 实例同时显示）
- 状态灯**不是图标**，而是一个小窗口 — 因为 Windows 任务栏图标上画 3 颗圆点太不清晰了

## 🛠️ 给开发者

想编译源码？确保安装了 [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)（部分电脑还需 [.NET 10 SDK](https://dotnet.microsoft.com/en-us/download)），然后：

```powershell
.\scripts\install.ps1
```

这个脚本会自动 `dotnet publish` 发布为单文件 exe，一步到位。
