Get-WebSocket
-------------

### Synopsis
WebSockets in PowerShell.

---

### Description

Get-WebSocket allows you to connect to a websocket and handle the output.

---

### Examples
Create a WebSocket job that connects to a WebSocket and outputs the results.

```PowerShell
Get-WebSocket -WebSocketUri "wss://localhost:9669"
```
Get is the default verb, so we can just say WebSocket.

```PowerShell
websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post
```
> EXAMPLE 3

```PowerShell
websocket jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail |
    Foreach-Object {
        $in = $_
        if ($in.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+') {
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
If set, will tail the output of the WebSocket job, outputting results continuously instead of outputting a websocket job.

|Type      |Required|Position|PipelineInput|
|----------|--------|--------|-------------|
|`[Switch]`|false   |named   |false        |

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
Get-WebSocket [[-WebSocketUri] <Uri>] [-Handler <ScriptBlock>] [-Variable <IDictionary>] [-Name <String>] [-InitializationScript <ScriptBlock>] [-BufferSize <Int32>] [-OnConnect <ScriptBlock>] [-OnError <ScriptBlock>] [-OnOutput <ScriptBlock>] [-OnWarning <ScriptBlock>] [-Watch] [-ConnectionTimeout <TimeSpan>] [-Runspace <Runspace>] [-RunspacePool <RunspacePool>] [<CommonParameters>]
```
