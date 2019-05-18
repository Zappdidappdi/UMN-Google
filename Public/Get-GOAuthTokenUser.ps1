function Get-GOAuthTokenUser
{
    <#
        .Synopsis
            Get Valid OAuth Token.  
        
        .DESCRIPTION
            The access token is good for an hour, the refresh token is mostly permanent and can be used to get a new access token without having to reauthenticate.
        
        .PARAMETER clientID
            The google OAuth Client ID

        .PARAMETER clientSecret
            The corresponding client secret that matches the Client ID

        .PARAMETER redirectUri
            An http redirect uri, must match one of the Authorized redirect URIs given for the OAuth client ID you are creating a token for
            Defaults to http://localhost:8080/oauth2callback
            Powershell will create a listener on that port as part of generating a new access token, so it must be unused when you run this
            If 8080 is unavailable on your system, you can specify an alternate URL here, but you should only need to change the port

        .PARAMETER refreshToken
            A refresh token if refreshing, generated by this cmdlet.

        .PARAMETER scope
            The API scopes to be included in the request. Space delimited, "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive"
            Only needed when generating a new token
        
        .EXAMPLE
            Get-GOAuthTokenUser -clientID $clientID -clientSecret $clientSecret -redirectUri "http://localhost:9090/oauth2callback" -scope "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive"
                
        .EXAMPLE
            Get-GOAuthTokenUser -clientID $clientID -clientSecret $clientSecret -refreshToken $refreshToken
            
        .NOTES
            Must be run on a machine where you can run a browser, or be able to redirect traffic from a local browser to the listener specified with redirectUri
    #>
    [CmdletBinding()]
    [OutputType([array])]
    Param
    (
        [Alias("appKey")]
        [Parameter(Mandatory)]
        [string]$clientID,

        [Alias("appSecret")]
        [Parameter(Mandatory)]
        [string]$clientSecret,
        
        [Parameter(ParameterSetName="NewToken")]
        [string]$redirectUri="http://localhost:8080/oauth2callback",

        [Parameter(Mandatory,ParameterSetName="Refresh")]
        [string]$refreshToken,

        [Parameter(Mandatory,ParameterSetName="NewToken")]
        [string]$scope

    )

    Begin
    {
        $requestUri = "https://www.googleapis.com/oauth2/v4/token"
    }
    Process
    {

        if($PSCmdlet.ParameterSetName -eq "NewToken")
        {
            ### Get the authorization code - start an http listener to intercept the redirect
            $scope = $scope.Replace(' ','%20')
            $auth_string = "https://accounts.google.com/o/oauth2/v2/auth"
            $auth_string += "?client_id=$clientID"
            $auth_string += "&redirect_uri=$redirectUri"
            $auth_string += "&scope=$scope"
            $auth_string += "&access_type=offline"
            $auth_string += "&response_type=code&prompt=consent"
            Write-Host "Please open this link on the machine you're running this cmdlet on"
            Write-Host $auth_string
            $authorizationCode = New-GOAuthTokenCode -RedirectURI $redirectUri -matchString 'code=([^&]*)'

            # exchange the authorization code for a refresh token and access token
            $body = @{
                code=$authorizationCode;
                client_id=$clientID;
                client_secret=$clientSecret;
                redirect_uri=$redirectUri;
                grant_type="authorization_code"; # Fixed value
               };
 
            $response = Invoke-RestMethod -Method Post -Uri $requestUri -Body $body

            $props = @{
                accessToken = $response.access_token
                refreshToken = $response.refresh_token
            }
        }

        else
        { 
            # Exchange the refresh token for new tokens
            $requestBody = "refresh_token=$refreshToken&client_id=$appKey&client_secret=$appSecret&grant_type=refresh_token"
 
            $response = Invoke-RestMethod -Method Post -Uri $requestUri -ContentType "application/x-www-form-urlencoded" -Body $requestBody
            $props = @{
                accessToken = $response.access_token
                refreshToken = $refreshToken
            }
        }
        
    }
    End
    {
        return new-object psobject -Property $props
    }
}