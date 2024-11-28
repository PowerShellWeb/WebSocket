#requires -Module PSDevOps
Import-BuildStep -SourcePath (
    Join-Path $PSScriptRoot 'GitHub'
) -BuildSystem GitHubAction

$PSScriptRoot | Split-Path | Push-Location

New-GitHubAction -Name "UseWebSocket" -Description 'Work with WebSockets in PowerShell' -Action WebSocketAction -Icon chevron-right -OutputPath .\action.yml

Pop-Location