<# 
    .Synopsis 
    Backup directory to the FTP server.

    .Description
    Backup directory to the FTP server. This function can log to the specified file.

    .Example
    # Upload folder to the server, with logs to the specified folder and deleting files after upload. 
    FTPUpload -Ftp "ftp://127.0.0.1" -User "ftpuser" -Passwd "ftppass" -Directory "C:\LocalFolder" -Logs -LogFolder "C:\PowerShell\FTP-Upload-Logs" -Cleanup
#>
function FTPUpload {
    param (
        [string]$ftp       = "ftp://<FTP-HOST>", ## FTP server hostname
        [string]$user      = "<FTP-USER>", ## FTP server username
        [string]$passwd    = "<FTP-PASSWORD>", ## FTP server user password
        [string]$directory = "C:\<LOCAL-BACKUP-DIRECTORY>", ## Local directory for upload to FTP server
        
        [switch]$logs    = $false, ## Enable logs to STDOUT
        [switch]$cleanup = $true,  ## Delete files after upload
    
        [string]$logFolder = "C:\PowerShell" ## Folder to store log files
    )
    
    $backupUpdateTime  = (Get-Date).Year.ToString()
    $backupUpdateTime += (Get-Date).Month.ToString()
    $backupUpdateTime += (Get-Date).Day.ToString()
    $backupUpdateTime += (Get-Date).Hour.ToString()
    $backupUpdateTime += (Get-Date).Minute.ToString()
    $backupUpdateTime += (Get-Date).Second.ToString()
    $today             = (Get-Date -Format yyyy-MM-dd)
    
    $serverHostName = [System.Net.DNS]::GetHostByName('').HostName 
    $logFilePath    = $logFolder + "\FTPBackup_" + $today + ".txt"
     
    $webclient             = New-Object System.Net.WebClient 
    $webclient.Credentials = New-Object System.Net.NetworkCredential($user, $passwd) 
    
    Clear-Host
    
    if ($logs) {
        Write-Host $logFilePath
    }
    
    # Create log folder/file if it doesnt exist
    if (-not (Test-Path $logFilePath)) {
        New-Item -Path $logFilePath -Force
    }
    
    # Start logs
    "From:" + $directory + " (on server:" + $serverHostName + ") To:" + $ftp | Out-File $logFilePath -Append
    "Start: " + (Get-Date) | Out-File $logFilePath -Append
    
    # Get all files from backup directory
    $files = @(Get-ChildItem -Path  $directory -Recurse | ?{ !$_.PSIsContainer } | Where-Object { $_.lastwritetime -gt (Get-Date).AddDays(-1)} | Select-Object -ExpandProperty FullName )
    
    foreach ($item in $files) 
    {
        if ($item -ne $null) 
        {
            # Construct path
            $uri = New-Object System.Uri($ftp + $item.Substring(3))
    
            # Upload file to FTP server
            $webclient.UploadFile($uri, $item)
    
            # Log uploaded file name to STDOUT if necessary
            if ($logs) {
                Write-Host (Get-Date)$item
            }
            
            # Update log file
            "$(Get-Date): " + $item | Out-File $logFilePath -Append
    
            # Delete uplaoded file if necessary
            if ($cleanup) {
                Remove-Item $item
            }
        }
    }
    
    # Cleanup
    $webclient.Dispose()
    
    # Stop logs
    "End:" + (Get-Date) | Out-File $logFilePath -Append
}

Export-ModuleMember -Function FTPUpload
