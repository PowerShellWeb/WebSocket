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

#### Get-WebSocket Example 1

~~~powershell
# Create a WebSocket job that connects to a WebSocket and outputs the results.
$socketServer = Get-WebSocket -RootUrl "http://localhost:8387/" -HTML "<h1>WebSocket Server</h1>"
$socketClient = Get-WebSocket -SocketUrl "ws://localhost:8387/"
foreach ($n in 1..10) { $socketServer.Send(@{n=Get-Random}) }
$socketClient | Receive-Job -Keep
~~~
 #### Get-WebSocket Example 2

~~~powershell
# Get is the default verb, so we can just say WebSocket.
# `-Watch` will output a continous stream of objects from the websocket.
# For example, let's Watch BlueSky, but just the text 
websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch -Maximum 1kb |
    % { 
        $_.commit.record.text
    }
~~~
 #### Get-WebSocket Example 3

~~~powershell
# Watch BlueSky, but just the text and spacing
$blueSkySocketUrl = "wss://jetstream2.us-$(
    'east','west'|Get-Random
).bsky.network/subscribe?$(@(
    "wantedCollections=app.bsky.feed.post"
) -join '&')"
websocket $blueSkySocketUrl -Watch | 
    % { Write-Host "$(' ' * (Get-Random -Max 10))$($_.commit.record.text)$($(' ' * (Get-Random -Max 10)))"} -Max 1kb
~~~
 #### Get-WebSocket Example 4

~~~powershell
# Watch continuously in a background job.
websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post
~~~
 #### Get-WebSocket Example 5

~~~powershell
# Watch the first message in -Debug mode.  
# This allows you to literally debug the WebSocket messages as they are encountered.
websocket wss://jetstream2.us-west.bsky.network/subscribe -QueryParameter @{
    wantedCollections = 'app.bsky.feed.post'
} -Max 1 -Debug
~~~
 #### Get-WebSocket Example 6

~~~powershell
# Watch BlueSky, but just the emoji
websocket jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail -Max 1kb |
    Foreach-Object {
        $in = $_
        if ($in.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+') {
            Write-Host $matches.0 -NoNewline
        }
    }
~~~
 #### Get-WebSocket Example 7

~~~powershell
$emojiPattern = '[\p{IsHighSurrogates}\p{IsLowSurrogates}\p{IsVariationSelectors}\p{IsCombiningHalfMarks}]+)'
websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail |
    Foreach-Object {
        $in = $_
        $spacing = (' ' * (Get-Random -Minimum 0 -Maximum 7))
        if ($in.commit.record.text -match "(?>(?:$emojiPattern|\#\w+)") {
            $match = $matches.0                    
            Write-Host $spacing,$match,$spacing -NoNewline
        }
    }
~~~
 #### Get-WebSocket Example 8

~~~powershell
websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch |
    Where-Object {
        $_.commit.record.embed.'$type' -eq 'app.bsky.embed.external'
    } |
    Foreach-Object {
        $_.commit.record.embed.external.uri
    }
~~~
 #### Get-WebSocket Example 9

~~~powershell
# BlueSky, but just the hashtags
websocket wss://jetstream2.us-west.bsky.network/subscribe -QueryParameter @{
    wantedCollections = 'app.bsky.feed.post'
} -WatchFor @{
    {$webSocketoutput.commit.record.text -match "\#\w+"}={
        $matches.0
    }                
} -Maximum 1kb
~~~
 #### Get-WebSocket Example 10

~~~powershell
# BlueSky, but just the hashtags (as links)
websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -WatchFor @{
    {$webSocketoutput.commit.record.text -match "\#\w+"}={
        if ($psStyle.FormatHyperlink) {
            $psStyle.FormatHyperlink($matches.0, "https://bsky.app/search?q=$([Web.HttpUtility]::UrlEncode($matches.0))")
        } else {
            $matches.0
        }
    }
}
~~~
 #### Get-WebSocket Example 11

~~~powershell
websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -WatchFor @{
    {$args.commit.record.text -match "\#\w+"}={
        $matches.0
    }
    {$args.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+'}={
        $matches.0
    }
}
~~~
 #### Get-WebSocket Example 12

~~~powershell
# We can decorate a type returned from a WebSocket, allowing us to add additional properties.
~~~

