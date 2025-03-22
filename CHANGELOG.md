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

## WebSocket 0.1.2

* WebSocket now decorates (#34)
  * Added a -PSTypeName(s) parameter to Get-WebSocket, so we can extend the output.
* Reusing WebSockets (#35)
  * If a WebSocketUri is already open, we will reuse it.
* Explicitly exporting commands (#38)
  * This should enable automatic import and enable Find-Command

---

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
  
## WebSocket 0.1

* Initial Release of WebSocket module
  * Get-WebSocket gets content from a WebSocket
  * Docker container for WebSocket
  * Build Workflow
    * WebSocket Logo
    * WebSocket website