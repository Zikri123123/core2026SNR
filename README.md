# core2026SNR Account Lock (GitHub)

Senarai akaun MT4 dibenarkan untuk EA `core2026SNR.mq4`.

## Fail penting

| Fail | Fungsi |
|---|---|
| `licenses.json` | Senarai akaun MT4 dibenarkan |
| `ea/MzcoreLicenseLock.mqh` | Include lock untuk EA |

## Raw URL (untuk EA)

```text
https://raw.githubusercontent.com/Zikri123123/core2026SNR-lock/main/licenses.json
```

## Setup MT4

1. Copy `ea/MzcoreLicenseLock.mqh` ke folder `MQL4/Experts/` (sama folder dengan EA).
2. Compile semula `core2026SNR.mq4`.
3. MT4 → `Tools → Options → Expert Advisors → Allow WebRequest`
4. Tambah:

```text
https://raw.githubusercontent.com
```

## Urus akaun

Edit `licenses.json` dalam GitHub — tambah/buang nombor akaun MT4, commit & push.

Contoh:

```json
{
  "licenses": [
    {
      "account": 11111111,
      "owner": "Nama trader",
      "active": true,
      "expires": ""
    }
  ]
}
```

- `active: false` = block akaun
- `expires: "2026-12-31"` = tamat tempoh (kosong = tiada expiry)
