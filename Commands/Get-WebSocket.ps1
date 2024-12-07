function Get-WebSocket {
    <#
    .SYNOPSIS
        WebSockets in PowerShell.
    .DESCRIPTION
        Get-WebSocket gets a websocket.

        This will create a job that connects to a WebSocket and outputs the results.

        If the `-Watch` parameter is provided, will output a continous stream of objects.
    .EXAMPLE
        # Create a WebSocket job that connects to a WebSocket and outputs the results.
        Get-WebSocket -WebSocketUri "wss://localhost:9669/" 
    .EXAMPLE
        # Get is the default verb, so we can just say WebSocket.
        # `-Watch` will output a continous stream of objects from the websocket.
        # For example, let's Watch BlueSky, but just the text.        
        websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch |
            % { 
                $_.commit.record.text
            }            
    .EXAMPLE
        # Watch BlueSky, but just the text and spacing
        $blueSkySocketUrl = "wss://jetstream2.us-$(
            'east','west'|Get-Random
        ).bsky.network/subscribe?$(@(
            "wantedCollections=app.bsky.feed.post"
        ) -join '&')"
        websocket $blueSkySocketUrl -Watch | 
            % { Write-Host "$(' ' * (Get-Random -Max 10))$($_.commit.record.text)$($(' ' * (Get-Random -Max 10)))"}
    .EXAMPLE        
        websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post
    .EXAMPLE
        # Watch BlueSky, but just the emoji
        websocket jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail |
            Foreach-Object {
                $in = $_
                if ($in.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+') {
                    Write-Host $matches.0 -NoNewline
                }
            }
    .EXAMPLE
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
    .EXAMPLE
        websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch |
            Where-Object {
                $_.commit.record.embed.'$type' -eq 'app.bsky.embed.external'
            } |
            Foreach-Object {
                $_.commit.record.embed.external.uri
            }
    .EXAMPLE
        # BlueSky, but just the hashtags
        websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -WatchFor @{
            {$webSocketoutput.commit.record.text -match "\#\w+"}={
                $matches.0
            }                
        }
    .EXAMPLE
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
    .EXAMPLE
        websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -WatchFor @{
            {$args.commit.record.text -match "\#\w+"}={
                $matches.0
            }
            {$args.commit.record.text -match '[\p{IsHighSurrogates}\p{IsLowSurrogates}]+'}={
                $matches.0
            }
        }
    #>
    [CmdletBinding(PositionalBinding=$false)]
    [Alias('WebSocket')]
    param(
    # The Uri of the WebSocket to connect to.
    [Parameter(Position=0,ValueFromPipelineByPropertyName)]
    [Alias('Url','Uri')]
    [uri]$WebSocketUri,

    # A ScriptBlock that will handle the output of the WebSocket.
    [ScriptBlock]
    $Handler,

    # Any variables to declare in the WebSocket job.
    # These variables will also be added to the job as properties.
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

    # If set, will output the raw text that comes out of the WebSocket.
    [Alias('Raw')]
    [switch]
    $RawText,

    # If set, will output the raw bytes that come out of the WebSocket.
    [Alias('RawByte','RawBytes','Bytes','Byte')]
    [switch]
    $Binary,

    # If set, will watch the output of a WebSocket job for one or more conditions.
    # The conditions are the keys of the dictionary, and can be a regex, a string, or a scriptblock.
    # The values of the dictionary are what will happen when a match is found.
    [ValidateScript({
        $keys = $_.Keys
        $values = $_.values
        foreach ($key in $keys) {
            if ($key -isnot [scriptblock]) {
                throw "Keys '$key' must be a scriptblock"
            }            
        }
        foreach ($value in $values) {
            if ($value -isnot [scriptblock] -and $value -isnot [string]) {
                throw "Value '$value' must be a string or scriptblock"
            }
        }
        return $true
    })]
    [Alias('WhereFor','Wherefore')]
    [Collections.IDictionary]
    $WatchFor,

    # The timeout for the WebSocket connection.  If this is provided, after the timeout elapsed, the WebSocket will be closed.
    [TimeSpan]
    $TimeOut,

    # If provided, will decorate the objects outputted from a websocket job.
    # This will only decorate objects converted from JSON.
    [Alias('PSTypeNames','Decorate','Decoration')]
    [string[]]
    $PSTypeName,

    # The maximum number of messages to receive before closing the WebSocket.
    [long]
    $Maximum,

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

            $MessageCount = [long]0
                                                
            while ($true) {
                if ($ws.State -ne 'Open') {break }
                if ($TimeOut -and ([DateTime]::Now - $webSocketStartTime) -gt $TimeOut) {
                    $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Timeout', $CT).Wait()
                    break
                }

                if ($Maximum -and $MessageCount -ge $Maximum) {
                    $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Maximum messages reached', $CT).Wait()
                    break
                }
                
                $Buf = [byte[]]::new($BufferSize)
                $Seg = [ArraySegment[byte]]::new($Buf)
                $null = $ws.ReceiveAsync($Seg, $CT).Wait()
                $MessageCount++
                
                try {
                    $webSocketMessage =
                        if ($Binary) {
                            $Buf -gt 0
                        } elseif ($RawText) {
                            $OutputEncoding.GetString($Buf, 0, $Buf.Count)
                        } else {
                            $JS = $OutputEncoding.GetString($Buf, 0, $Buf.Count)
                            if ([string]::IsNullOrWhitespace($JS)) { continue }
                            ConvertFrom-Json $JS
                        }
                    if ($PSTypeName) {
                        $webSocketMessage.pstypenames.clear()
                        [Array]::Reverse($PSTypeName)
                        foreach ($psType in $psTypeName) {
                            $webSocketMessage.pstypenames.add($psType)
                        }
                    }
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
        } 
        elseif ($WatchFor) {
            . {
                do {                
                    $webSocketJob | Receive-Job
                    Start-Sleep -Milliseconds (
                        7, 11, 13, 17, 19, 23 | Get-Random
                    ) 
                } while ($webSocketJob.State -in 'Running','NotStarted')
            } | . {                
                process {
                    $webSocketOutput = $_
                    foreach ($key in @($WatchFor.Keys)) {
                        $result = 
                            if ($key -is [ScriptBlock]) {
                                . $key $webSocketOutput
                            }

                        if (-not $result) { continue }
                        if ($WatchFor[$key] -is [ScriptBlock]) {
                            $webSocketOutput | . $WatchFor[$key]
                        } else {
                            $WatchFor[$key]
                        }                        
                    }
                }
            }
        }
        else {
            $webSocketJob
        }        
    }
}
