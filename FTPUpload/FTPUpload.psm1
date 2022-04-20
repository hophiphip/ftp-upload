<# 
    .Synopsis 
     Backup directory to the FTP server.

    .Description
     Backup directory to the FTP server. This function can log to the specified file.

    .Parameter FTPHost
     FTP server hostname.

     .Parameter FTPUser
     FTP server username.

     .Parameter FTPPass
     FTP server user password.

     .Parameter uploadPath
     Local file/folder to upload.

     .Parameter contents
     In case provided path is a folder, upload only contents of this folder.
#>
function FTPUpload {
    param (
        [Parameter(Mandatory, HelpMessage = "Enter FTP server hostname.")]
        [string]$FTPHost,

        [Parameter(Mandatory, HelpMessage = "Enter FTP server username.")]
        [string]$FTPUser,

        [Parameter(Mandatory, HelpMessage = "Enter FTP server user password.")]
        [string]$FTPPass,

        [Parameter(Mandatory, HelpMessage = "Enter local file or folder to upload.")]
        [string]$uploadPath,

        [switch]$contents = $false
    )
    
    $webclient             = New-Object System.Net.WebClient 
    $webclient.Credentials = New-Object System.Net.NetworkCredential($FTPUser,$FTPPass)  

    if (-not (Test-Path $uploadPath)) {
        "Provided path is incorrect. File doesn't exist"
        return
    }

    if ($false -eq ((Get-Item $uploadPath) -is [System.IO.DirectoryInfo])) {
        #
        # Not a directory, just a file. Upload the file and exit.
        #
        $entry     = (Get-Item $uploadPath)
        $fullName  = $entry.FullName
        $name      = $entry.Name
        $directory = $entry.Directory.FullName

        $srcPath = $directory -Replace "\\", "\\" -Replace "\:", "\:"
        $dstFile = $fullName -Replace $srcPath, $FTPHost
        $dstFile = $dstFile -Replace "\\", "/"

        $uri = New-Object System.Uri($dstFile)

        $webclient.UploadFile($uri, $fullName)

        # Log upload status
        "Uploaded:" + $fullName + " To:" + $FTPHost 

        return
    }

    # Upload folder with its contents
    $uploadPath = (Get-Item $uploadPath).FullName

    $directoryFullName = $uploadPath
    $directoryName     = (Get-Item $uploadPath).Name

    $entries = Get-ChildItem $uploadPath -Recurse
    $folders = $entries | Where-Object { $_.PSIsContainer}
    $files   = $entries | Where-Object {!$_.PSIsContainer}

    # Create FTP directory with the upload folder name and update FTP path
    if (-not $contents) {
        $dstFolder = $FTPHost.TrimEnd('/') + '/' + $directoryName
        TryCreateFtpFolder -dstFolder $dstFolder -FTPUser $FTPUser -FTPPass $FTPPass
    }

    $srcFolderPath = (Get-Item $uploadPath).Parent.FullName.TrimEnd('/')

    ## Create FTP sub-directories
    foreach($folder in $folders)
    {    
        $dstFolder = ""
        if ($contents) {
            $dstFolder = $folder.FullName -Replace $folder.Parent.FullName, $FTPHost
        }
        else {
            $dstFolder = $folder.Fullname -Replace $srcFolderPath, $FTPHost
        }

        $dstFolder = $dstFolder.Replace("\", "/")

        TryCreateFtpFolder -dstFolder $dstFolder -FTPUser $FTPUser -FTPPass $FTPPass
    }

    $srcFilePath = $srcFolderPath
    if ($contents) {
        $srcFilePath = $uploadPath.TrimEnd('/')
    }

    ## Upload Files
    foreach($entry in $files)
    {
        $srcFullname = $entry.fullname
        $srcName     = $entry.Name

        $dstFile = $srcFullname.Replace($srcFilePath, $FTPHost + "/")
        $dstFile = $dstFile.Replace("\", "/")

        $uri = New-Object System.Uri($dstFile) 

        $webclient.UploadFile($uri, $srcFullname)

        "Uploaded:" + $srcFullname
    }
}

function TryCreateFtpFolder {
    <#
        .Synopsis
        Create a folder on FTP server.

        .Parameter dstFolder
        FTP folder path complete with FTP host.

        .Parameter FTPUser
        FTP server username.

        .Parameter FTPPass
        FTP server user password.

        .Example
        TryCreateFtpFolder -dstFolder 'ftp://127.0.0.1/some-ftp-folder' -FTPUser someuser -FTPPass somepass
    #>
    param (
        [Parameter(Mandatory)]
        [string]$dstFolder,

        [Parameter(Mandatory)]
        [string]$FTPUser,

        [Parameter(Mandatory)]
        [string]$FTPPass
    )

    try {
            $makeDirectory             = [System.Net.WebRequest]::Create($dstFolder);
            $makeDirectory.Credentials = New-Object System.Net.NetworkCredential($FTPUser, $FTPPass);
            $makeDirectory.Method      = [System.Net.WebRequestMethods+FTP]::MakeDirectory;
            $makeDirectory.GetResponse();

            # Log folder created successfully
            "Created folder:" + $dstFolder
    }
    catch [Net.WebException] {
            try {
                #if there was an error returned, check if folder already existed on server

                $checkDirectory             = [System.Net.WebRequest]::Create($dstFolder);
                $checkDirectory.Credentials = New-Object System.Net.NetworkCredential($FTPUser, $FTPPass);
                $checkDirectory.Method      = [System.Net.WebRequestMethods+FTP]::PrintWorkingDirectory;

                $response = $checkDirectory.GetResponse();

                #folder already exists!
                "Folder:" + $dstFolder + " already exists"
            }
            catch [Net.WebException] {
                
                #if the folder didn't exist
                "Unknown error while creating folder:" + $dstFolder
            }
    }
}

Export-ModuleMember -Function FTPUpload
