# AskUserQuestion Patterns for Low Confidence

Use only when `confidence: low` after heuristics.

## General Pattern (per file)
```
For {ClassName} methods, test level is unclear.
Signals: {summary of DB/external/side_effects/loc/zone}.
Choose default:
1) unit — faster, more stubs/mocks
2) integration — real DB, external HTTP stubbed
3) request — full endpoint (if controller)
```
Apply the chosen option to all low-confidence methods in the file; record in `decision_trace`.

## Per-Method Variant
Use if one method is ambiguous and others are clear.
```
Method {MethodName} has mixed signals ({loc} LOC, deps: {deps}, side_effects: {effects}).
Pick level:
1) unit (stub DB/HTTP)
2) integration (real DB, HTTP stubbed)
```
If user responds with custom instruction, store it in `decision_trace` and `confidence: high`.
