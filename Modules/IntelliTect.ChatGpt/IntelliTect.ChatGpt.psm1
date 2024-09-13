
$completionsUri = 'https://api.openai.com/v1/completions'

Function Invoke-ChatGpt {
    [CmdletBinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline)][string]$Prompt,
        [string]$ApiKey = $env:OpenAIApiKey,
        [ValidateRange(0, 2)][float]$Temperature
    )

    if([string]::IsNullOrWhiteSpace($ApiKey)) {  
        $ApiKey = Read-Host -Prompt "What is the ApiKey (see https://openai.com/api/)?" -MaskInput
        if([string]::IsNullOrWhiteSpace($ApiKey)) {
            Write-Error "Missing an argument for parameter 'ApiKey'. Specify a parameter of type 'System.String' and try again."
        }
    }
    if($Temperature) {
        $body = "{
            ""model"": ""text-davinci-003"",
            ""prompt"": ""$Prompt"",
            ""temperature"": $Temperature
        }"
    }
    else {
        $body = "{
            ""model"": ""text-davinci-003"",
            ""prompt"": ""$Prompt""
        }"
    }
    Write-Debug "`$body = $body"

    $result = Invoke-WebRequest -uri $completionsUri `
        -Headers @{ 
            'Content-Type' = 'application/json'; `
            'Authorization' = "Bearer $ApiKey"
        } `
        -Method POST -body $body -ErrorVariable $LastError -ErrorAction Ignore

    # ToDo: Handle error (such as missing API key).
    # if($LastError) {
    #     $result | ConvertFrom-Json
    # }
    
    $result | Select-Object -ExpandProperty 'Content' `
        | ConvertFrom-Json | Select-Object -ExpandProperty 'Choices' `
            | Select-Object -ExpandProperty 'Text' | ForEach-Object { $_.Trim() }
}
