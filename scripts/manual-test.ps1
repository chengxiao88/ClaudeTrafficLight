param(
    [ValidateSet("idle","done","thinking","working","permission","error","off")]
    [string]$State = "done"
)

& "$PSScriptRoot\signal.ps1" $State
Write-Host "已发送测试状态：$State"
