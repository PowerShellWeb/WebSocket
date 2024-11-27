<div align='center'>
    <img alt='WebSocket Logo (Animated)' style='height:50%' src='Assets/WebSocket-Animated.svg' />
</div>

# WebSocket

Work with WebSockets in PowerShell

WebSocket is a small PowerShell module that helps you work with WebSockets.

It has a single command:  Get-WebSocket.

Because `Get` is the default verb in PowerShell, you can just call it `WebSocket`.


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