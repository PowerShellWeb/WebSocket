
describe WebSocket {
    it 'Can get websocket content' {
        $websocketContent = @(websocket wss://jetstream2.us-east.bsky.network/subscribe -TimeOut 00:00:01 -Watch)

        $websocketContent.Count | Should -BeGreaterThan 0
    }
}