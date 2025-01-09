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
        websocket wss://jetstream2.us-west.bsky.network/subscribe -QueryParameter @{ wantedCollections = 'app.bsky.feed.post' } -Max 1 -Debug
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
    .EXAMPLE
        # We can decorate a type returned from a WebSocket, allowing us to add additional properties.

        # For example, let's add a `Tags` property to the `app.bsky.feed.post` type.
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
    #>
    [CmdletBinding(PositionalBinding=$false,SupportsPaging)]
    [Alias('WebSocket','ws','wss')]
    param(
    # The WebSocket Uri.
    [Parameter(Position=0,ValueFromPipelineByPropertyName)]
    [Alias('Url','Uri')]
    [uri]$WebSocketUri,

    # One or more root urls.
    # If these are provided, a WebSocket server will be created with these listener prefixes.
    [Parameter(Position=1,ValueFromPipelineByPropertyName)]
    [Alias('HostHeader','Host','ServerURL','ListenerPrefix','ListenerPrefixes','ListenerUrl')]
    [string[]]
    $RootUrl,

    # A collection of query parameters.
    # These will be appended onto the `-WebSocketUri`.
    [Collections.IDictionary]
    $QueryParameter,

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
    $BufferSize = 64kb,

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

    # The subprotocol used by the websocket.  If not provided, this will default to `json`.
    [string]
    $SubProtocol,
    
    # One or more filters to apply to the output of the WebSocket.
    # These can be strings, regexes, scriptblocks, or commands.
    # If they are strings or regexes, they will be applied to the raw text.
    # If they are scriptblocks, they will be applied to the deserialized JSON.
    # These filters will be run within the WebSocket job.
    [PSObject[]]
    $Filter,

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
        $SocketClientJob = {
            param(
                # By accepting a single parameter containing variables, 
                # we can avoid the need to pass in a large number of parameters.
                # we can also modify this dictionary, to provide a way to pass information back.
                [Collections.IDictionary]$Variable
            )
            
            # Take every every `-Variable` passed in and define it within the job
            foreach ($keyValue in $variable.GetEnumerator()) {
                $ExecutionContext.SessionState.PSVariable.Set($keyValue.Key, $keyValue.Value)
            }

            $Variable.JobRunspace = [Runspace]::DefaultRunspace

            if ((-not $WebSocketUri)) {
                throw "No WebSocketUri"
            }

            if (-not $WebSocketUri.Scheme) {
                $WebSocketUri = [uri]"wss://$WebSocketUri"
            }
            
            if ($QueryParameter) {
                $WebSocketUri = [uri]"$($webSocketUri)$($WebSocketUri.Query ? '&' : '?')$(@(
                    foreach ($keyValuePair in $QueryParameter.GetEnumerator()) {
                        if ($keyValuePair.Value -is [Collections.IList]) {
                            foreach ($value in $keyValuePair.Value) {
                                "$($keyValuePair.Key)=$([Web.HttpUtility]::UrlEncode($value).Replace('+', '%20'))"
                            }
                        } else {
                            "$($keyValuePair.Key)=$([Web.HttpUtility]::UrlEncode($keyValuePair.Value).Replace('+', '%20'))"
                        }
                }) -join '&')"
            }

            if (-not $BufferSize) {
                $BufferSize = 64kb
            }

            $CT = [Threading.CancellationToken]::None
            
            if ($webSocket -isnot [Net.WebSockets.ClientWebSocket]) {
                $ws = [Net.WebSockets.ClientWebSocket]::new()
                if ($SubProtocol) {
                    $ws.Options.AddSubProtocol($SubProtocol)
                } else {
                    $ws.Options.AddSubProtocol('json')
                }
                $null = $ws.ConnectAsync($WebSocketUri, $CT).Wait()
            } else {
                $ws = $WebSocket
            }            

            $webSocketStartTime = $Variable.WebSocketStartTime = [DateTime]::Now
            $Variable.WebSocket = $ws

            $MessageCount = [long]0
            $FilteredCount = [long]0
            $SkipCount = [long]0            

            :WebSocketMessageLoop while ($true) {
                if ($ws.State -ne 'Open') {break }
                if ($TimeOut -and ([DateTime]::Now - $webSocketStartTime) -gt $TimeOut) {
                    $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Timeout', $CT).Wait()
                    break
                }

                if ($Maximum -and (
                    ($MessageCount - $FilteredCount) -ge $Maximum
                )) {
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
                        } else {
                            $messageString = $OutputEncoding.GetString($Buf, 0, $Buf.Count)
                            if ($Filter) {
                                foreach ($fil in $filter) {
                                    if ($fil -is [string] -and $messageString -like "*$fil*") {
                                        $FilteredCount++
                                        continue WebSocketMessageLoop
                                    }
                                    if ($fil -is [regex] -and $fil.IsMatch($messageString)) {
                                        $FilteredCount++
                                        continue WebSocketMessageLoop
                                    }
                                }
                            }
                            if ($RawText) {
                                $messageString
                            } else {
                                $MessageObject = ConvertFrom-Json -InputObject $messageString
                                if ($filter) {
                                    foreach ($fil in $Filter) {
                                        if ($fil -is [ScriptBlock] -or 
                                            $fil -is [Management.Automation.CommandInfo]
                                        ) {
                                            if (& $fil $MessageObject) {
                                                $FilteredCount++
                                                continue WebSocketMessageLoop
                                            }
                                        }
                                    }
                                }
                                if ($Skip -and ($SkipCount -le $Skip)) {
                                    $SkipCount++
                                    continue WebSocketMessageLoop
                                }
                                
                                
                                $MessageObject
                                if ($First -and ($MessageCount - $FilteredCount - $SkipCount) -ge $First) {
                                    $Maximum = $first
                                }
                            }
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
        # First, let's pack all of the parameters into a dictionary of variables.
        foreach ($keyValuePair in $PSBoundParameters.GetEnumerator()) {
            $Variable[$keyValuePair.Key] = $keyValuePair.Value
        }
        # If `-Debug` was passed,
        if ($DebugPreference -notin 'SilentlyContinue','Ignore') {
            # run the job in the current scope (so we can debug it).
            . $SocketClientJob -Variable $Variable
            return
        }
        $webSocketJob =
            if ($WebSocketUri) {
                if (-not $name) {
                    $Name = $WebSocketUri
                }

                $existingJob = foreach ($jobWithThisName in (Get-Job -Name $Name -ErrorAction Ignore)) {
                    if (
                        $jobWithThisName.State -in 'Running','NotStarted' -and
                        $jobWithThisName.WebSocket -is [Net.WebSockets.ClientWebSocket]
                    ) {
                        $jobWithThisName
                        break
                    }
                }

                if ($existingJob) {
                    $existingJob
                } else {
                    Start-ThreadJob -ScriptBlock $SocketClientJob -Name $Name -InitializationScript $InitializationScript -ArgumentList $Variable
                }                                            
            }

        $subscriptionSplat = @{
            EventName = 'DataAdded'
            MessageData = $webSocketJob
            SupportEvent = $true
        }
        $eventSubscriptions = @(
            if ($webSocketJob) {
                if ($OnOutput) {
                    Register-ObjectEvent @subscriptionSplat -InputObject $webSocketJob.Output -Action $OnOutput
                }
                if ($OnError) {
                    Register-ObjectEvent @subscriptionSplat -InputObject $webSocketJob.Error -Action $OnError
                }
                if ($OnWarning) {
                    Register-ObjectEvent @subscriptionSplat -InputObject $webSocketJob.Warning -Action $OnWarning
                }
            }            
        )
        if ($eventSubscriptions) {
            $variable['EventSubscriptions'] = $eventSubscriptions
        }

        if ($webSocketJob) {
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
            $webSocketJob.pstypenames.insert(0, 'WebSocket.ThreadJob')
        }        
        
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
