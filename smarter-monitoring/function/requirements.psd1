@{
    # Keep this list short. Every module here is downloaded and loaded on cold
    # start, and 'Az' (the meta-module) adds tens of seconds. We call Azure REST
    # endpoints directly with a managed-identity token instead - see
    # Get-AzureAccessToken in AiEnrichment.psm1.
    'Az.Accounts' = '3.*'
}
