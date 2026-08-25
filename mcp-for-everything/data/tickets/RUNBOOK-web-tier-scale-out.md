# Runbook: Scaling the web tier

When HTTP 5xx rate exceeds 5% AND web tier CPU is above 85%:

1. Confirm the load balancer health probe is passing on at least 2 nodes.
2. Scale the VMSS to +2 instances.
3. Wait 4 minutes for warm-up before evaluating.
4. If 5xx persists after scale-out, suspect the database, not the web tier.

Do NOT restart the web tier during business hours; in-flight carts are lost.
