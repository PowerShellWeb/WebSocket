function Get-WebSocket {
    <#
    .SYNOPSIS
        WebSockets in PowerShell.
    .DESCRIPTION
        Get-WebSocket allows you to connect to a websocket and handle the output.
    .EXAMPLE
        # Create a WebSocket job that connects to a WebSocket and outputs the results.
        Get-WebSocket -WebSocketUri "wss://localhost:9669" 
    .EXAMPLE
        # Get is the default verb, so we can just say WebSocket.
        websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post
    .EXAMPLE
        websocket jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail |
            Foreach-Object {
                $in = $_
                if ($in.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+') {
                    Write-Host $matches.0 -NoNewline
                }
            }
    .EXAMPLE
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
    .EXAMPLE
        websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch |
            Where-Object {
                $_.commit.record.embed.'$type' -eq 'app.bsky.embed.external'
            } |
            Foreach-Object {
                $_.commit.record.embed.external.uri
            }
    .EXAMPLE
                    
    #>
    [CmdletBinding(PositionalBinding=$false)]
    param(
    # The Uri of the WebSocket to connect to.
    [Parameter(Position=0,ValueFromPipelineByPropertyName)]
    [Alias('Url','Uri')]
    [uri]$WebSocketUri,

    # A ScriptBlock that will handle the output of the WebSocket.
    [ScriptBlock]
    $Handler,

    # Any variables to declare in the WebSocket job.
    [Collections.IDictionary]
    $Variable = @{},

    # The name of the WebSocket job.
    [string]
    $Name,

    # The script to run when the WebSocket job starts.
    [ScriptBlock]
    $InitializationScript = {},

    # The buffer size.  Defaults to 16kb.
    [int]
    $BufferSize = 16kb,

    # The ScriptBlock to run after connection to a websocket.
    # This can be useful for making any initial requests.
    [ScriptBlock]
    $OnConnect,

    # The ScriptBlock to run when an error occurs.
    [ScriptBlock]
    $OnError,

    # The ScriptBlock to run when the WebSocket job outputs an object.
    [ScriptBlock]
    $OnOutput,

    # The Scriptblock to run when the WebSocket job produces a warning.
    [ScriptBlock]
    $OnWarning,

    # If set, will watch the output of the WebSocket job, outputting results continuously instead of outputting a websocket job.    
    [Alias('Tail')]
    [switch]
    $Watch,

    # The timeout for the WebSocket connection.  If this is provided, after the timeout elapsed, the WebSocket will be closed.
    [TimeSpan]
    $TimeOut,    

    # The maximum time to wait for a connection to be established.
    # By default, this is 7 seconds.
    [TimeSpan]
    $ConnectionTimeout = '00:00:07',

    # The Runspace where the handler should run.
    # Runspaces allow you to limit the scope of the handler.
    [Runspace]
    $Runspace,

    # The RunspacePool where the handler should run.
    # RunspacePools allow you to limit the scope of the handler to a pool of runspaces.
    [Management.Automation.Runspaces.RunspacePool]
    [Alias('Pool')]
    $RunspacePool
    )

    begin {
        $SocketJob = {
            param([Collections.IDictionary]$Variable)
            
            foreach ($keyValue in $variable.GetEnumerator()) {
                $ExecutionContext.SessionState.PSVariable.Set($keyValue.Key, $keyValue.Value)
            }

            if ((-not $WebSocketUri) -or $webSocket) {
                throw "No WebSocketUri"
            }

            if (-not $WebSocketUri.Scheme) {
                $WebSocketUri = [uri]"wss://$WebSocketUri"
            }

            if (-not $BufferSize) {
                $BufferSize = 16kb
            }

            $CT = [Threading.CancellationToken]::None
            
            if (-not $webSocket) {
                $ws = [Net.WebSockets.ClientWebSocket]::new()
                $null = $ws.ConnectAsync($WebSocketUri, $CT).Wait()
            } else {
                $ws = $WebSocket
            }

            $webSocketStartTime = $Variable.WebSocketStartTime = [DateTime]::Now
            $Variable.WebSocket = $ws
                                    
            
            while ($true) {
                if ($ws.State -ne 'Open') {break }
                if ($TimeOut -and ([DateTime]::Now - $webSocketStartTime) -gt $TimeOut) {
                    $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Timeout', $CT).Wait()
                    break
                }
                $Buf = [byte[]]::new($BufferSize)
                $Seg = [ArraySegment[byte]]::new($Buf)
                $null = $ws.ReceiveAsync($Seg, $CT).Wait()
                $JS = $OutputEncoding.GetString($Buf, 0, $Buf.Count)
                if ([string]::IsNullOrWhitespace($JS)) { continue }
                try { 
                    $webSocketMessage = ConvertFrom-Json $JS
                    if ($handler) {
                        $psCmd =  
                            if ($runspace.LanguageMode -eq 'NoLanguage' -or 
                                $runspacePool.InitialSessionState.LanguageMode -eq 'NoLanguage') {
                                $handler.GetPowerShell()
                            } elseif ($Runspace -or $RunspacePool) {
                                [PowerShell]::Create().AddScript($handler)
                            }
                        if ($psCmd) {
                            if ($Runspace) {
                                $psCmd.Runspace = $Runspace
                            } elseif ($RunspacePool) {
                                $psCmd.RunspacePool = $RunspacePool
                            }
                        } else {
                            $webSocketMessage | . $handler
                        }
                        
                    } else {
                        $webSocketMessage
                    }                    
                } catch { 
                    Write-Error $_
                }
            }
        }                        
    }

    process {
        foreach ($keyValuePair in $PSBoundParameters.GetEnumerator()) {
            $Variable[$keyValuePair.Key] = $keyValuePair.Value
        }
        $webSocketJob = 
            if ($WebSocketUri) {
                if (-not $name) {
                    $Name = $WebSocketUri
                }
                
                Start-ThreadJob -ScriptBlock $SocketJob -Name $Name -InitializationScript $InitializationScript -ArgumentList $Variable
            } elseif ($WebSocket) {
                if (-not $name) {
                    $name = "websocket"
                }
                Start-ThreadJob -ScriptBlock $SocketJob -Name $Name -InitializationScript $InitializationScript -ArgumentList $Variable
            }

        $subscriptionSplat = @{
            EventName = 'DataAdded'
            MessageData = $webSocketJob
            SupportEvent = $true
        }
        $eventSubscriptions = @(
            if ($OnOutput) {
                Register-ObjectEvent @subscriptionSplat -InputObject $webSocketJob.Output -Action $OnOutput
            }
            if ($OnError) {
                Register-ObjectEvent @subscriptionSplat -InputObject $webSocketJob.Error -Action $OnError
            }
            if ($OnWarning) {
                Register-ObjectEvent @subscriptionSplat -InputObject $webSocketJob.Warning -Action $OnWarning
            }
        )
        if ($eventSubscriptions) {
            $variable['EventSubscriptions'] = $eventSubscriptions
        }

        $webSocketConnectTimeout = [DateTime]::Now + $ConnectionTimeout
        while (-not $variable['WebSocket'] -and 
            ([DateTime]::Now -lt $webSocketConnectTimeout)) {
            Start-Sleep -Milliseconds 0
        }
        
        foreach ($keyValuePair in $Variable.GetEnumerator()) {
            $webSocketJob.psobject.properties.add(
                [psnoteproperty]::new($keyValuePair.Key, $keyValuePair.Value), $true
            )
        }
        $webSocketJob.pstypenames.insert(0, 'WebSocketJob')
        if ($Watch) {
            do {                
                $webSocketJob | Receive-Job
                Start-Sleep -Milliseconds (
                    7, 11, 13, 17, 19, 23 | Get-Random
                ) 
            } while ($webSocketJob.State -in 'Running','NotStarted')
        } else {
            $webSocketJob
        }        
    }
}
