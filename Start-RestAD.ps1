#requires -modules ActiveDirectory
[CmdletBinding()]
Param(
    [Int]$TCPPort = 8080,
    [Boolean]$LocalSite = $true
)

#region Functions
Function Convert-UrlToParams {
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String]$Url
    )

    [Collections.Hashtable]$Params = @{}
    $UrlSplit = $Url.Split('\?')
    $BaseUrl  = $UrlSplit[0].Split('/')
    $UrlParam = $UrlSplit[1]

    if ($null -ne $UrlParam) {
        $UrlParam.Split('&') | ForEach-Object -Process {
            $tmp = $_ -split "=\'"
            $null = $Params.Add($tmp[0], $tmp[1].replace("'",''))
        }
    }

    [PSCustomObject][Ordered]@{
        Endpoint   = $BaseUrl[3]
        Identity   = $BaseUrl[4]
        Parameters = $Params
    }
}
#endregion Functions

#region Create a listener
$HttpListener = New-Object System.Net.HttpListener
if ($LocalSite -eq $true) {
    $HttpListener.Prefixes.Add('http://localhost:{0}/' -f $TCPPort) 
} else {
    $HttpListener.Prefixes.Add('http://+:{0}/' -f $TCPPort) 
}
try {
    $HttpListener.Start()
    'Listening ...'
}
catch {
    throw $_
}
#endregion Create a listener

#region Main
while ($true) {
    $Context = $HttpListener.GetContext()
    
    #Capture the details about the request
    $Request = $Context.Request

    #Setup a place to deliver a response
    $Response = $Context.Response

    Write-Host -Object $Request.Url
   
    #Break from loop if GET request sent to /StopAPI
    $UrlInfos = Convert-UrlToParams -Url $Request.Url
    if ($UrlInfos.Endpoint -Contains 'Stop-RestAD') {
        $Message = 'See you!'

        #Convert the data to UTF8 bytes
        [byte[]]$Buffer = [System.Text.Encoding]::UTF8.GetBytes($Message)

        # Set length of response
        $Response.ContentType = 'application/json'
        $Response.ContentLength64 = $Buffer.length
        
        # Write response out and close
        $Output = $Response.OutputStream
        $Output.Write($Buffer, 0, $Buffer.length)
        $Output.Close()
        Break 
    } else {
        [Collections.Hashtable]$QuerySplat = @{}
        if (![String]::IsNullOrEmpty($UrlInfos.Parameters)) {
            $UrlInfos.Parameters.Keys | ForEach-Object -Process {
                if ($UrlInfos.Parameters[$_] -match ',') {
                    $Value = $UrlInfos.Parameters[$_].split(',')
                } else {
                    $Value = $UrlInfos.Parameters[$_]
                }
                $null = $QuerySplat.Add($_, $Value)
            }
        }
        if (![String]::IsNullOrEmpty($UrlInfos.Identity)) {
            $QuerySplat.Add('Identity', $UrlInfos.Identity)
        }

        switch ($UrlInfos.Endpoint) {
            'User' {
                try {
                    if ($QuerySplat.Count -eq 0) {
                        $Result = Get-ADUser -Filter *
                    } else {
                        $Result = Get-ADUser @QuerySplat
                    }
                    if ($UrlInfos.Parameters.Properties -or $UrlInfos.Parameters.Property) {
                        $Result = $Result | Select-Object -Property $UrlInfos.Parameters.Properties.Split(',')
                    }
                }
                catch {
                    $Result = $_.ToString()
                }
            }
            'Group' {
                try {
                    if ($QuerySplat.Count -eq 0) {
                        $Result = Get-ADGroup -Filter *
                    } else {
                        $Result = Get-ADGroup @QuerySplat
                    }
                    if ($UrlInfos.Parameters.Properties) {
                        $Result = $Result | Select-Object -Property $UrlInfos.Parameters.Properties.Split(',')
                    }
                }
                catch {
                    $Result = $_.ToString()
                }
            }
            'Site' {
                try {
                    if ($QuerySplat.Count -eq 0) {
                        $Result = Get-ADReplicationSite -Filter *
                    } else {
                        $Result = Get-ADReplicationSite @QuerySplat
                    }
                    if ($UrlInfos.Parameters.Properties) {
                        $Result = $Result | Select-Object -Property $UrlInfos.Parameters.Properties.Split(',')
                    }
                }
                catch {
                    $Result = $_.ToString()
                }
            }
            'Subnet' {
                try {
                    if ($QuerySplat.Count -eq 0) {
                        $Result = Get-ADReplicationSubnet -Filter *
                    } else {
                        $Result = Get-ADReplicationSubnet @QuerySplat
                    }
                    if ($UrlInfos.Parameters.Properties) {
                        $Result = $Result | Select-Object -Property $UrlInfos.Parameters.Properties.Split(',')
                    }
                }
                catch {
                    $Result = $_.ToString()
                }
            }
            Default {
                #404 message
                $Result = 'Endpoint not found.'
            }
        }

        $Message = $Result | ConvertTo-Json

        #Convert the data to UTF8 bytes
        [byte[]]$Buffer = [System.Text.Encoding]::UTF8.GetBytes($Message)
       
        # Set length of response
        $Response.ContentType = 'application/json'
        $Response.ContentLength64 = $Buffer.length
       
        # Write response out and close
        $Output = $Response.OutputStream
        $Output.Write($Buffer, 0, $Buffer.length)
        $Output.Close()
   }    
}
#endregion Main

#Terminate the listener
$HttpListener.Stop()