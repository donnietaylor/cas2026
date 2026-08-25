# INC-88240 - Expired certificate on api.contoso.com
Severity: 1
Opened: 2026-08-16

TLS certificate expired at 03:00 UTC. All API clients failed.
Nobody was watching the expiry date; the renewal reminder went to a mailbox
belonging to someone who left in March.

## Resolution
Reissued via Key Vault and enabled auto-rotation.

## Follow-up
Add certificate expiry to the monitoring pipeline. This is the third time.
