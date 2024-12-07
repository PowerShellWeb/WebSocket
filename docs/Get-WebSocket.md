Get-WebSocket
-------------

### Synopsis
WebSockets in PowerShell.

---

### Description

Get-WebSocket gets a websocket.

This will create a job that connects to a WebSocket and outputs the results.

If the `-Watch` parameter is provided, will output a continous stream of objects.

---

### Examples
Create a WebSocket job that connects to a WebSocket and outputs the results.

```PowerShell
Get-WebSocket -WebSocketUri "wss://localhost:9669/"
```
Get is the default verb, so we can just say WebSocket.
`-Watch` will output a continous stream of objects from the websocket.
For example, let's Watch BlueSky, but just the text.        

```PowerShell
websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch |
    % { 
        $_.commit.record.text
    }
```
Watch BlueSky, but just the text and spacing

```PowerShell
$blueSkySocketUrl = "wss://jetstream2.us-$(
    'east','west'|Get-Random
).bsky.network/subscribe?$(@(
    "wantedCollections=app.bsky.feed.post"
) -join '&')"
websocket $blueSkySocketUrl -Watch | 
    % { Write-Host "$(' ' * (Get-Random -Max 10))$($_.commit.record.text)$($(' ' * (Get-Random -Max 10)))"}
```
> EXAMPLE 4

```PowerShell
websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post
```
Watch BlueSky, but just the emoji

```PowerShell
websocket jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail |
    Foreach-Object {
        $in = $_
        if ($in.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+') {
            Write-Host $matches.0 -NoNewline
        }
    }
```
> EXAMPLE 6

```PowerShell
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
```
> EXAMPLE 7

```PowerShell
websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch |
    Where-Object {
        $_.commit.record.embed.'$type' -eq 'app.bsky.embed.external'
    } |
    Foreach-Object {
        $_.commit.record.embed.external.uri
    }
```
BlueSky, but just the hashtags

```PowerShell
websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -WatchFor @{
    {$webSocketoutput.commit.record.text -match "\#\w+"}={
        $matches.0
    }                
}
```
BlueSky, but just the hashtags (as links)

```PowerShell
websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -WatchFor @{
    {$webSocketoutput.commit.record.text -match "\#\w+"}={
        if ($psStyle.FormatHyperlink) {
            $psStyle.FormatHyperlink($matches.0, "https://bsky.app/search?q=$([Web.HttpUtility]::UrlEncode($matches.0))")
        } else {
            $matches.0
        }
    }
}
```
> EXAMPLE 10

```PowerShell
websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -WatchFor @{
    {$args.commit.record.text -match "\#\w+"}={
        $matches.0
    }
    {$args.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+'}={
        $matches.0
    }
}
```

---

### Parameters
#### **WebSocketUri**
The Uri of the WebSocket to connect to.

|Type   |Required|Position|PipelineInput        |Aliases    |
|-------|--------|--------|---------------------|-----------|
|`[Uri]`|false   |1       |true (ByPropertyName)|Url<br/>Uri|

#### **Handler**
A ScriptBlock that will handle the output of the WebSocket.

|Type           |Required|Position|PipelineInput|
|---------------|--------|--------|-------------|
|`[ScriptBlock]`|false   |named   |false        |

#### **Variable**
Any variables to declare in the WebSocket job.
These variables will also be added to the job as properties.

|Type           |Required|Position|PipelineInput|
|---------------|--------|--------|-------------|
|`[IDictionary]`|false   |named   |false        |

#### **Name**
The name of the WebSocket job.

|Type      |Required|Position|PipelineInput|
|----------|--------|--------|-------------|
|`[String]`|false   |named   |false        |

#### **InitializationScript**
The script to run when the WebSocket job starts.

|Type           |Required|Position|PipelineInput|
|---------------|--------|--------|-------------|
|`[ScriptBlock]`|false   |named   |false        |

#### **BufferSize**
The buffer size.  Defaults to 16kb.

|Type     |Required|Position|PipelineInput|
|---------|--------|--------|-------------|
|`[Int32]`|false   |named   |false        |

#### **OnConnect**
The ScriptBlock to run after connection to a websocket.
This can be useful for making any initial requests.

|Type           |Required|Position|PipelineInput|
|---------------|--------|--------|-------------|
|`[ScriptBlock]`|false   |named   |false        |

#### **OnError**
The ScriptBlock to run when an error occurs.

|Type           |Required|Position|PipelineInput|
|---------------|--------|--------|-------------|
|`[ScriptBlock]`|false   |named   |false        |

#### **OnOutput**
The ScriptBlock to run when the WebSocket job outputs an object.

|Type           |Required|Position|PipelineInput|
|---------------|--------|--------|-------------|
|`[ScriptBlock]`|false   |named   |false        |

#### **OnWarning**
The Scriptblock to run when the WebSocket job produces a warning.

|Type           |Required|Position|PipelineInput|
|---------------|--------|--------|-------------|
|`[ScriptBlock]`|false   |named   |false        |

#### **Watch**
If set, will watch the output of the WebSocket job, outputting results continuously instead of outputting a websocket job.

|Type      |Required|Position|PipelineInput|Aliases|
|----------|--------|--------|-------------|-------|
|`[Switch]`|false   |named   |false        |Tail   |

#### **RawText**
If set, will output the raw text that comes out of the WebSocket.

|Type      |Required|Position|PipelineInput|Aliases|
|----------|--------|--------|-------------|-------|
|`[Switch]`|false   |named   |false        |Raw    |

#### **Binary**
If set, will output the raw bytes that come out of the WebSocket.

|Type      |Required|Position|PipelineInput|Aliases                                |
|----------|--------|--------|-------------|---------------------------------------|
|`[Switch]`|false   |named   |false        |RawByte<br/>RawBytes<br/>Bytes<br/>Byte|

#### **WatchFor**
If set, will watch the output of a WebSocket job for one or more conditions.
The conditions are the keys of the dictionary, and can be a regex, a string, or a scriptblock.
The values of the dictionary are what will happen when a match is found.

|Type           |Required|Position|PipelineInput|Aliases               |
|---------------|--------|--------|-------------|----------------------|
|`[IDictionary]`|false   |named   |false        |WhereFor<br/>Wherefore|

#### **TimeOut**
The timeout for the WebSocket connection.  If this is provided, after the timeout elapsed, the WebSocket will be closed.

|Type        |Required|Position|PipelineInput|
|------------|--------|--------|-------------|
|`[TimeSpan]`|false   |named   |false        |

#### **PSTypeName**
If provided, will decorate the objects outputted from a websocket job.
This will only decorate objects converted from JSON.

|Type        |Required|Position|PipelineInput|Aliases                                |
|------------|--------|--------|-------------|---------------------------------------|
|`[String[]]`|false   |named   |false        |PSTypeNames<br/>Decorate<br/>Decoration|

#### **Maximum**
The maximum number of messages to receive before closing the WebSocket.

|Type     |Required|Position|PipelineInput|
|---------|--------|--------|-------------|
|`[Int64]`|false   |named   |false        |

#### **ConnectionTimeout**
The maximum time to wait for a connection to be established.
By default, this is 7 seconds.

|Type        |Required|Position|PipelineInput|
|------------|--------|--------|-------------|
|`[TimeSpan]`|false   |named   |false        |

#### **Runspace**
The Runspace where the handler should run.
Runspaces allow you to limit the scope of the handler.

|Type        |Required|Position|PipelineInput|
|------------|--------|--------|-------------|
|`[Runspace]`|false   |named   |false        |

#### **RunspacePool**
The RunspacePool where the handler should run.
RunspacePools allow you to limit the scope of the handler to a pool of runspaces.

|Type            |Required|Position|PipelineInput|Aliases|
|----------------|--------|--------|-------------|-------|
|`[RunspacePool]`|false   |named   |false        |Pool   |

---

### Syntax
```PowerShell
Get-WebSocket [[-WebSocketUri] <Uri>] [-Handler <ScriptBlock>] [-Variable <IDictionary>] [-Name <String>] [-InitializationScript <ScriptBlock>] [-BufferSize <Int32>] [-OnConnect <ScriptBlock>] [-OnError <ScriptBlock>] [-OnOutput <ScriptBlock>] [-OnWarning <ScriptBlock>] [-Watch] [-RawText] [-Binary] [-WatchFor <IDictionary>] [-TimeOut <TimeSpan>] [-PSTypeName <String[]>] [-Maximum <Int64>] [-ConnectionTimeout <TimeSpan>] [-Runspace <Runspace>] [-RunspacePool <RunspacePool>] [<CommonParameters>]
```
