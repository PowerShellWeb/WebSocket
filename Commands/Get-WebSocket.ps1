function Get-WebSocket {
    <#
    .SYNOPSIS
        WebSockets in PowerShell.
    .DESCRIPTION
        Get-WebSocket gets a websocket.

        This will create a job that connects to a WebSocket and outputs the results.

        If the `-Watch` parameter is provided, will output a continous stream of objects.
    .LINK
        https://websocket.powershellweb.com/Get-WebSocket/
    .LINK
        https://learn.microsoft.com/en-us/dotnet/api/system.net.websockets.clientwebsocket?wt.mc_id=MVP_321542
    .LINK
        https://learn.microsoft.com/en-us/dotnet/api/system.net.httplistener?wt.mc_id=MVP_321542
    .EXAMPLE
        # Create a WebSocket job that connects to a WebSocket and outputs the results.
        $socketServer = Get-WebSocket -RootUrl "http://localhost:8387/" -HTML "<h1>WebSocket Server</h1>"
        $socketClient = Get-WebSocket -SocketUrl "ws://localhost:8387/"
    .EXAMPLE
        # Get is the default verb, so we can just say WebSocket.
        # `-Watch` will output a continous stream of objects from the websocket.
        # For example, let's Watch BlueSky, but just the text 
        websocket wss://jetstream2.us-west.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Watch -Maximum 1kb |
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
            % { Write-Host "$(' ' * (Get-Random -Max 10))$($_.commit.record.text)$($(' ' * (Get-Random -Max 10)))"} -Max 1kb
    .EXAMPLE
        # Watch continuously in a background job.
        websocket wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post
    .EXAMPLE
        # Watch the first message in -Debug mode.  
        # This allows you to literally debug the WebSocket messages as they are encountered.
        websocket wss://jetstream2.us-west.bsky.network/subscribe -QueryParameter @{
            wantedCollections = 'app.bsky.feed.post'
        } -Max 1 -Debug
    .EXAMPLE
        # Watch BlueSky, but just the emoji
        websocket jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post -Tail -Max 1kb |
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
        websocket wss://jetstream2.us-west.bsky.network/subscribe -QueryParameter @{
            wantedCollections = 'app.bsky.feed.post'
        } -WatchFor @{
            {$webSocketoutput.commit.record.text -match "\#\w+"}={
                $matches.0
            }                
        } -Maximum 1kb
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
    [CmdletBinding(
        PositionalBinding=$false,
        SupportsPaging,
        DefaultParameterSetName='WebSocketClient'
    )]
    [Alias('WebSocket','ws','wss')]
    param(
    # The WebSocket Uri.
    [Parameter(Position=0,ParameterSetName='WebSocketClient',ValueFromPipelineByPropertyName)]
    [Alias('Url','Uri','WebSocketUri','WebSocketUrl')]
    [uri]
    $SocketUrl,

    # One or more root urls.
    # If these are provided, a WebSocket server will be created with these listener prefixes.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='WebSocketServer')]
    [Alias('HostHeader','Host','CNAME','ListenerPrefix','ListenerPrefixes','ListenerUrl')]
    [string[]]
    $RootUrl,

    # A route table for all requests.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketServer')]
    [Alias('Routes','RouteTable','WebHook','WebHooks')]
    [Collections.IDictionary]
    $Route,

    # The Default HTML.
    # This will be displayed when visiting the root url.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketServer')]
    [Alias('DefaultHTML','Home','Index','IndexHTML','DefaultPage')]
    [string]
    $HTML,

    # The name of the palette to use.  This will include the [4bitcss](https://4bitcss.com) stylesheet.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketServer')]
    [Alias('Palette','ColorScheme','ColorPalette')]
    [ArgumentCompleter({
        param ($commandName,$parameterName,$wordToComplete,$commandAst,$fakeBoundParameters )
        if (-not $script:4bitcssPaletteList) {
            $script:4bitcssPaletteList = Invoke-RestMethod -Uri https://cdn.jsdelivr.net/gh/2bitdesigns/4bitcss@latest/docs/Palette-List.json
        }
        if ($wordToComplete) {
            $script:4bitcssPaletteList -match "$([Regex]::Escape($wordToComplete) -replace '\\\*', '.{0,}')"
        } else {
            $script:4bitcssPaletteList 
        }        
    })]
    [string]
    $PaletteName,

    # The [Google Font](https://fonts.google.com/) name.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketServer')]
    [Alias('FontName')]
    [string]
    $GoogleFont,

    # The Google Font name to use for code blocks.
    # (this should be a [monospace font](https://fonts.google.com/?classification=Monospace))
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketServer')]
    [Alias('PreFont','CodeFontName','PreFontName')]
    [string]
    $CodeFont,

    # A list of javascript files or urls to include in the content.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketServer')]
    [string[]]
    $JavaScript,

    # A javascript import map.  This allows you to import javascript modules.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketServer')]
    [Alias('ImportsJavaScript','JavaScriptImports','JavaScriptImportMap')]
    [Collections.IDictionary]
    $ImportMap,

    # A collection of query parameters.
    # These will be appended onto the `-SocketUrl`.
    # Multiple values for a single parameter will be passed as multiple parameters.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketClient')]
    [Alias('QueryParameters','Query')]
    [Collections.IDictionary]
    $QueryParameter,

    # A ScriptBlock that can handle the output of the WebSocket or the Http Request.
    # This may be run in a separate `-Runspace` or `-RunspacePool`.
    # The output of the WebSocket or the Context will be passed as an object.
    [ScriptBlock]
    $Handler,

    # If set, will forward websocket messages as events.
    # Only events that match -Filter will be forwarded.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketClient')]
    [Alias('Forward')]
    [switch]
    $ForwardEvent,

    # Any variables to declare in the WebSocket job.
    # These variables will also be added to the job as properties.
    [Collections.IDictionary]    
    $Variable = @{},

    # Any Http Headers to include in the WebSocket request or server response.
    [Collections.IDictionary]
    [Alias('Headers')]
    $Header,

    # The name of the WebSocket job.    
    [string]
    $Name,

    # The script to run when the WebSocket job starts.
    [ScriptBlock]
    $InitializationScript = {},

    # The buffer size.  Defaults to 16kb.
    [Parameter(ValueFromPipelineByPropertyName)]
    [int]
    $BufferSize = 64kb,

    # If provided, will send an object.
    # If this is a scriptblock, it will be run and the output will be sent.
    [Alias('Send')]
    [PSObject]
    $Broadcast,

    # The ScriptBlock to run after connection to a websocket.
    # This can be useful for making any initial requests.
    [Parameter(ParameterSetName='WebSocketClient')]
    [ScriptBlock]
    $OnConnect,

    # The ScriptBlock to run when an error occurs.
    [Parameter(ParameterSetName='WebSocketClient')]
    [ScriptBlock]
    $OnError,

    # The ScriptBlock to run when the WebSocket job outputs an object.
    [Parameter(ParameterSetName='WebSocketClient')]
    [ScriptBlock]
    $OnOutput,

    # The Scriptblock to run when the WebSocket job produces a warning.
    [Parameter(ParameterSetName='WebSocketClient')]
    [ScriptBlock]
    $OnWarning,

    # If provided, will authenticate the WebSocket.
    # Many websockets require an initial authentication handshake
    # after an initial message is received.    
    # This parameter can be either a ScriptBlock or any other object.
    # If it is a ScriptBlock, it will be run with the output of the WebSocket passed as the first argument.
    # This will run after the socket is connected but before any messages are received.
    [Parameter(ParameterSetName='WebSocketClient')]
    [Alias('Authorize','HelloMessage')]
    [PSObject]
    $Authenticate,

    # If provided, will shake hands after the first websocket message is received.
    # This parameter can be either a ScriptBlock or any other object.
    # If it is a ScriptBlock, it will be run with the output of the WebSocket passed as the first argument.
    # This will run after the socket is connected and the first message is received.
    [Parameter(ParameterSetName='WebSocketClient')]        
    [Alias('Identify')]
    [PSObject]
    $Handshake,

    # If set, will watch the output of the WebSocket job, outputting results continuously instead of outputting a websocket job.    
    [Parameter(ParameterSetName='WebSocketClient')]
    [Alias('Tail')]
    [switch]
    $Watch,

    # If set, will output the raw text that comes out of the WebSocket.
    [Parameter(ParameterSetName='WebSocketClient')]
    [Alias('Raw')]
    [switch]
    $RawText,

    # If set, will output the raw bytes that come out of the WebSocket.
    [Parameter(ParameterSetName='WebSocketClient')]
    [Alias('RawByte','RawBytes','Bytes','Byte')]
    [switch]
    $Binary,    

    # If set, will force a new job to be created, rather than reusing an existing job.
    [switch]
    $Force,

    # The subprotocol used by the websocket.  If not provided, this will default to `json`.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketClient')]
    [string]
    $SubProtocol,

    # If set, will not set a subprotocol.  This will only work with certain websocket servers, but will not work with an HTTP Listener WebSocket.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketClient')]
    [switch]
    $NoSubProtocol,
    
    # One or more filters to apply to the output of the WebSocket.
    # These can be strings, regexes, scriptblocks, or commands.
    # If they are strings or regexes, they will be applied to the raw text.
    # If they are scriptblocks, they will be applied to the deserialized JSON.
    # These filters will be run within the WebSocket job.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketClient')]
    [PSObject[]]
    $Filter,

    # If set, will watch the output of a WebSocket job for one or more conditions.
    # The conditions are the keys of the dictionary, and can be a regex, a string, or a scriptblock.
    # The values of the dictionary are what will happen when a match is found.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketClient')]
    [ValidateScript({
        $keys = $_.Keys
        $values = $_.values
        foreach ($key in $keys) {
            if ($key -isnot [scriptblock]) {
                throw "Key '$key' must be a scriptblock"
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

    # The timeout for the WebSocket connection.
    # If this is provided, after the timeout elapsed, the WebSocket will be closed.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Lifespan')]
    [TimeSpan]
    $TimeOut,

    # If provided, will decorate the objects outputted from a websocket job.
    # This will only decorate objects converted from JSON.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketClient')]
    [Alias('PSTypeNames','Decorate','Decoration')]
    [string[]]
    $PSTypeName,

    # The maximum number of messages to receive before closing the WebSocket.
    [Parameter(ValueFromPipelineByPropertyName)]
    [long]
    $Maximum,

    # The throttle limit used when creating background jobs.
    [Parameter(ValueFromPipelineByPropertyName)]
    [int]
    $ThrottleLimit = 64,

    # The maximum time to wait for a connection to be established.
    # By default, this is 7 seconds.    
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='WebSocketClient')]
    [TimeSpan]
    $ConnectionTimeout = '00:00:07',

    # The Runspace where the handler should run.
    # Runspaces allow you to limit the scope of the handler.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Runspace]
    $Runspace,

    # The RunspacePool where the handler should run.
    # RunspacePools allow you to limit the scope of the handler to a pool of runspaces.
    [Parameter(ValueFromPipelineByPropertyName)]
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
            
            $Variable.JobRunspace = [Runspace]::DefaultRunspace

            # Take every every `-Variable` passed in and define it within the job
            foreach ($keyValue in $variable.GetEnumerator()) {
                $ExecutionContext.SessionState.PSVariable.Set($keyValue.Key, $keyValue.Value)
            }            

            # If we have no socket url,
            if ((-not $SocketUrl)) {
                # throw up an error.
                throw "No SocketUrl"
            }

            # If the socket url does not have a scheme
            if (-not $SocketUrl.Scheme) {
                # assume `wss`
                $SocketUrl = [uri]"wss://$SocketUrl"
            } elseif (
                # otherwise, if the scheme is http or https
                $SocketUrl.Scheme -match '^https?'
            ) {
                # replace it with `ws` or `wss`
                $SocketUrl = $SocketUrl -replace '^http', 'ws'
            }
            
            # If any query parameters were provided
            if ($QueryParameter) {
                # add them to the socket url
                $SocketUrl = [uri]"$($SocketUrl)$($SocketUrl.Query ? '&' : '?')$(@(
                    foreach ($keyValuePair in $QueryParameter.GetEnumerator()) {
                        # cannocially, each key value pair should be url encoded, 
                        # and multiple values should be passed multiple times.
                        foreach ($value in $keyValuePair.Value) {
                            $valueString =
                                # If the value is a boolean or a switch,
                                if ($value -is [bool] -or $value -is [switch]) {
                                    # convert it to a string and make it lowercase.
                                    ($value -as [bool] -as [string]).ToLower()
                                } else {
                                    # Otherwise, just stringify.
                                    "$value"
                                }
                            "$($keyValuePair.Key)=$([Web.HttpUtility]::UrlEncode($valueString).Replace('+', '%20'))"
                        }                    
                }) -join '&')"
            }

            # If we had not set a -BufferSize, 
            if (-not $BufferSize) {
                $BufferSize = 64kb # default to 64kb.
            }

            # Create a cancellation token, as this will save syntax space
            $CT = [Threading.CancellationToken]::None
            
            # If `$WebSocket `is not already a websocket
            if ($webSocket -isnot [Net.WebSockets.ClientWebSocket]) {
                # create a new socket
                $ws = [Net.WebSockets.ClientWebSocket]::new()
                if ($SubProtocol) {
                    # and add the subprotocol
                    $ws.Options.AddSubProtocol($SubProtocol)
                } elseif (-not $NoSubProtocol) {
                    $ws.Options.AddSubProtocol('json')
                }
                # If there are headers
                if ($Header) {
                    # add them to the initial socket request.
                    foreach ($headerKeyValue in $header.GetEnumerator()) {
                        $ws.Options.SetRequestHeader($headerKeyValue.Key, $headerKeyValue.Value)
                    }                    
                }
                # Now, let's try to connect to the WebSocket.
                $null = $ws.ConnectAsync($SocketUrl, $CT).Wait()
            } else {
                $ws = $WebSocket
            }            

            # Keep track of the time
            $webSocketStartTime = $Variable.WebSocketStartTime = [DateTime]::Now
            # and add the WebSocket to the variable dictionary, so we can access it later.
            $Variable.WebSocket = $ws

            # Initialize some counters:            
            $MessageCount = [long]0  # * The number of messages received
            $FilteredCount = [long]0 # * The number of messages filtered out
            $SkipCount = [long]0     # * The number of messages skipped
            
            # Initialize variables related to handshaking
            $saidHello = $null # * Whether we have said hello
            $shookHands = $null # * Whether we have shaken hands

            # This loop will run as long as the websocket is open.
            :WebSocketMessageLoop while ($ws.State -eq 'Open') {
                # If we've given a timeout for the websocket,
                # and the websocket has been open for longer than the timeout, 
                if ($TimeOut -and ([DateTime]::Now - $webSocketStartTime) -gt $TimeOut) {
                    # then it's closing time (you don't have to go home but you can't stay here).
                    $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Timeout', $CT).Wait()
                    break
                }

                # If we've gotten the maximum number of messages,
                if ($Maximum -and (
                    ($MessageCount - $FilteredCount) -ge $Maximum
                )) {
                    # then I can't even take any more responses.
                    $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Maximum messages reached', $CT).Wait()
                    break
                }
                
                # If we're authenticating, and haven't yet said hello
                if ($Authenticate -and -not $SaidHello) {
                    # then we should say hello.
                    # Determine the authentication message
                    $authenticationMessage =
                        # If the authentication message is a scriptblock,
                        if ($Authenticate -is [ScriptBlock]) {
                            & $Authenticate # run it
                        } else {
                            $authenticate # otherwise, use it as-is.
                        }

                    # If we have an authentication message
                    if ($authenticationMessage) {
                        # and it's not a string
                        if ($authenticationMessage -isnot [string]) {
                            # then we should send it as JSON and mark that we've said hello.
                            $saidHello = $ws.SendAsync([ArraySegment[byte]]::new(
                                $OutputEncoding.GetBytes((ConvertTo-Json -InputObject $authenticationMessage -Depth 10))
                            ), 'Text', $true, $CT)
                        }
                    }
                }
                
                # Ok, let's get the next message.
                $Buf = [byte[]]::new($BufferSize)
                $Seg = [ArraySegment[byte]]::new($Buf)
                $receivingWebSocket = $ws.ReceiveAsync($Seg, $CT)
                # use this tight loop to let us cancel the await if we need to.
                while (-not ($receivingWebSocket.IsCompleted -or $receivingWebSocket.IsFaulted -or $receivingWebSocket.IsCanceled)) {

                }
                # If we had a problem, write an error.
                if ($receivingWebSocket.Exception) {
                    Write-Error -Exception $receivingWebSocket.Exception -Category ProtocolError
                    continue
                }
                $MessageCount++
                
                try {
                    # If we have a handshake and we haven't yet shaken hands
                    if ($Handshake -and -not $shookHands) {
                        # then we should shake hands.
                        # Get the message string
                        $messageString = $OutputEncoding.GetString($Buf, 0, $Buf.Count)
                        # and try to convert it from JSON.
                        $messageObject = ConvertFrom-Json -InputObject $messageString *>&1
                        # Determine the handshake message
                        $handShakeMessage =
                            # If the handshake message is a scriptblock,                          
                            if ($Handshake -is [ScriptBlock]) {
                                & $Handshake $MessageObject # run it and pass the message
                            } else {
                                $Handshake # otherwise, use it as-is.
                            }
    
                        # If we have a handshake message
                        if ($handShakeMessage) {
                            # and it's not a string
                            if ($handShakeMessage -isnot [string]) {
                                # then we should send it as JSON and mark that we've shaken hands.
                                $saidHello = $ws.SendAsync([ArraySegment[byte]]::new(
                                    $OutputEncoding.GetBytes((ConvertTo-Json -InputObject $handShakeMessage -Depth 10))
                                ), 'Text', $true, $CT)
                            }
                        }
                    }

                    # Get the message from the websocket
                    $webSocketMessage =
                        if ($Binary) { # If we wanted binary
                            $Buf -gt 0 -as [byte[]] # then return non-null bytes
                        } else {
                            # otherwise, get the message as a string
                            $messageString = $OutputEncoding.GetString($Buf, 0, $Buf.Count)
                            # if we have any filters
                            if ($Filter) {
                                # then we see if we can apply them now.
                                foreach ($fil in $filter) {
                                    # Wilcard filters can be applied to the raw text
                                    if ($fil -is [string] -and $messageString -like "*$fil*") {
                                        $FilteredCount++
                                        continue WebSocketMessageLoop
                                    }
                                    # and so can regex filters.
                                    if ($fil -is [regex] -and $fil.IsMatch($messageString)) {
                                        $FilteredCount++
                                        continue WebSocketMessageLoop
                                    }
                                }
                            }
                            # If we have asked for -RawText
                            if ($RawText) {
                                $messageString # then return the raw text
                            } else {
                                # Otherwise, try to convert the message from JSON.
                                $MessageObject = ConvertFrom-Json -InputObject $messageString
                                
                                # Now we can run any filters that are scriptblocks or commands.
                                if ($filter) {
                                    foreach ($fil in $Filter) {
                                        if ($fil -is [ScriptBlock] -or
                                            $fil -is [Management.Automation.CommandInfo]
                                        ) {
                                            # Capture the output of the filter
                                            $filterOutput = $MessageObject | & $fil $MessageObject
                                            # if the output was falsy,
                                            if (-not $filterOutput) {
                                                $FilteredCount++ # filter out the message.
                                                continue WebSocketMessageLoop
                                            }
                                        }
                                    }
                                }

                                # If -Skip was provided and we haven't skipped enough messages
                                if ($Skip -and ($SkipCount -le $Skip)) {
                                    # then skip this message.
                                    $SkipCount++
                                    continue WebSocketMessageLoop
                                }
                                
                                # Now, emit the message object.
                                # (expressions that are not assigned will be outputted)
                                $MessageObject                       

                                # If we have a -First parameter, and we have not yet reached the maximum
                                # (after accounting for skips and filters)
                                if ($First -and ($MessageCount - $FilteredCount - $SkipCount) -ge $First) {
                                    # then set the maximum to first (which will cancel this after the next loop)
                                    $Maximum = $first
                                }
                            }
                        }
                    
                    # If we want to decorate the output
                    if ($PSTypeName) {
                        # clear it's typenames
                        $webSocketMessage.pstypenames.clear()
                        for ($typeNameIndex = $PSTypeName.Length - 1; $typeNameIndex -ge 0; $typeNameIndex--) {
                            # and add each type name in reverse order
                            $webSocketMessage.pstypenames.add($PSTypeName[$typeNameIndex])
                        }                  
                    }

                    # If we are forwarding events
                    if ($ForwardEvent -and $MainRunspace.Events.GenerateEvent) {
                        # generate an event in the main runspace
                        $null = $MainRunspace.Events.GenerateEvent(
                            "$SocketUrl",
                            $ws,
                            @($webSocketMessage),
                            $webSocketMessage
                        )
                    }

                    # If we have an output handler, try to run it and get the output
                    $handledResponse = if ($handler) {
                        # We may need to run the handler in a `[PowerShell]` command.
                        $psCmd =
                            # This is true if we want `NoLanguage` mode.
                            if ($runspace.LanguageMode -eq 'NoLanguage' -or 
                                $runspacePool.InitialSessionState.LanguageMode -eq 'NoLanguage') {
                                # (in which case we'll call .GetPowerShell())
                                $handler.GetPowerShell()
                            } elseif (
                                # or if we have a runspace or runspace pool
                                $Runspace -or $RunspacePool
                            ) {
                                # (in which case we'll `.Create()` and `.AddScript()`) 
                                [PowerShell]::Create().AddScript($handler, $true)
                            }
                        if ($psCmd) {
                            # If we have a runspace, we'll use that.
                            if ($Runspace) {
                                $psCmd.Runspace = $Runspace
                            } elseif ($RunspacePool) {
                                # or, alternatively, we can use a runspace pool.
                                $psCmd.RunspacePool = $RunspacePool
                            }
                            # Now, we can invoke the command.
                            $psCmd.Invoke(@($webSocketMessage))
                        } else {
                            # Otherwise, we'll just run the handler.
                            $webSocketMessage | . $handler
                        }
                    }

                    # If we have a response from the handler,
                    if ($handledResponse) {
                        $handledResponse # emit that response.
                    } else {
                        $webSocketMessage # otherwise, emit the message.
                    }                    
                } catch { 
                    Write-Error $_
                }
            }

            # Now that the socket is closed,
            # check for a status description.
            # If there is one,
            if ($ws.CloseStatusDescription) {
                # write an error.
                Write-Error $ws.CloseStatusDescription -TargetObject $ws
            }
        }
        $SocketServerJob = {
            <#
            .SYNOPSIS
                A fairly simple WebSocket server
            .DESCRIPTION
                A fairly simple WebSocket server
            #>
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

            $Variable['JobRunspace'] = [Runspace]::DefaultRunspace

            # If we have routes, we will cache all of their possible parameters now
            if ($route.Count) {
                # We want to keep the parameter sets
                $routeParameterSets = [Ordered]@{}
                # and the metadata about parameters. 
                $routeParameters = [Ordered]@{}
                
                # For each key and value in the route table, we will try to get the command info for the value.
                foreach ($routePair in $route.GetEnumerator()) {
                    $routeToCmd =
                        # If the value is a scriptblock
                        if ($routePair.Value -is [ScriptBlock]) {
                            # we have to create a temporary function
                            $function:TempFunction = $routePair.Value
                            # and get that function.
                            $ExecutionContext.SessionState.InvokeCommand.GetCommand('TempFunction', 'Function')
                        } elseif ($routePair.Value -is [Management.Automation.CommandInfo]) {
                            $routePair.Value
                        }
                    if ($routeToCmd) {
                        $routeParameterSets[$routePair.Name] = $routeToCmd.ParametersSets
                        $routeParameters[$routePair.Name] = $routeToCmd.Parameters
                    }
                }
            }
            
            # If there's no listener, create one.
            if (-not $httpListener) {
                $httpListener = $variable['HttpListener'] = [Net.HttpListener]::new()
            }

            # If the listener doesn't have a lookup table for SocketRequests, create one.
            if (-not $httpListener.SocketRequests) {
                $httpListener.psobject.properties.add(
                    [psnoteproperty]::new('SocketRequests', [Ordered]@{}), $true)
            }
            
            # If the listener isn't listening, start it.
            if (-not $httpListener.IsListening) { $httpListener.Start() }

            $variable['SiteHeader'] = $siteHeader =  @(
            
                if ($Javascript) {
                    # as well as any javascript files provided.
                    foreach ($js in $Javascript) {
                        if ($js -match '.js$') {
                            "<script src='$javascript'></script>"
                        } else {
                            "<script type='text/javascript'>$js</script>"
                        }
                    }
                }
                    
                # If an import map was provided, we will include it.
                if ($ImportMap) {                
                    $variable['ImportMap'] = @(
                        "<script type='importmap'>"
                        [Ordered]@{
                            imports = $ImportMap
                        } | ConvertTo-Json -Depth 3
                        "</script>"
                    ) -join [Environment]::NewLine
                }

                # If a palette name was provided, we will include the 4bitcss stylesheet.
                if ($PaletteName) {
                    if ($PaletteName -match '/.+?\.css$') {
                        "<link type='text/css' rel='stylesheet' href='$PaletteName' id='4bitcss' />"

                    } else {
                        '<link type="text/css" rel="stylesheet" href="https://cdn.jsdelivr.net/gh/2bitdesigns/4bitcss@latest/css/.css" id="4bitcss" />' -replace '\.css', "$PaletteName.css"
                    }            
                }
                
                # If a font name was provided, we will include the font stylesheet.
                if ($GoogleFont) {
                    "<link type='text/css' rel='stylesheet' href='https://fonts.googleapis.com/css?family=$GoogleFont' id='fontname' />"
                    "<style type='text/css'>body { font-family: '$GoogleFont'; }</style>"
                }

                # If a code font was provided, we will include the code font stylesheet.
                if ($CodeFont) {
                    "<link type='text/css' rel='stylesheet' href='https://fonts.googleapis.com/css?family=$CodeFont' id='codefont' />"
                    "<style type='text/css'>pre, code { font-family: '$CodeFont'; }</style>"
                }
                                
                # and if any stylesheets were provided, we will include them.            
                foreach ($css in $variable.StyleSheet) {
                    if ($css -match '.css$') {
                        "<link rel='stylesheet' href='$css' />"
                    } else {
                        "<style type='text/css'>$css</style>"
                    }
                }                            
            )            

            $httpListener.psobject.properties.add([psnoteproperty]::new('JobVariable',$Variable), $true)
            $listenerStartTime = [DateTime]::Now
        
            # While the listener is listening,
            while ($httpListener.IsListening) {
                # If we've given a timeout for the listener,
                # and the listener has been open for longer than the timeout, 
                if ($Timeout -and ([DateTime]::Now - $listenerStartTime) -gt $TimeOut) {
                    # then it's closing time (you don't have to go home but you can't stay here).
                    $httpListener.Stop()
                    break
                }
                # get the context asynchronously.
                $contextAsync = $httpListener.GetContextAsync()
                # and wait for it to complete.
                while (-not ($contextAsync.IsCompleted -or $contextAsync.IsFaulted -or $contextAsync.IsCanceled)) {
                    # while this is going on, other events can be processed, and CTRL-C can exit.
                    # also, we can go ahead and check for any socket requests, and get ready for the next one if we find one.
                    foreach ($socketRequest in @($httpListener.SocketRequests.GetEnumerator())) {
                        if ($socketRequest.Value.Receiving.IsCompleted) {
                            $socketRequest.Value.MessageCount++
                            $jsonMessage = ConvertFrom-Json -InputObject ($OutputEncoding.GetString($socketRequest.Value.ClientBuffer -gt 0))
                            $socketRequest.Value.ClientBuffer.Clear()
                            if ($MainRunspace.Events.GenerateEvent) {
                                $MainRunspace.Events.GenerateEvent.Invoke(@(
                                    "$($request.Url.Scheme -replace '^http', 'ws')://",
                                    $httpListener,
                                    @($socketRequest.Value.Context, $socketRequest.Value.WebSocketContet, $socketRequest.Key, $socketRequest.Value),
                                    $jsonMessage
                                ))
                            }
                            $socketRequest.Value.Receiving = 
                                $socketRequest.Value.WebSocket.ReceiveAsync($socketRequest.Value.ClientBuffer, [Threading.CancellationToken]::None)
                        }
                    }
                }
                # If async method fails,
                if ($contextAsync.IsFaulted) {
                    # write an error and continue.
                    Write-Error -Exception $contextAsync.Exception -Category ProtocolError
                    continue
                }
                # Get the context async result.
                # The context is basically the next request and response in the queue.
                $context = $(try { $contextAsync.Result } catch { $_ })

                # yield the context immediately, in case anything is watching the output of this job
                $context

                $Request, $response = $context.Request, $context.Response
                $RequestedUrl = $Request.Url
                # Favicons are literally outdated, but they're still requested.
                if ($RequestedUrl -match '/favicon.ico$') {
                    # by returning a 404 for them, we can make the browser stop asking.
                    $context.Response.StatusCode = 404
                    $context.Response.Close()
                    continue
                }
                # Now, for the fun part.
                # We turn request into a PowerShell events.
                # The protocol is the scheme of the request url.
                $Protocol = $RequestedUrl.Scheme
                # Each event will have the source identifier of the protocol, followed by ://                
                $eventIdentifier = "$($Protocol)://"
                # and by default it will pass a message containing the context.                                
                $messageData = [Ordered]@{Protocol = $protocol; Url = $context.Request.Url;Context = $context}

                if ($Header -and $response) {
                    foreach ($headerKeyValue in $Header.GetEnumerator()) {
                        try {
                            $response.Headers.Add($headerKeyValue.Key, $headerKeyValue.Value)
                        } catch {
                            Write-Warning "Cannot add header '$($headerKeyValue.Key)': $_"
                        }                        
                    }
                }

                # HttpListeners are quite nice, especially when it comes to websocket upgrades.
                # If the request is a websocket request
                if ($Request.IsWebSocketRequest) {
                    # we will change the event identifier to a websocket scheme.
                    $eventIdentifier = $eventIdentifier -replace '^http', 'ws'                    
                    # and call the `AcceptWebSocketAsync` method to upgrade the connection.
                    $acceptWebSocket = $context.AcceptWebSocketAsync('json')
                    # Once again, we'll use a tight loop to wait for the upgrade to complete or fail.
                    while (-not ($acceptWebSocket.IsCompleted -or $acceptWebSocket.IsFaulted -or $acceptWebSocket.IsCanceled)) { }
                    # and if it fails,
                    if ($acceptWebSocket.IsFaulted) {
                        # we will write an error and continue.
                        Write-Error -Exception $acceptWebSocket.Exception -Category ProtocolError
                        continue
                    }
                    # If it succeeds, capture the result.
                    $webSocketResult = try { $acceptWebSocket.Result } catch { $_ }

                    # If the websocket is open
                    if ($webSocketResult.WebSocket.State -eq 'open') {
                        # we have switched protocols!
                        $Protocol = $requestedUrl.Scheme -replace '^http', 'ws'

                        # Now add the result it to the SocketRequests lookup table, using the request trace identifier as the key.
                        $clientBuffer = $webSocketResult.WebSocket::CreateClientBuffer($BufferSize, $BufferSize)
                        $socketObject = [PSCustomObject][Ordered]@{
                            Context = $context
                            WebSocketContext = $webSocketResult
                            WebSocket = $webSocketResult.WebSocket
                            ClientBuffer = $clientBuffer
                            Created = [DateTime]::UtcNow 
                            LastMessageTime = $null
                            Receiving = $webSocketResult.WebSocket.ReceiveAsync($clientBuffer, [Threading.CancellationToken]::None)
                            MessageQueue = [Collections.Queue]::new()
                            MessageCount = [long]0
                        }
                        
                        if (-not $httpListener.SocketRequests["$($webSocketResult.RequestUri)"]) {
                            $httpListener.SocketRequests["$($webSocketResult.RequestUri)"] = [Collections.Queue]::new()
                        }
                        $httpListener.SocketRequests["$($webSocketResult.RequestUri)"].Enqueue($socketObject)                        
                        # and add the websocketcontext result to the message data.
                        $messageData["WebSocketContext"] = $webSocketResult
                        # also add the websocket result to the message data,
                        # since many might not exactly know what a "WebSocketContext" is.
                        $messageData["WebSocket"] = $webSocketResult.WebSocket
                    }
                }
                
                # Now, we generate the event.
                $generateEventArguments = @(
                    $eventIdentifier,
                    $httpListener,
                    @($context)
                    $messageData
                )
                # Get a pointer to the GenerateEvent method (we'll want this later)
                if ($MainRunspace.Events.GenerateEvent) {
                    $MainRunspace.Events.GenerateEvent.Invoke($generateEventArguments)
                }

                # Everything below this point is for HTTP requests.
                if ($protocol -notmatch '^http') {
                    continue # so if we're already a websocket, we will skip the rest of this code.
                }

                $routedTo = $null
                $routeKey = $null
                # If we have routes, we will try to find a route that matches the request.
                if ($route.Count) {
                    $routeTable = $route
                    $potentialRouteKeys = @(
                        $request.Url.AbsolutePath,
                        ($request.Url.AbsolutePath -replace '/$'),
                        "$($request.HttpMethod) $($request.Url.AbsolutePath)",
                        "$($request.HttpMethod) $($request.Url.AbsolutePath -replace '/$')"
                        "$($request.HttpMethod) $($request.Url.LocalPath)",
                        "$($request.HttpMethod) $($request.Url.LocalPath -replace '/$')"
                    )
                    $routedTo = foreach ($potentialKey in $potentialRouteKeys) {
                        if ($routeTable[$potentialKey]) {
                            $routeTable[$potentialKey]
                            $routeKey = $potentialKey
                            break
                        }
                    }
                }

                if (-not $routedTo -and $handler) {
                    # If we have an output handler, try to run it and get the output
                    $routedTo = if ($handler) {
                        # We may need to run the handler in a `[PowerShell]` command.
                        $psCmd =
                            # This is true if we want `NoLanguage` mode.
                            if ($runspace.LanguageMode -eq 'NoLanguage' -or 
                                $runspacePool.InitialSessionState.LanguageMode -eq 'NoLanguage') {
                                # (in which case we'll call .GetPowerShell())
                                $handler.GetPowerShell()
                            } elseif (
                                # or if we have a runspace or runspace pool
                                $Runspace -or $RunspacePool
                            ) {
                                # (in which case we'll `.Create()` and `.AddScript()`) 
                                [PowerShell]::Create().AddScript($handler, $true)
                            }
                        if ($psCmd) {
                            # If we have a runspace, we'll use that.
                            if ($Runspace) {
                                $psCmd.Runspace = $Runspace
                            } elseif ($RunspacePool) {
                                # or, alternatively, we can use a runspace pool.
                                $psCmd.RunspacePool = $RunspacePool
                            }
                            # Now, we can invoke the command.
                            $psCmd.Invoke(@($context))
                        } else {
                            # Otherwise, we'll just run the handler.
                            $context | . $handler
                        }
                    }
                }

                if (-not $routedTo -and $html) {
                    $routedTo = 
                        # If the content is already html, we will use it as is.
                        if ($html -match '\<html') {
                            $html
                        } else {
                            # Otherwise, we will wrap it in an html tag.
                            @(
                                "<html>"
                                "<head>"
                                # and apply the site header.
                                $SiteHeader -join [Environment]::NewLine
                                "</head>"
                                "<body>"
                                $html
                                "</body>"
                                "</html>"
                            ) -join [Environment]::NewLine
                    }
                }

                # If we routed to a string, we will close the response with the string.
                if ($routedTo -is [string]) {
                    $response.Close($OutputEncoding.GetBytes($routedTo), $true)
                    continue
                }

                # If we've routed to is a byte array, we will close the response with the byte array.
                if ($routedTo -is [byte[]]) {
                    $response.Close($routedTo, $true)
                    continue
                }                
                    
                # If we routed to a script block or command, we will try to execute it.
                if ($routedTo -is [ScriptBlock] -or 
                    $routedTo -is [Management.Automation.CommandInfo]) {
                    $routeSplat = [Ordered]@{}

                    # If the command had a `-Request` parameter, we will pass the request object.
                    if ($routeParameters -and $routeParameters[$routeKey].Request) {
                        $routeSplat['Request'] = $request
                    }
                    # If the command had a `-Response` parameter, we will pass the response object.
                    if ($routeParameters -and $routeParameters[$routeKey].Response) {
                        $routeSplat['Response'] = $response
                    }

                    # If the request has a query string, we will parse it and pass the values to the command.
                    if ($request.Url.QueryString) {
                        $parsedQuery = [Web.HttpUtility]::ParseQueryString($request.Url.QueryString)
                        foreach ($parsedQueryKey in $parsedQuery.Keys) {
                            if ($routeParameters[$routeKey][$parsedQueryKey]) {
                                $routeSplat[$parsedQueryKey] = $parsedQuery[$parsedQueryKey]
                            }
                        }
                    }
                    # If the request has a content type of json, we will parse the json and pass the values to the command.
                    if ($request.ContentType -match '^(?>application|text)/json') {
                        $streamReader = [IO.StreamReader]::new($request.InputStream)
                        $json = $streamReader.ReadToEnd()
                        $jsonHashtable = ConvertFrom-Json -InputObject $json -AsHashtable
                        foreach ($keyValuePair in $jsonHashtable.GetEnumerator()) {
                            if ($routeParameters[$routeKey][$keyValuePair.Key]) {
                                $routeSplat[$keyValuePair.Key] = $keyValuePair.Value
                            }
                        }
                        $streamReader.Close()
                        $streamReader.Dispose()
                    }

                    # If the request has a content type of form-urlencoded, we will parse the form and pass the values to the command.
                    if ($request.ContentType -eq 'application/x-www-form-urlencoded') {
                        $streamReader = [IO.StreamReader]::new($request.InputStream)
                        $formData = [Web.HttpUtility]::ParseQueryString($streamReader.ReadToEnd())
                        foreach ($formKey in $formData.Keys) {
                            if ($routeParameters[$routeKey][$formKey]) {
                                $routeSplat[$formKey] = $form[$formKey]
                            }
                        }
                        $streamReader.Close()
                        $streamReader.Dispose()
                    }

                    # We will execute the command and get the output.
                    $routeOutput = . $routedTo @routeSplat
                    
                    # If the output is a string, we will close the response with the string.
                    if ($routeOutput -is [string]) 
                    {                        
                        $response.Close($OutputEncoding.GetBytes($routeOutput), $true)
                        continue
                    }
                    # If the output is a byte array, we will close the response with the byte array.
                    elseif ($routeOutput -is [byte[]]) 
                    {
                        $response.Close($routeOutput, $true)
                        continue
                    }
                    # If the response is an array, write the responses out one at a time.
                    # (note: this will likely be changed in the future)
                    elseif ($routeOutput -is [object[]]) {
                        foreach ($routeOut in $routeOutput) {                                
                            if ($routeOut -is [string]) {
                                $routeOut = $OutputEncoding.GetBytes($routeOut)
                            }
                            if ($routeOut -is [byte[]]) {
                                $response.OutputStream.Write($routeOut, 0, $routeOut.Length)
                            }
                        }
                        $response.Close()
                    }
                    else {
                        # If the response was an object, we will convert it to json and close the response with the json.
                        $responseJson = ConvertTo-Json -InputObject $routeOutput -Depth 3
                        $response.ContentType = 'application/json'
                        $response.Close($OutputEncoding.GetBytes($responseJson), $true)
                    }
                }
            }
        }                    
    }

    process {
        # Sometimes we want to customize the behavior of a command based off of the input object
        # So, start off by capturing $_
        $inputObject = $_
        # If the input was a job, we might remap a parameter
        if ($inputObject -is 'Management.Automation.Job') {
            if ($inputObject.WebSocket -is [Net.WebSockets.ClientWebSocket] -and 
                $inputObject.SocketUrl) {
                $SocketUrl = $inputObject.SocketUrl
            }
            if ($inputObject.HttpListener -is [Net.HttpListener] -and 
                $inputObject.RootUrl) {
                $RootUrl = $inputObject.RootUrl
            }
        }
        if ((-not $SocketUrl) -and (-not $RootUrl)) {
            $socketAndListenerJobs =
                foreach ($job in Get-Job) {
                    if (
                        $Job.WebSocket -is [Net.WebSockets.ClientWebSocket] -or 
                        $Job.HttpListener -is [Net.HttpListener]
                    ) {
                        $job
                    }
                }
            $socketAndListenerJobs
        }
        # First, let's pack all of the parameters into a dictionary of variables.
        foreach ($keyValuePair in $PSBoundParameters.GetEnumerator()) {
            $Variable[$keyValuePair.Key] = $keyValuePair.Value
        }
        
        $Variable['MainRunspace'] = [Runspace]::DefaultRunspace
        if (-not $variable['BufferSize']) {
            $variable['BufferSize'] = $BufferSize
        }
        $StartThreadJobSplat = [Ordered]@{
            InitializationScript = $InitializationScript
            ThrottleLimit = $ThrottleLimit
        }

        # If we're going to be listening for HTTP requests, run a thread job for the server.        
        if ($RootUrl) {

            if (-not $Name) {
                $Name = "$($RootUrl -join '|')"
            }

            $existingJob = foreach ($jobWithThisName in (Get-Job -Name $Name -ErrorAction Ignore)) {
                if (
                    $jobWithThisName.State -in 'Running','NotStarted' -and
                    $jobWithThisName.HttpListener -is [Net.HttpListener]
                ) {
                    $jobWithThisName
                    break
                }
            }

            if ((-not $existingJob) -or $Force) {
                $variable['HttpListener'] = $httpListener = [Net.HttpListener]::new()
                foreach ($potentialPrefix in $RootUrl) {
                    if ($potentialPrefix -match '^https?://') {
                        $httpListener.Prefixes.Add($potentialPrefix)
                    } else {
                        $httpListener.Prefixes.Add("http://$potentialPrefix/")
                        $httpListener.Prefixes.Add("https://$potentialPrefix/")
                    }
                }
                $httpListener.Start()
            }            

            if ($DebugPreference -notin 'SilentlyContinue','Ignore') {
                . $SocketServerJob -Variable $Variable
            } else {                
                if ($existingJob -and -not $Force) {
                    $httpListenerJob = $existingJob
                    $httpListener = $existingJob.HttpListener
                } else {
                    $httpListenerJob = Start-ThreadJob -ScriptBlock $SocketServerJob -Name "$RootUrl" -ArgumentList $Variable @StartThreadJobSplat                    
                    $httpListenerJob.pstypenames.insert(0, 'WebSocket.ThreadJob')
                    $httpListenerJob.pstypenames.insert(0, 'WebSocket.Server.ThreadJob')
                }
            }
            
            # If we have a listener job
            if ($httpListenerJob) {
                # and the job has not started
                if ($httpListenerJob.JobStateInfo.State -eq 'NotStarted') {
                    # sleep for no time (this will allow the job to start)
                    Start-Sleep -Milliseconds 0 
                }                
                foreach ($keyValuePair in $Variable.GetEnumerator()) {
                    $httpListenerJob.psobject.properties.add(
                        [psnoteproperty]::new($keyValuePair.Key, $keyValuePair.Value), $true
                    )
                }

                if (-not $Broadcast) {
                    $httpListenerJob
                }
            }            
        }

        # If `-Debug` was passed,
        if ($DebugPreference -notin 'SilentlyContinue','Ignore') {
            # run the job in the current scope (so we can debug it).
            . $SocketClientJob -Variable $Variable
            return
        }

        # If -Debug was not passed, we're running in a background thread job.
        $webSocketJob =
            if ($SocketUrl) {
                # If we had no name, we will use the SocketUrl as the name.
                if (-not $name) {
                    # and we will ensure that it starts with `ws://` or `wss://`
                    $Name = $SocketUrl -replace '^http', 'ws'
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

                if ($existingJob -and -not $Force) {
                    $existingJob
                } else {
                    Start-ThreadJob -ScriptBlock $SocketClientJob -Name $Name -ArgumentList $Variable @StartThreadJobSplat
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

        if ($webSocketJob -and -not $webSocketJob.WebSocket) {            
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
            $webSocketJob.pstypenames.insert(0, 'WebSocket.Client.ThreadJob')
        }

        # If we're broadcasting a message
        if ($Broadcast) {
            # find out who is listening.
            $socketList = @(
                if ($httpListener.SocketRequests) {
                    @(foreach ($queue in $httpListener.SocketRequests.Values) {
                        foreach ($socket in $queue) {
                            if ($socket.WebSocket.State -eq 'Open') {
                                $socket.WebSocket
                            }                                
                        }
                    })
                }
                if ($webSocketJob.WebSocket) {
                    $webSocketJob.WebSocket
                }
            )

            # If no one is listening, write a warning.
            if (-not $socketList) {
                Write-Warning "No one is listening"
            }

            # If the broadcast is a scriptblock or command, run it.
            if ($Broadcast -is [ScriptBlock] -or 
                $Broadcast -is [Management.Automation.CommandInfo]) {
                $Broadcast = & $Broadcast
            }
            # If the broadcast is a byte array, convert it to an array segment.
            if ($broadcast -is [byte[]]) {
                $broadcast = [ArraySegment[byte]]::new($broadcast)
            }

            # If the broadcast is an array segment, send it as binary.
            if ($broadcast -is [ArraySegment[byte]]) {
                foreach ($socket in $socketList) {
                    $null = $socket.SendAsync($broadcast, 'Binary', 'EndOfMessage', [Threading.CancellationToken]::None)
                }                
            }
            else {
                # Otherwise, convert the broadcast to JSON.
                $broadcastJson = ConvertTo-Json -InputObject $Broadcast
                $broadcastJsonBytes = $OutputEncoding.GetBytes($broadcastJson)
                $broadcastSegment = [ArraySegment[byte]]::new($broadcastJsonBytes)
                foreach ($socket in $socketList) {
                    $null = $socket.SendAsync($broadcastSegment, 'Text', 'EndOfMessage', [Threading.CancellationToken]::None)
                }                
            }
            $Broadcast # emit the broadcast.
        }
        
        if ($Watch -and $webSocketJob) {
            do {
                $webSocketJob | Receive-Job
                Start-Sleep -Milliseconds (
                    7, 11, 13, 17, 19, 23 | Get-Random
                ) 
            } while ($webSocketJob.State -in 'Running','NotStarted')
        } 
        elseif ($WatchFor -and $webSocketJob) {
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
        elseif ($webSocketJob -and -not $broadcast) {
            $webSocketJob
        }        
    }
}
