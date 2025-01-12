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
    [Alias('Url','Uri','WebSocketUrl')]
    [uri]
    $WebSocketUri,

    # One or more root urls.
    # If these are provided, a WebSocket server will be created with these listener prefixes.
    [Parameter(Position=1,ValueFromPipelineByPropertyName)]
    [Alias('HostHeader','Host','CNAME','ServerURL','ListenerPrefix','ListenerPrefixes','ListenerUrl')]
    [string[]]
    $RootUrl,

    # A route table for all requests.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Routes','RouteTable','WebHook','WebHooks')]
    [Collections.IDictionary]
    $Route,

    # The Default HTML.
    # This will be displayed when visiting the root url.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('DefaultHTML','Home','Index','IndexHTML','DefaultPage')]
    [string]
    $HTML,

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
        
            # While the listener is listening,
            while ($httpListener.IsListening) {
                # get the context asynchronously.
                $contextAsync = $httpListener.GetContextAsync()
                # and wait for it to complete.
                while (-not ($contextAsync.IsCompleted -or $contextAsync.IsFaulted -or $contextAsync.IsCanceled)) {
                    # while this is going on, other events can be processed, and CTRL-C can exit.
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
                        $httpListener.SocketRequests[$context.Request.RequestTraceIdentifier] = $webSocketResult
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
                                $SiteHeader
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
        if ((-not $WebSocketUri) -and (-not $RootUrl)) {
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

        # If we're going to be listening for HTTP requests, run a thread job for the server.        
        if ($RootUrl) {

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

            if ($DebugPreference -notin 'SilentlyContinue','Ignore') {
                . $SocketServerJob -Variable $Variable
            } else {
                $httpListenerJob = Start-ThreadJob -ScriptBlock $SocketServerJob -Name "$RootUrl" -InitializationScript $InitializationScript -ArgumentList $Variable
            }            
            
            if ($httpListenerJob) {
                foreach ($keyValuePair in $Variable.GetEnumerator()) {
                    $httpListenerJob.psobject.properties.add(
                        [psnoteproperty]::new($keyValuePair.Key, $keyValuePair.Value), $true
                    )
                }
                $httpListenerJob
            }                        
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
        elseif ($webSocketJob) {
            $webSocketJob
        }        
    }
}
