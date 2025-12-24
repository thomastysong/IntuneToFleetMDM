function Send-ITFSlackNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SlackWebhook,

        [Parameter(Mandatory)]
        [ValidateSet('Started','Success','Failure','PreflightFailed')]
        [string]$Type,

        [Parameter(Mandatory)]
        [psobject]$Context,

        [Parameter()]
        [string]$FailureReason
    )

    try {
        $url = Resolve-ITFSlackWebhookUrl -SlackWebhook $SlackWebhook
        if (-not $url) { return $false }

        $payloadObj = New-ITFSlackPayload -Type $Type -Context $Context -FailureReason $FailureReason
        $json = $payloadObj | ConvertTo-Json -Depth 10

        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

        Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body $json -ErrorAction Stop | Out-Null
        Write-ITFMDMLog -Level Info -EventId 3001 -Message 'Slack notification sent' -Data @{ type = $Type }
        return $true
    }
    catch {
        # Best-effort only; never fail the migration because Slack is down/misconfigured.
        $err = $null
        try { $err = $_.Exception.Message } catch { }
        Write-ITFMDMLog -Level Warn -EventId 3002 -Message 'Slack notification failed (best-effort)' -Data @{ type = $Type; error = $err }
        return $false
    }
}


