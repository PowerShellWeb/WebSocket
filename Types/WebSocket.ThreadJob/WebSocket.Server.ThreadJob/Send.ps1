<#
.SYNOPSIS
    Sends a WebSocket message.
.DESCRIPTION
    Sends a message from a WebSocket server.
#>
param(
[PSObject]
$Message,

[string]
$Pattern
)

function sendMessage {
    param([Parameter(ValueFromPipeline)]$msg, [PSObject[]]$Sockets)
    process {
        if ($msg -is [byte[]]) {
            $messageSegment = [ArraySegment[byte]]::new($msg)
            foreach ($socket in $sockets) {
                if ($null -ne $messageSegment -and $socket.SendAsync) {
                    $null = $socket.SendAsync($messageSegment, 'Binary', 'EndOfMessage',[Threading.Cancellationtoken]::None)
                }    
            }
            
        } else {
            $jsonMessage = ConvertTo-Json -InputObject $msg
            $messageSegment = [ArraySegment[byte]]::new($OutputEncoding.GetBytes($jsonMessage))
            foreach ($socket in $sockets) {
                if ($null -ne $messageSegment -and $socket.SendAsync) {
                    $null = $socket.SendAsync($messageSegment, 'Binary', 'EndOfMessage',[Threading.Cancellationtoken]::None)
                }    
            }
        }
        $msg
    }
}

$patternAsRegex = $pattern -as [regex]
$socketList = @(    
    foreach ($socketConnection in $this.HttpListener.SocketRequests.Values) {                
        if (
            $patternAsRegex -and 
            $socketConnection.WebSocketContext.RequestUri -match $pattern
        ) {
            $socketConnection.WebSocket
        }
        elseif (
            $pattern -and 
            $socketConnection.WebSocketContext.RequestUri -like $pattern
        ) {
            $socketConnection.WebSocket
        }
        else {
            $socketConnection.WebSocket
        }
    }
)


if ($message -is [Collections.IList] -and $message -isnot [byte[]]) {
    $Message | sendMessage -Sockets $socketList
} else {
    sendMessage -msg $Message -Sockets $socketList
}




