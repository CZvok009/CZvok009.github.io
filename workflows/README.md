# WF-001: Inteligentní extraktor nestrukturovaných dat

Produkční n8n workflow knihovna pro AI SME Integrátor. Každá varianta je samostatný importovatelný JSON soubor se stejnou architekturou.

## Architektura (všechny varianty)

```
Webhook → Basic LLM Chain (+ OpenAI Chat Model) → Validation Gate → Switch
                                                          ↓              ↓
                                                 Google Sheets    Slack Alert
```

**Konstanty:** Temperature `0`, Webhook `POST` + respond immediately, Validation Gate s `$input.item.json.text ?? $input.item.json.output`.

## Soubory

| Soubor | Webhook path | Obor |
|---|---|---|
| `WF-001_intelligent_extractor.json` | `wf-001-extract` | Základní logistika |
| `WF-001_logistics_extended.json` | `wf-001-logistics` | Spedice (rozšířená) |
| `WF-001_ecommerce_variant.json` | `wf-001-ecommerce` | E-commerce |
| `WF-001_legal_variant.json` | `wf-001-legal` | Advokacie / právo |
| `WF-001_manufacturing_variant.json` | `wf-001-manufacturing` | Výroba (+ kritická eskalace) |
| `WF-001_accounting_variant.json` | `wf-001-accounting` | Účetnictví (+ suspicious větev) |

## Speciální větve

**Manufacturing:** Po validaci → `Route by Criticality`. Pokud `criticality === "critical"`, odešle `<!channel>` Slack alert a zároveň zapíše do Sheets.

**Accounting:** Po validaci → `Route by Validation Status`. Pokud `validation_status === "suspicious"`, workflow nezapisuje do Sheets a odešle alert účetní.

## Import do n8n

1. Spusťte n8n (`start_all.bat` nebo `npx n8n start`)
2. **⋯ → Import from File** → vyberte JSON
3. Nakonfigurujte credentials (OpenAI, Google Sheets, Slack) — každý workflow má vlastní
4. Vyberte cílový Google Sheet a Slack kanál
5. Aktivujte workflow

## Test curl (webhook-test = editor preview, webhook = produkce)

```bash
# Legal
curl -X POST http://localhost:5678/webhook-test/wf-001-legal \
  -H "Content-Type: application/json" \
  -d '{"body":{"text":"Smlouva o dílo, článek 5.3 — dodavatel není povinen nahradit škodu vzniklou vyšší mocí. Chybí definice vyšší moci."}}'

# Logistics (rozšířená)
curl -X POST http://localhost:5678/webhook-test/wf-001-logistics \
  -H "Content-Type: application/json" \
  -d '{"body":{"text":"Potřebujeme převézt 8 palet elektroniky z Prahy do Vídně. Váha cca 2200 kg, nakládka zítra ráno, křehké zboží!"}}'

# Manufacturing
curl -X POST http://localhost:5678/webhook-test/wf-001-manufacturing \
  -H "Content-Type: application/json" \
  -d '{"body":{"text":"Stroj L-04 hlásí poruchu hydraulického čerpadla. Prostoj 45 minut, vyrobeno 320 ks, zmetky 28 ks. Nutná okamžitá výměna těsnění."}}'

# Accounting
curl -X POST http://localhost:5678/webhook-test/wf-001-accounting \
  -H "Content-Type: application/json" \
  -d '{"body":{"text":"Faktura č. 2026-0891, dodavatel: Novák s.r.o., DIČ CZ12345678, IBAN CZ6508000000192000145399, VS 20260891, základ 15000 Kč, DPH 3150 Kč, celkem 18150 Kč, splatnost 15.7.2026"}}'

# Základní / E-commerce
curl -X POST http://localhost:5678/webhook-test/wf-001-extract \
  -H "Content-Type: application/json" \
  -d '{"body":{"text":"Dobrý den, potřebujeme odvézt 3 palety z Brna do Hamburku. Celková váha je cca 1450 kg."}}'
```

## Pravidla

- **Temperature = 0** — deterministická extrakce
- **Validation Gate** — měnit jen `requiredFields`, ne strukturu
- **`$input.item`** — ne `$input.all()`
- Každý workflow má vlastní Google Sheets credentials
- System Prompt neměnit bez testu na min. 10 vzorcích

## Rozšíření polí

1. Přidejte pole do JSON struktury v System Promptu (LLM Extract)
2. Přidejte do `requiredFields` v Code Node (jen povinná pole)
3. Přidejte mapování do Google Sheets uzlu
