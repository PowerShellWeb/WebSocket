<div align='center'>
    <img alt='WebSocket Logo (Animated)' style='height:50%' src='Assets/WebSocket-Animated.svg' />
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

#### Get-WebSocket Example 1

~~~powershell
# Create a WebSocket job that connects to a WebSocket and outputs the results.
Get-WebSocket -WebSocketUri "wss://localhost:9669"
~~~
 #### Get-WebSocket Example 2

~~~powershell
# Get is the default verb, so we can just say WebSocket.
websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post
~~~
 #### Get-WebSocket Example 3

~~~powershell
websocket jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail |
    Foreach-Object {
        $in = $_
        if ($in.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+') {
            Write-Host $matches.0 -NoNewline
        }
    }
~~~
 #### Get-WebSocket Example 4

~~~powershell
$emojiPattern = '[\p{IsHighSurrogates}\p{IsLowSurrogates}\p{IsVariationSelectors}\p{IsCombiningHalfMarks}]+)'
websocket jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail |
    Foreach-Object {
        $in = $_
        $spacing = (' ' * (Get-Random -Minimum 0 -Maximum 7))
        if ($in.commit.record.text -match "(?>(?:$emojiPattern|\#\w+)") {
            $match = $matches.0                    
            Write-Host $spacing,$match,$spacing -NoNewline
        }
    }
~~~
 #### Get-WebSocket Example 5

~~~powershell
websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch |
    Where-Object {
        $_.commit.record.embed.'$type' -eq 'app.bsky.embed.external'
    } |
    Foreach-Object {
        $_.commit.record.embed.external.uri
    }
~~~
 #### Get-WebSocket Example 6

~~~powershell

~~~
