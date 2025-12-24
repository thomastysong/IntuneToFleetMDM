function New-ITFSlackPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Started','Success','Failure')]
        [string]$Type,

        [Parameter(Mandatory)]
        [psobject]$Context,

        [Parameter()]
        [string]$FailureReason
    )

    $targetUrlMrkdwn = $null
    if ($Context.DiscoveryUrl) {
        $targetUrlMrkdwn = ('<{0}|{0}>' -f $Context.DiscoveryUrl)
    }

    $baseFields = @(
        @{ type = 'mrkdwn'; text = ("*Username*`n{0}" -f $Context.Username) },
        @{ type = 'mrkdwn'; text = ("*Serial Number*`n{0}" -f $Context.SerialNumber) },
        @{ type = 'mrkdwn'; text = ("*Device Model*`n{0}" -f $Context.DeviceModel) },
        @{ type = 'mrkdwn'; text = ("*OS Version (Build)*`n{0}" -f $Context.OSVersionBuild) },
        @{ type = 'mrkdwn'; text = ("*Target MDM URL*`n{0}" -f $targetUrlMrkdwn) },
        @{ type = 'mrkdwn'; text = ("*Migration UUID*`n{0}" -f $Context.CorrelationId) }
    )

    $payload = $null
    switch ($Type) {
        'Failure' {
            $payload = @{
                text = 'MDM Migration Failed'
                attachments = @(
                    @{
                        color = '#E01E5A'
                        blocks = @(
                            @{
                                type = 'header'
                                text = @{
                                    type = 'plain_text'
                                    text = ':x: MDM Migration Failed :fleet:'
                                    emoji = $true
                                }
                            }
                            @{
                                type = 'section'
                                text = @{
                                    type = 'mrkdwn'
                                    text = '*Enrollment did not complete.* We’ll retry automatically and post an update when it succeeds.'
                                }
                            }
                            @{ type = 'divider' }
                            @{
                                type = 'section'
                                fields = $baseFields
                            }
                            @{
                                type = 'section'
                                fields = @(
                                    @{ type = 'mrkdwn'; text = ("*Failure Reason*`n{0}" -f $FailureReason) }
                                )
                            }
                            @{
                                type = 'context'
                                elements = @(
                                    @{ type = 'mrkdwn'; text = 'MDM Migration Orchestrator' }
                                )
                            }
                        )
                    }
                )
            }
        }

        'Success' {
            $completedAt = (Get-Date).ToString('ddd MMM dd HH:mm:ss K yyyy')
            $payload = @{
                text = 'MDM Migration Completed Successfully'
                attachments = @(
                    @{
                        color = '#2EB67D'
                        blocks = @(
                            @{
                                type = 'header'
                                text = @{
                                    type = 'plain_text'
                                    text = ':white_check_mark: MDM Migration Completed Successfully :nvidia-verified: :fleet:'
                                    emoji = $true
                                }
                            }
                            @{
                                type = 'section'
                                text = @{
                                    type = 'mrkdwn'
                                    text = 'Device successfully enrolled to Fleet MDM'
                                }
                            }
                            @{ type = 'divider' }
                            @{
                                type = 'section'
                                fields = $baseFields
                            }
                            @{
                                type = 'section'
                                fields = @(
                                    @{ type = 'mrkdwn'; text = ("*Completed At*`n{0}" -f $completedAt) }
                                )
                            }
                            @{
                                type = 'context'
                                elements = @(
                                    @{ type = 'mrkdwn'; text = 'MDM Migration Orchestrator' }
                                )
                            }
                        )
                    }
                )
            }
        }

        'Started' {
            $payload = @{
                text = 'MDM Migration Started - Unenrollment Complete'
                attachments = @(
                    @{
                        color = '#ECB22E'
                        blocks = @(
                            @{
                                type = 'header'
                                text = @{
                                    type = 'plain_text'
                                    text = ':warning: MDM Migration Started - Unenrollment Complete :fleet:'
                                    emoji = $true
                                }
                            }
                            @{
                                type = 'section'
                                text = @{
                                    type = 'mrkdwn'
                                    text = 'Device has been unenrolled from legacy MDM and is beginning Fleet enrollment'
                                }
                            }
                            @{ type = 'divider' }
                            @{
                                type = 'section'
                                fields = $baseFields
                            }
                            @{
                                type = 'context'
                                elements = @(
                                    @{ type = 'mrkdwn'; text = 'MDM Migration Orchestrator' }
                                )
                            }
                        )
                    }
                )
            }
        }
    }

    return $payload
}


