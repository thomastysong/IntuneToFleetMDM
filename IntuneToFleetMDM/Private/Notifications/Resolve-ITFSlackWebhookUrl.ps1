function Resolve-ITFSlackWebhookUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SlackWebhook
    )

    $w = $SlackWebhook.Trim()
    if (-not $w) { return $null }

    # Accept full URL or path-only. Normalize to full URL.
    if ($w -match '^(?i)https?://') {
        return $w
    }

    # Allow inputs like:
    # - hooks.slack.com/services/T.../B.../W...
    # - /services/T.../B.../W...
    # - services/T.../B.../W...
    # - T.../B.../W...
    $w = $w.TrimStart('/')
    if ($w -match '^(?i)hooks\.slack\.com/services/') {
        return ('https://{0}' -f $w)
    }

    if ($w -match '^(?i)services/') {
        return ('https://hooks.slack.com/{0}' -f $w)
    }

    return ('https://hooks.slack.com/services/{0}' -f $w)
}


