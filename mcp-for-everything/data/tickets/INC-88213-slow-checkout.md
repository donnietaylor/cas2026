# INC-88213 - Checkout latency spike
Severity: 2
Opened: 2026-08-14

Customer reports checkout taking 30+ seconds during the afternoon peak.
Traced to connection pool exhaustion on sql-prod-03 after the 8/13 deploy.

## Resolution
Raised max pool size from 100 to 250 and added a connection leak check to
the order service. Latency back to ~400ms.

## Follow-up
The leak was in OrderRepository.GetPendingAsync - the reader was never
disposed on the exception path.
