<#
.SYNOPSIS
    Starts the container.
.DESCRIPTION
    Starts a container.

    This script should be called from the Dockerfile as the ENTRYPOINT (or from within the ENTRYPOINT).

    It should be deployed to the root of the container image.

    ~~~Dockerfile
    # Thank you Microsoft!  Thank you PowerShell!  Thank you Docker!
    FROM mcr.microsoft.com/powershell
    # Set the shell to PowerShell (thanks again, Docker!)
    SHELL ["/bin/pwsh", "-nologo", "-command"]
    # Run the initialization script.  This will do all remaining initialization in a single layer.
    RUN --mount=type=bind,src=./,target=/Initialize ./Initialize/Container.init.ps1

    ENTRYPOINT ["pwsh", "-nologo", "-noexit", "-file", "/Container.start.ps1"]
    ~~~
.NOTES
    Did you know that in PowerShell you can 'use' namespaces that do not really exist?
    This seems like a nice way to describe a relationship to a container image.
    That is why this file is using the namespace 'mcr.microsoft.com/powershell'.
    (this does nothing, but most likely will be used in the future)
#>

#use container ghcr.io/powershellweb/websocket

param()

$env:IN_CONTAINER = $true
$PSStyle.OutputRendering = 'Ansi'

$mountedFolders = @(if (Test-Path '/proc/mounts') {
    (Select-String "\S+\s(?<p>\S+).+rw?,.+symlinkroot=/mnt/host" "/proc/mounts").Matches.Groups |
        Where-Object Name -eq p |
        Get-Item -path { $_.Value }
})
   
if ($mountedFolders) {
    "Mounted $($mountedFolders.Length) folders:" | Out-Host
    $mountedFolders | Out-Host
}

if ($args) {
    # If there are arguments, output them (you could handle them in a more complex way).
    "$args" | Out-Host
    $global:ContainerStartArguments = @() + $args

    #region Custom
    
    #endregion Custom
} else {
    # If there are no arguments, see if there is a Microservice.ps1
    if (Test-Path './Microservice.ps1') {
        # If there is a Microservice.ps1, run it.
        . ./Microservice.ps1
    }
    #region Custom
    else 
    {        
        # If a single drive is mounted, start the socket files.
        $webSocketFiles = $mountedFolders | Get-ChildItem -Filter *.WebSocket.ps1 
        foreach ($webSocketFile in $webSocketFiles) {
            Start-ThreadJob -Name $webSocketFile.Name -ScriptBlock { . $using:webSocketFile.FullName }
            . $webSocketFile.FullName
        }
    }
    #endregion Custom
}

# If you want to do something when the container is stopped, you can register an event.
# This can call a script that does some cleanup, or sends a message as the service is exiting.
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if (Test-Path '/Container.stop.ps1') {
        & /Container.stop.ps1 
    }    
} | Out-Null