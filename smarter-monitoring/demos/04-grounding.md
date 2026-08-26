# Demo 4 — Grounding: facts before judgment

**Code:** [`powershell/modules/Grounding.psm1`](../powershell/modules/Grounding.psm1)

## The setup

Show the room what the model would otherwise see — five alert titles — and ask them
to diagnose the outage from that.

They can't. Neither can a model. The difference is that a model will produce a
confident, fluent, well-structured paragraph anyway, and that is worse than silence
because someone will act on it.

## Three sources

| Function | Answers |
|---|---|
| `Get-ResourceFacts` | What are these resources, who owns them, what environment? (Resource Graph, one query for the whole batch) |
| `Get-RecentDeployment` | What changed in the last four hours? |
| `Get-CorrelatedSignal` | What does the telemetry actually say? (Log Analytics KQL) |

## If you add only one, add deployments

The honest base rate for "why did production break" is **"somebody deployed
something."** A model that can see a deploy landed fourteen minutes before the first
alert finds the real answer far more often than one that cannot.

In the recorded scenario that deploy is right there in `groundingContext`:

```
checkout-api 2026.8.24.3, deployed 13:47
"Order repository refactor; connection disposal moved to finally block"
```

First alert fires at 14:00. The model does not have to be clever to connect those —
it has to be *told*.

## The framing to use

> The alert tells you a threshold was crossed. The logs tell you what was happening.
> Those are different questions, and the second one is the one your on-call engineer
> would go and look at. So look at it for them — and hand the model the answer
> instead of the threshold.

## Failure behaviour

Every lookup is individually wrapped. If Resource Graph is slow or the workspace is
unreachable, you get a warning and a thinner context object — not a dead batch.
Grounding is an enhancement, and an enhancement that can take down the pipeline is a
liability.

Requires `Reader` on the subscription and `Log Analytics Reader` on the workspace.
Both read-only, both least-privilege. See [azure-setup.md](../docs/azure-setup.md).
