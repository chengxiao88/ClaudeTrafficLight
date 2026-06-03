# Claude Traffic Light / Claude 红绿灯

一个 Windows 本地小工具：通过 Claude Code Hooks 接收状态事件，在桌面角落和系统托盘里显示红黄绿状态灯，让你不用一直盯着终端也能知道 Claude 当前在干什么。

## 状态定义

| 状态 | 红 | 黄 | 绿 | 含义 |
|------|---|---|------|------|
| 空闲 | ● 灰 | ● 灰 | ● **亮** | Claude 等待输入 |
| 任务完成 | ● 灰 | ● 灰 | ● **闪烁 10 次后常亮** | Claude 刚完成任务，回到空闲 |
| 思考中 | ● 灰 | ● **慢闪** | ● 灰 | Claude 正在思考/生成回复 |
| 执行任务 | ● 灰 | ● **常亮** | ● 灰 | Claude 正在调用工具 |
| 等待授权 | ● **闪烁 10 次后常亮** | ● 灰 | ● 灰 | Claude 需要用户确认（Yes/No） |
| 发生错误 | ● **亮** | ● **亮**（交替闪烁） | ● 灰 | Hook 或 Claude turn 失败 |
| 未启动/过期 | ● 灰 | ● 灰 | ● 灰 | Claude 未启动，或状态超过 30 分钟未更新 |

- **绿灯闪烁 10 次**：闪烁完后变为常绿（空闲）
- **红灯闪烁 10 次**：闪烁完后变为常红（仍在等待授权）
- **黄灯慢闪**：250ms 粒度，亮 1s 灭 1s 循环
- **红黄交替闪**（Error）：红亮黄灭 ↔ 红灭黄亮，快速交替

## 技术路线

```
Claude CLI / Claude Code
  └─ Hooks → scripts/signal.ps1
       ├─ 写入 %LOCALAPPDATA%/ClaudeLight/status.json
       ├─ 写入 %LOCALAPPDATA%/ClaudeLight/sessions/{session_id}.json
       └─ 自动拉起 ClaudeTrafficLight.exe（如未运行）
            └─ FileSystemWatcher 监听 status.json 变化
                 ├─ 更新桌面小窗口（3 颗圆点 + 颜色 + 动画）
                 └─ 更新系统托盘图标
```

**隐私说明**：本工具不调用外网、不读取 Claude 对话内容。只保存状态、时间、session_id、cwd、hook_event_name、tool_name、notification_type、source 等元数据。

## 目录结构

```
ClaudeTrafficLight/
├── src/ClaudeTrafficLight/      .NET 8 WinForms 源码
│   ├── Program.cs               入口 + 单实例互斥锁
│   ├── TrafficLightForm.cs      主窗口 + 托盘 + 灯效 + 文件监听
│   ├── TrafficLightState.cs     状态枚举
│   ├── StatusPayload.cs         状态数据模型
│   ├── app.ico                  应用图标
│   └── ClaudeTrafficLight.csproj
├── scripts/
│   ├── signal.ps1               Claude Hook 信号桥（自动启动 exe + 原子写入 + 会话日志）
│   ├── install.ps1              发布并安装到 %LOCALAPPDATA%/ClaudeLight
│   ├── start-claude.cmd         可选启动包装器（设置窗口标题后启动 claude）
│   └── manual-test.ps1          手动测试状态灯
├── hooks/
│   └── settings.template.json   Claude Hooks 配置模板
├── docs/
│   └── PRD.md                   产品需求文档
├── README.md                    本文件
└── PRD_Claude红绿灯状态提醒工具.docx  完整 PRD（Word）
```

## 窗口交互

- **拖拽**：左键按住小窗口任意位置拖动
- **左键单击**（窗口或托盘图标）：将 Claude 终端窗口带到前台（匹配窗口标题含 `Claude Code - TrafficLight` 或 `claude` 的终端）
- **右键托盘菜单**：
  - 「定位 Claude 终端」— 同单击
  - 「退出」— 关闭状态灯程序
- **Alt+Tab 隐藏**：小窗口设置了 `WS_EX_TOOLWINDOW`，不会出现在任务切换列表

## 构建与安装

在 PowerShell 中执行（需要 [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)）：

```powershell
cd <本项目根目录>
.\scripts\install.ps1
```

安装脚本会：

1. `dotnet publish` 发布为单文件 exe（Release / win-x64 / 自包含 false）
2. 复制 `signal.ps1`、`start-claude.cmd` 到安装目录
3. 生成 `%LOCALAPPDATA%\ClaudeLight\settings.generated.json`

## 配置 Claude Hooks

把 `%LOCALAPPDATA%\ClaudeLight\settings.generated.json` 里的 `hooks` 节点**合并**到：

```
%USERPROFILE%\.claude\settings.json
```

**注意**：如果已有 `hooks`，不要整文件覆盖，只把事件项合并进去。

支持的 Hook 事件：

| Hook 事件 | 映射状态 | 触发时机 |
|-----------|----------|----------|
| `SessionStart` | idle | Claude 会话开始 |
| `UserPromptSubmit` | thinking | 用户提交 prompt |
| `PreToolUse` | working | 即将调用工具 |
| `PostToolUse` | thinking | 工具调用完成，返回思考 |
| `PostToolUseFailure` | error | 工具调用失败 |
| `PostToolBatch` | thinking | 一批工具调用结束 |
| `PermissionRequest` | permission | 权限请求弹窗出现 |
| `Notification(permission_prompt)` | permission | 权限通知 |
| `Notification(idle_prompt)` | done | 任务完成通知 |
| `Stop` | done | 正常停止 |
| `StopFailure` | error | 停止失败 |
| `SessionEnd` | off | 会话结束 |

合并后，在 Claude CLI 输入 `/hooks` 确认对应事件已被识别。

## 启动方式

**方式一（推荐）**：用包装器启动

```cmd
%LOCALAPPDATA%\ClaudeLight\scripts\start-claude.cmd
```

它会将终端标题设为 `Claude Code - TrafficLight`，方便状态灯精确聚焦。

**方式二**：直接启动 Claude，让 Hooks 自动拉起状态灯

只要 Hooks 配置正确，Claude 一触发事件，`signal.ps1` 会自动启动 `ClaudeTrafficLight.exe`。

## 手动测试

```powershell
# 测试不同状态
%LOCALAPPDATA%\ClaudeLight\scripts\manual-test.ps1 thinking
%LOCALAPPDATA%\ClaudeLight\scripts\manual-test.ps1 working
%LOCALAPPDATA%\ClaudeLight\scripts\manual-test.ps1 permission
%LOCALAPPDATA%\ClaudeLight\scripts\manual-test.ps1 done
%LOCALAPPDATA%\ClaudeLight\scripts\manual-test.ps1 error
%LOCALAPPDATA%\ClaudeLight\scripts\manual-test.ps1 off
```

## 实现细节

**信号桥原子写入**：`signal.ps1` 使用 `.tmp + Move-Item` 方式写入 `status.json`，避免文件读取时读到不完整内容。

**会话日志**：每次写入 `status.json` 的同时，还会按 session_id 写入 `sessions/{session_id}.json`，可追溯每个会话的历史状态。

**单实例**：`Program.cs` 使用命名互斥锁 `Global\ClaudeTrafficLight_UserInstance`，防止同时启动多个实例。

**过期检测**：每 30 秒检查一次最后更新时间，超过 30 分钟无更新自动变为 Off 状态。

## 注意事项

- Windows 不建议程序强行自动 Pin 到任务栏；如需固定在任务栏，请手动右键固定发布的 exe
- 本工具只提醒，不自动批准 Claude 的权限请求
- 如果公司电脑执行策略限制 PowerShell，需允许当前用户执行本地脚本，或由管理员把 `signal.ps1` 加入可信路径
- 需要 .NET 8 Runtime（非 SDK 也能运行），安装脚本使用 `SelfContained=false`，所以目标机器需安装 .NET 8 运行时