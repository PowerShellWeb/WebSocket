@{
    ModuleVersion = '0.1.1'
    RootModule = 'WebSocket.psm1'
    Guid = '75c70c8b-e5eb-4a60-982e-a19110a1185d'
    Author = 'James Brundage'
    CompanyName = 'StartAutomating'
    Copyright = '2024 StartAutomating'
    Description = 'Work with WebSockets in PowerShell'
    PrivateData = @{
        PSData = @{
            Tags = @('WebSocket', 'WebSockets', 'Networking', 'Web')
            ProjectURI = 'https://github.com/PowerShellWeb/WebSocket'
            LicenseURI = 'https://github.com/PowerShellWeb/WebSocket/blob/main/LICENSE'
            ReleaseNotes = @'
> Like It? [Star It](https://github.com/PowerShellWeb/WebSocket)
> Love It? [Support It](https://github.com/sponsors/StartAutomating)

## WebSocket 0.1.1

* WebSocket GitHub Action
  * Run any `*.WebSocket.ps1` files in a repository (#24)
* WebSocket container updates
  * Container now runs mounted `*.WebSocket.ps1` files (#26)
* Get-WebSocket improvements:
  * New Parameters:
    * -Maximum (#22)
    * -TimeOut (#23)
    * -WatchFor (#29)
    * -RawText (#30)
    * -Binary (#31)
* WebSocket Testing (#25)
* Adding FUNDING.yml (#14)

---

Additional details available in the [CHANGELOG](CHANGELOG.md)
'@
        }
    }
}