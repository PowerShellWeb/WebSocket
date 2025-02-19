<div align='center'>
    <img alt='WebSocket Logo (Animated)' style='width:33%' src='Assets/WebSocket-Animated.svg' />
    <br />
    <a href='https://www.powershellgallery.com/packages/WebSocket/'>
        <img src='https://img.shields.io/powershellgallery/dt/WebSocket' />
    </a>
</div>

# WebSocket

Work with WebSockets in PowerShell

WebSocket is a small PowerShell module that helps you work with WebSockets.

It has a single command:  Get-WebSocket.

Because `Get` is the default verb in PowerShell, you can just call it `WebSocket`.

## WebSocket Container

You can use the WebSocket module within a container:

~~~powershell
docker pull ghcr.io/powershellweb/websocket
docker run -it ghcr.io/powershellweb/websocket
~~~

### Installing and Importing

~~~PowerShell
Install-Module WebSocket -Scope CurrentUser -Force
Import-Module WebSocket -Force -PassThru
~~~

### Get-WebSocket

To connect to a websocket and start listening for results, use [Get-WebSocket](Get-WebSocket.md)

~~~PowerShell
# Because get is the default verb, we can just say `WebSocket`
# The `-Watch` parameter will continually watch for results
websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch
~~~

To stop watching a websocket, simply stop the background job.

### More Examples

~~~PipeScript{
Import-Module .\ 
Get-Help Get-WebSocket | 
    %{ $_.Examples.Example.code} |
    % -Begin { $exampleCount = 0 } -Process {
        $exampleCount++
        @(
            "#### Get-WebSocket Example $exampleCount" 
            ''         
            "~~~powershell"
            $_
            "~~~"
            ''
        ) -join [Environment]::Newline
    }
}
~~~