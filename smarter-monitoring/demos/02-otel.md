# Demo 2 — OpenTelemetry and the trace ID

**Code:** [`otel-demo/app.py`](../otel-demo/app.py) ·
[`otel-demo/collector-config.yaml`](../otel-demo/collector-config.yaml) ·
`ConvertFrom-OtelSpan` in [`EventNormalizer.psm1`](../powershell/modules/EventNormalizer.psm1)

## Why OTel is in this session

Not for vendor neutrality — that is real but it is not the point here.

**A span carries a trace ID**, and a trace ID turns *"these alerts might be related"*
into *"these alerts are provably the same request."* That is not a heuristic you tune.
It is a join key.

## Run it

```powershell
cd otel-demo
pip install -r requirements.txt
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = "<from the portal>"
python app.py --scenario checkout-failure
```

Emits five healthy traces, then one failing trace with three spans:

```
POST /checkout                     ERROR  upstream timeout calling payments
└── payments.authorize             ERROR  connection reset
    └── orders.db.insert           ERROR  timeout expired; pool exhausted
```

All three share one trace ID. The real failure is at the bottom of the stack; the
alert you would have been paged for is at the top.

> `app.py` sleeps for six seconds before exiting. `BatchSpanProcessor` ships spans
> asynchronously — exit immediately and they never leave the process, which looks
> exactly like a broken demo.

## Both paths

Someone in the room is not on Application Insights. Cover both:

| Path | How |
|---|---|
| Azure Monitor OpenTelemetry Distro → App Insights | `configure_azure_monitor()` in `app.py` |
| OTel Collector → Event Hubs | `collector-config.yaml` |

Same spans, same trace IDs, different plumbing. *That* is the neutrality argument
earning its keep.

Note the collector config filters to error spans only (`filter/errors-only`). Shipping
every span into Event Hubs is expensive and pointless — this pipeline correlates
incidents, not traffic.

## Watch for

`ConvertFrom-OtelSpan` accepts both `2` and `STATUS_CODE_ERROR` for the status code,
because the OTLP JSON encoding uses either depending on who produced it.
