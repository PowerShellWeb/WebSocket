<#
.SYNOPSIS
    Sends a WebSocket message.
.DESCRIPTION
    Sends a message to a WebSocket server.
#>
param(
[PSObject]
$Message
)

function sendMessage {
    param([Parameter(ValueFromPipeline)]$msg)
    process {
        if ($msg -is [byte[]]) {
            [ArraySegment[byte]]$messageSegment = [ArraySegment[byte]]::new($msg)
            if ($null -ne $messageSegment -and $this.WebSocket.SendAsync) {
                $this.WebSocket.SendAsync($messageSegment, 'Binary', 'EndOfMessage',[Threading.Cancellationtoken]::None)
            }
        } else {
            $jsonMessage = ConvertTo-Json -InputObject $msg
            $messageSegment = [ArraySegment[byte]]::new($OutputEncoding.GetBytes($jsonMessage))
            if ($null -ne $jsonMessage -and $this.WebSocket.SendAsync) {
                $this.WebSocket.SendAsync($messageSegment, 'Text', 'EndOfMessage', [Threading.Cancellationtoken]::None)
            }
        }
    }
}

if ($message -is [Collections.IList] -and $message -isnot [byte[]]) {
    $Message | sendMessage
} else {
    sendMessage -msg $Message
}




