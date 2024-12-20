@{
    ModuleVersion = '0.1.2'
    RootModule = 'WebSocket.psm1'
    Guid = '75c70c8b-e5eb-4a60-982e-a19110a1185d'
    Author = 'James Brundage'
    CompanyName = 'StartAutomating'
    Copyright = '2024 StartAutomating'
    Description = 'Work with WebSockets in PowerShell'
    FunctionsToExport = @('Get-WebSocket')
    AliasesToExport = @('WebSocket')
    PrivateData = @{
        PSData = @{
            Tags = @('WebSocket', 'WebSockets', 'Networking', 'Web')
            ProjectURI = 'https://github.com/PowerShellWeb/WebSocket'
            LicenseURI = 'https://github.com/PowerShellWeb/WebSocket/blob/main/LICENSE'
            ReleaseNotes = @'
> Like It? [Star It](https://github.com/PowerShellWeb/WebSocket)
> Love It? [Support It](https://github.com/sponsors/StartAutomating)

## WebSocket 0.1.2

* WebSocket now decorates (#34)
  * Added a -PSTypeName(s) parameter to Get-WebSocket, so we can extend the output.
* Reusing WebSockets (#35)
  * If a WebSocketUri is already open, we will reuse it.
* Explicitly exporting commands (#38)
  * This should enable automatic import and enable Find-Command

---

Additional details available in the [CHANGELOG](CHANGELOG.md)
'@
        }
    }
}