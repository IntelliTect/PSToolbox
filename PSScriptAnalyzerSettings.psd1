@{
    # Severity of records to emit.
    Severity = @('Error', 'Warning')

    # PSGallery rule profile is a reasonable baseline. Anything not explicitly
    # excluded below will be enforced.
    IncludeDefaultRules = $true

    ExcludeRules = @(
        # Many cmdlets in this repo legitimately use Write-Host for interactive
        # output (e.g. coloured terminal feedback in Highlight, Invoke-GitCommand).
        'PSAvoidUsingWriteHost',
        # PSToolbox exports a curated set of aliases (HL, Edit, Using, Open) that
        # have been part of the public surface for years.
        'PSAvoidUsingCmdletAliases'
    )
}
