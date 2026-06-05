$settingsFile = "$env:USERPROFILE\.claude\settings.json"
$content = Get-Content $settingsFile -Raw
if ($content -match '"hooks"') {
    exit 0
}
$hooksFile = "C:\Users\ChengXiao\ClaudeTrafficLight\.claude\settings.json"
$hooks = Get-Content $hooksFile -Raw
$clean = $content.TrimEnd() -replace '}\s*$', ''
$merged = $clean + ",`r`n  " + $hooks.Substring(1)
$merged | Set-Content $settingsFile -Encoding UTF8