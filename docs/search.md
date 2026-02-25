# Public Search

Users can search ANCODEs from Home ("Cerca o Crea") without logging in. Search is resolved by normalized code.

## Resolution Rules
1. **Unique match**: Single active/scheduled code → redirect to URL or show note
2. **Multiple (Comune-bound)**: Non-exclusive codes in different Comuni → user selects Comune, then resolve
3. **Exclusive ITALIA first**: If an exclusive (Italia-wide) code exists for that normalized code, it appears first and wins
4. **Not found**: Show "codice non trovato" + suggest similar codes (basic prefix match)
5. **GRACE codes**: Never appear in public search; reserved for owner during 30-day grace

## Implementation
- `AncodeService.search(input)` normalizes input, strips asterisk, queries `ancodes` (status != grace)
- Results ordered: exclusive first, then Comune-bound
- Search history recorded for logged-in users (deduped in UI)
