[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(Mandatory=$true)]
    [string]$file, 
    [Parameter(Mandatory=$true)]
    [string]$server,
    [Parameter(Mandatory=$true)]
    [string]$repo,
    [Parameter(Mandatory=$true)]
	[string]$directory,
    [Parameter(Mandatory=$true)]
    [string]$user,
    [Parameter(Mandatory=$true)]
    [string]$password
)

class Uploader 
{
    [string] $file;
    [string] $server;
    [string] $repo;
	[string] $directory;
    [string] $user;
    [string] $password;

    [string] $token;
    [string] $uploadLink;
    [string] $filename;
	[string] $repoid;

    Uploader([string] $file, [string] $server, [string] $repo, [string] $directory, [string] $user, [string] $password) 
	{
        $this.file     	= $file;
		$this.filename  = (Get-Item $this.file).Name;
        $this.server   	= $server;
        $this.repo     	= $repo;
		$this.directory = $directory;
        $this.user     	= $user;
        $this.password 	= $password;
    }

    [void] GetToken() 
	{
		Write-Host "Get token..."	
		
		$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
		$headers.Add("Content-Type", "application/json")

		$body = "{
		`n    `"username`": `"$($this.user)`",
		`n    `"password`": `"$($this.password)`"
		`n}"
		$address = $this.server + "/api2/auth-token/"
		
		$response = Invoke-RestMethod $address -Method 'POST' -Headers $headers -Body $body
		$this.token = $response.token
    }

	[void] GetRepoId()
	{
		Write-Host "Get repo id..."	
		
		$address = "$($this.server)/api2/repos/"
		
		$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
		$headers.Add("Authorization", "Token " + $($this.token))
		
		$response = Invoke-RestMethod $address -Method 'GET' -Headers $headers | ConvertTo-Json | ConvertFrom-Json
		
		$result = ($response | Where { $_.name -eq $this.repo}).id
		$this.repoid = $result
	}

    [void] GetLink() 
	{
		Write-Host "Get upload link..."	
	
		$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
		$headers.Add("Authorization", "Token " + $($this.token))
		$headers.Add("Accept", "*/*")
		
		$address = "$($this.server)/api2/repos/$($this.repoId)/upload-link"
		
		$this.uploadLink = Invoke-RestMethod $address -Method 'GET' -Headers $headers -PreserveAuthorizationOnRedirect
    }

    [void] Run()
	{
        $this.GetToken();
		$this.GetRepoId();
        $this.GetLink();
		$this.Upload();
    }
	
	[void] Upload()
	{
		Write-Host "Run uploader..."		
		
		$multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
		$multipartFile = $this.file
		$FileStream = [System.IO.FileStream]::new($multipartFile, [System.IO.FileMode]::Open)
		$fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
		$fileHeader.Name = '"file"'
		$fileHeader.FileName = '"' + $this.filename + '"'
		$fileContent = [System.Net.Http.StreamContent]::new($FileStream)
		$fileContent.Headers.ContentDisposition = $fileHeader
		$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/plain")
		
		$dirHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
		$dirHeader.Name = '"parent_dir"'
		$dirContent = [System.Net.Http.StringContent]::new($this.directory)
		$dirContent.Headers.ContentDisposition = $dirHeader
		
		$multipartContent.Add($fileContent)
		$multipartContent.Add($dirContent)
		
		$b = $multipartContent.Headers.ContentType.Parameters | Where-Object { $_.Name -eq 'boundary' }
		$b.Value = $b.Value.Trim('"')

		Invoke-RestMethod -Uri $this.uploadlink -Body $multipartContent -Method 'POST'
	}
}

function main() 
{
    [Uploader]::new($file, $server, $repo, $directory, $user, $password).Run();
}

main;