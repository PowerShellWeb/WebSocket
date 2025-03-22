@{
    ModuleVersion = '0.1.3'
    RootModule = 'WebSocket.psm1'
    Guid = '75c70c8b-e5eb-4a60-982e-a19110a1185d'
    Author = 'James Brundage'
    CompanyName = 'StartAutomating'
    Copyright = '2024 StartAutomating'
    Description = 'Work with WebSockets in PowerShell'
    FunctionsToExport = @('Get-WebSocket')
    AliasesToExport = @('WebSocket','ws','wss')
    FormatsToProcess = @('WebSocket.format.ps1xml')
    TypesToProcess = @('WebSocket.types.ps1xml')
    PrivateData = @{
        PSData = @{
            Tags = @('WebSocket', 'WebSockets', 'Networking', 'Web')
            ProjectURI = 'https://github.com/PowerShellWeb/WebSocket'
            LicenseURI = 'https://github.com/PowerShellWeb/WebSocket/blob/main/LICENSE'
            ReleaseNotes = @'
> Like It? [Star It](https://github.com/PowerShellWeb/WebSocket)
> Love It? [Support It](https://github.com/sponsors/StartAutomating)

## WebSocket 0.1.3

WebSocket server support!

### Server Features

For consistency, capabilities, and aesthetics,
this is a fairly fully features HTTP server that happens to support websockets

* `Get-WebSocket` `-RootURL/-HostHeader` ( #47 )
* `-StyleSheet` lets you include stylesheets ( #64 )
* `-JavaScript` lets you include javascript ( #65 )
* `-Timeout/-LifeSpan` server support ( #85 )

### Client Improvements

* `Get-WebSocket -QueryParameter` lets you specify query parameters ( #41 ) 
* `Get-WebSocket  -Debug` lets you debug the websocketjob. ( #45 )
* `Get-WebSocket -SubProtocol` lets you specify a subprotocol (defaults to JSON) ( #46 )
* `Get-WebSocket -Authenticate` allows sends pre-connection authentication ( #69 )
* `Get-WebSocket -Handshake` allows post-connection authentication ( #81 )
* `Get-WebSocket -Force` allows the creation of multiple clients ( #58 )


### General Improvements

* `Get-WebSocket -SupportsPaging` ( #55 )
* `Get-WebSocket -BufferSize 64kb` ( #52 )
* `Get-WebSocket -Force` ( #58 )
* `Get-WebSocket -Filter` ( #42 )
* `Get-WebSocket -ForwardEvent` ( #56 )
* `Get-WebSocket` Parameter Sets ( #73, #74 )
* `-Broadcast` lets you broadcast to clients and servers ( #39 )
* `Get-WebSocket` quieting previous job check ( #43 )

---

Additional details available in the [CHANGELOG](https://github.com/PowerShellWeb/WebSocket/blob/main/CHANGELOG.md)
'@
        }
    }
}