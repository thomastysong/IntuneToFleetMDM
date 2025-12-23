function New-ITFProgrammaticEnrollmentToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OrbitNodeKey
    )

    # Matches the payload format used by our validated script:
    # { "type": 1, "payload": { "orbit_node_key": "<nodekey>" } }
    $accessTokenObj = @{
        type    = 1
        payload = @{
            orbit_node_key = $OrbitNodeKey
        }
    }

    return ($accessTokenObj | ConvertTo-Json -Compress -Depth 4)
}


