# Create / Register Code

Users create ANCODEs with type (Link or Note), Comune, and Terms acceptance. Multi-create in one session supported.

## Fields
- **Code**: Max 30 chars, uppercase + digits only; real-time validation; availability check
- **Type**: Link (URL) or Nota (text)
- **Comune**: Mandatory; autocomplete over Italian municipalities; "All/Italia" not selectable
- **Terms**: Must be checked

## Output
- Shortlink: `https://<domain>/c/<code>` (domain configurable)
- QR code: generated via qr_flutter; download/share
- PDF export: placeholder layout
- Test link button

## Plan Limits
- FREE: 5 codes, 30-day expiry, not editable, not exclusive
- PRO/BUSINESS: Configurable via `plan_config`; editable; exclusive slots
