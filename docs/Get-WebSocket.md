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
Get-WebSocket -SocketUrl "wss://localhost:9669/"
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
> EXAMPLE 5

```PowerShell
websocket wss://jetstream2.us-west.bsky.network/subscribe -QueryParameter @{ wantedCollections = 'app.bsky.feed.post' } -Max 1 -Debug
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
> EXAMPLE 7

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
> EXAMPLE 8

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
websocket wss://jetstream2.us-west.bsky.network/subscribe -QueryParameter @{
    wantedCollections = 'app.bsky.feed.post'
} -WatchFor @{
    {$webSocketoutput.commit.record.text -match "\#\w+"}={
        $matches.0
    }                
} -Maximum 1kb
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
> EXAMPLE 11

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
We can decorate a type returned from a WebSocket, allowing us to add additional properties.
For example, let's add a `Tags` property to the `app.bsky.feed.post` type.

```PowerShell
$typeName = 'app.bsky.feed.post'
Update-TypeData -TypeName $typeName -MemberName 'Tags' -MemberType ScriptProperty -Value {
    @($this.commit.record.facets.features.tag)
} -Force

# Now, let's get 10kb posts ( this should not take too long )
$somePosts =
    websocket "wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=$typeName" -PSTypeName $typeName -Maximum 10kb -Watch
$somePosts |
    ? Tags |
    Select -ExpandProperty Tags |
    Group |
    Sort Count -Descending |
    Select -First 10
```

---

### Parameters
#### **SocketUrl**
The WebSocket Uri.

|Type   |Required|Position|PipelineInput        |Aliases                                      |
|-------|--------|--------|---------------------|---------------------------------------------|
|`[Uri]`|false   |1       |true (ByPropertyName)|Url<br/>Uri<br/>WebSocketUri<br/>WebSocketUrl|

#### **RootUrl**
One or more root urls.
If these are provided, a WebSocket server will be created with these listener prefixes.

|Type        |Required|Position|PipelineInput        |Aliases                                                                              |
|------------|--------|--------|---------------------|-------------------------------------------------------------------------------------|
|`[String[]]`|true    |1       |true (ByPropertyName)|HostHeader<br/>Host<br/>CNAME<br/>ListenerPrefix<br/>ListenerPrefixes<br/>ListenerUrl|

#### **Route**
A route table for all requests.

|Type           |Required|Position|PipelineInput        |Aliases                                       |
|---------------|--------|--------|---------------------|----------------------------------------------|
|`[IDictionary]`|false   |named   |true (ByPropertyName)|Routes<br/>RouteTable<br/>WebHook<br/>WebHooks|

#### **HTML**
The Default HTML.
This will be displayed when visiting the root url.

|Type      |Required|Position|PipelineInput        |Aliases                                                     |
|----------|--------|--------|---------------------|------------------------------------------------------------|
|`[String]`|false   |named   |true (ByPropertyName)|DefaultHTML<br/>Home<br/>Index<br/>IndexHTML<br/>DefaultPage|

#### **PaletteName**
The name of the palette to use.  This will include the [4bitcss](https://4bitcss.com) stylesheet.

|Type      |Required|Position|PipelineInput        |Aliases                                 |
|----------|--------|--------|---------------------|----------------------------------------|
|`[String]`|false   |named   |true (ByPropertyName)|Palette<br/>ColorScheme<br/>ColorPalette|

#### **GoogleFont**
The [Google Font](https://fonts.google.com/) name.

|Type      |Required|Position|PipelineInput        |Aliases |
|----------|--------|--------|---------------------|--------|
|`[String]`|false   |named   |true (ByPropertyName)|FontName|

#### **CodeFont**
The Google Font name to use for code blocks.
(this should be a [monospace font](https://fonts.google.com/?classification=Monospace))

|Type      |Required|Position|PipelineInput        |Aliases                                 |
|----------|--------|--------|---------------------|----------------------------------------|
|`[String]`|false   |named   |true (ByPropertyName)|PreFont<br/>CodeFontName<br/>PreFontName|

#### **JavaScript**
A list of javascript files or urls to include in the content.

|Type        |Required|Position|PipelineInput        |
|------------|--------|--------|---------------------|
|`[String[]]`|false   |named   |true (ByPropertyName)|

#### **ImportMap**
A javascript import map.  This allows you to import javascript modules.

|Type           |Required|Position|PipelineInput        |Aliases                                                        |
|---------------|--------|--------|---------------------|---------------------------------------------------------------|
|`[IDictionary]`|false   |named   |true (ByPropertyName)|ImportsJavaScript<br/>JavaScriptImports<br/>JavaScriptImportMap|

#### **QueryParameter**
A collection of query parameters.
These will be appended onto the `-SocketUrl`.

|Type           |Required|Position|PipelineInput        |
|---------------|--------|--------|---------------------|
|`[IDictionary]`|false   |named   |true (ByPropertyName)|

#### **Handler**
A ScriptBlock that will handle the output of the WebSocket.

|Type           |Required|Position|PipelineInput|
|---------------|--------|--------|-------------|
|`[ScriptBlock]`|false   |named   |false        |

#### **ForwardEvent**
If set, will forward websocket messages as events.
Only events that match -Filter will be forwarded.

|Type      |Required|Position|PipelineInput        |Aliases|
|----------|--------|--------|---------------------|-------|
|`[Switch]`|false   |named   |true (ByPropertyName)|Forward|

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

#### **Broadcast**

|Type        |Required|Position|PipelineInput|
|------------|--------|--------|-------------|
|`[PSObject]`|false   |named   |false        |

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

#### **Force**
If set, will force a new job to be created, rather than reusing an existing job.

|Type      |Required|Position|PipelineInput|
|----------|--------|--------|-------------|
|`[Switch]`|false   |named   |false        |

#### **SubProtocol**
The subprotocol used by the websocket.  If not provided, this will default to `json`.

|Type      |Required|Position|PipelineInput        |
|----------|--------|--------|---------------------|
|`[String]`|false   |named   |true (ByPropertyName)|

#### **Filter**
One or more filters to apply to the output of the WebSocket.
These can be strings, regexes, scriptblocks, or commands.
If they are strings or regexes, they will be applied to the raw text.
If they are scriptblocks, they will be applied to the deserialized JSON.
These filters will be run within the WebSocket job.

|Type          |Required|Position|PipelineInput        |
|--------------|--------|--------|---------------------|
|`[PSObject[]]`|false   |named   |true (ByPropertyName)|

#### **WatchFor**
If set, will watch the output of a WebSocket job for one or more conditions.
The conditions are the keys of the dictionary, and can be a regex, a string, or a scriptblock.
The values of the dictionary are what will happen when a match is found.

|Type           |Required|Position|PipelineInput        |Aliases               |
|---------------|--------|--------|---------------------|----------------------|
|`[IDictionary]`|false   |named   |true (ByPropertyName)|WhereFor<br/>Wherefore|

#### **TimeOut**
The timeout for the WebSocket connection.  If this is provided, after the timeout elapsed, the WebSocket will be closed.

|Type        |Required|Position|PipelineInput|
|------------|--------|--------|-------------|
|`[TimeSpan]`|false   |named   |false        |

#### **PSTypeName**
If provided, will decorate the objects outputted from a websocket job.
This will only decorate objects converted from JSON.

|Type        |Required|Position|PipelineInput        |Aliases                                |
|------------|--------|--------|---------------------|---------------------------------------|
|`[String[]]`|false   |named   |true (ByPropertyName)|PSTypeNames<br/>Decorate<br/>Decoration|

#### **Maximum**
The maximum number of messages to receive before closing the WebSocket.

|Type     |Required|Position|PipelineInput|
|---------|--------|--------|-------------|
|`[Int64]`|false   |named   |false        |

#### **ThrottleLimit**
The throttle limit used when creating background jobs.

|Type     |Required|Position|PipelineInput|
|---------|--------|--------|-------------|
|`[Int32]`|false   |named   |false        |

#### **ConnectionTimeout**
The maximum time to wait for a connection to be established.
By default, this is 7 seconds.

|Type        |Required|Position|PipelineInput        |
|------------|--------|--------|---------------------|
|`[TimeSpan]`|false   |named   |true (ByPropertyName)|

#### **Runspace**
The Runspace where the handler should run.
Runspaces allow you to limit the scope of the handler.

|Type        |Required|Position|PipelineInput        |
|------------|--------|--------|---------------------|
|`[Runspace]`|false   |named   |true (ByPropertyName)|

#### **RunspacePool**
The RunspacePool where the handler should run.
RunspacePools allow you to limit the scope of the handler to a pool of runspaces.

|Type            |Required|Position|PipelineInput        |Aliases|
|----------------|--------|--------|---------------------|-------|
|`[RunspacePool]`|false   |named   |true (ByPropertyName)|Pool   |

#### **IncludeTotalCount**

|Type      |Required|Position|PipelineInput|
|----------|--------|--------|-------------|
|`[Switch]`|false   |named   |false        |

#### **Skip**

|Type      |Required|Position|PipelineInput|
|----------|--------|--------|-------------|
|`[UInt64]`|false   |named   |false        |

#### **First**

|Type      |Required|Position|PipelineInput|
|----------|--------|--------|-------------|
|`[UInt64]`|false   |named   |false        |

---

### Syntax
```PowerShell
Get-WebSocket [[-SocketUrl] <Uri>] [-QueryParameter <IDictionary>] [-ForwardEvent] [-Variable <IDictionary>] [-Name <String>] [-InitializationScript <ScriptBlock>] [-BufferSize <Int32>] [-Broadcast <PSObject>] [-OnConnect <ScriptBlock>] [-OnError <ScriptBlock>] [-OnOutput <ScriptBlock>] [-OnWarning <ScriptBlock>] [-Watch] [-RawText] [-Binary] [-Force] [-SubProtocol <String>] [-Filter <PSObject[]>] [-WatchFor <IDictionary>] [-TimeOut <TimeSpan>] [-PSTypeName <String[]>] [-Maximum <Int64>] [-ThrottleLimit <Int32>] [-ConnectionTimeout <TimeSpan>] [-Runspace <Runspace>] [-RunspacePool <RunspacePool>] [-IncludeTotalCount] [-Skip <UInt64>] [-First <UInt64>] [<CommonParameters>]
```
```PowerShell
Get-WebSocket [-RootUrl] <String[]> [-Route <IDictionary>] [-HTML <String>] [-PaletteName <String>] [-GoogleFont <String>] [-CodeFont <String>] [-JavaScript <String[]>] [-ImportMap <IDictionary>] [-Handler <ScriptBlock>] [-Variable <IDictionary>] [-Name <String>] [-InitializationScript <ScriptBlock>] [-BufferSize <Int32>] [-Broadcast <PSObject>] [-Force] [-TimeOut <TimeSpan>] [-Maximum <Int64>] [-ThrottleLimit <Int32>] [-IncludeTotalCount] [-Skip <UInt64>] [-First <UInt64>] [<CommonParameters>]
```
