# Security

We take security seriously.  If you believe you have discovered a vulnerability, please [file an issue](https://github.com/PowerShellWeb/WebSocket/issues).

## Special Security Considerations

WebSockets are not inherantly dangerous, but what comes out of them might well be.

In order to avoid data poisoning attacks, please _never_ directly run any code from the internet that you do not trust.

Please also assume all WebSockets are untrustworthy.

There are a few easy ways to do this.

WebSocket responses should never:

1. Be piped into `Invoke-Expression`
2. Be expanded with `.ExpandString`
3. Be directly placed into a `SQL` query

