# WF-001: Zbývající varianty n8n workflow — Cursor prompt

## Kontext

Rozšiřujeme produkční n8n workflow knihovnu pro AI SME Integrátor.
Základní architektura (WF-001 logistika/spedice) je hotová a funkční.
Nyní vytváříme čtyři odvětvové varianty — každá je samostatný importovatelný `.json` soubor.

## Architektura je vždy stejná — NEměň ji

```
Webhook → Basic LLM Chain (+ OpenAI Chat Model sub-node) → Code Node (Validation Gate) → Switch
                                                                        ↓                    ↓
                                                               Google Sheets          Slack Alert
```

**Konstanty napříč všemi variantami:**
- Temperature: `0` na OpenAI Chat Model
- Webhook: HTTP Method `POST`, Respond: `Immediately`
- Code Node: JavaScript, `$input.item.json.text` nebo `$input.item.json.output` (fallback)
- Switch: `status === "success"` → Sheets, `status === "error"` → Slack
- Slack zpráva template: viz WF-001 logistika (stejná struktura, jen `errors` a `partialData`)

---

## Varianta A: WF-001-LEGAL — Advokacie a právní služby

**Soubor:** `workflows/WF-001_legal_variant.json`
**Webhook path:** `wf-001-legal`

### System Prompt pro LLM uzel:

```
You are an expert legal document data extraction parser operating in a strict automated pipeline.
Your task is to extract structured information from legal document text, contract clauses, or case descriptions.
You must return ONLY a valid JSON object. Do not include markdown formatting, explanations, or any other text.

Required JSON structure:
{
  "clause": "string or null",
  "risk_level": "low|medium|high|critical or null",
  "identified_issues": "string or null",
  "recommendation": "string or null",
  "includeMetadata": "boolean"
}

Extraction rules:
1. If a value is not explicitly mentioned, set it to null.
2. risk_level must be one of: low, medium, high, critical — infer from context if not stated.
3. identified_issues: summarize all legal risks found in one concise sentence.
4. recommendation: provide one concrete action step.
5. includeMetadata: set to true if the document contains dates, signatures, or parties.
```

### Validation Gate — requiredFields:

```javascript
const requiredFields = ['clause', 'risk_level', 'identified_issues'];
```

### Google Sheets mapování:

| Sloupec | Expression |
|---|---|
| Datum | `{{ $now.toISO() }}` |
| Klauzule | `{{ $json.data.clause }}` |
| Riziko | `{{ $json.data.risk_level }}` |
| Problémy | `{{ $json.data.identified_issues }}` |
| Doporučení | `{{ $json.data.recommendation }}` |
| Metadata | `{{ $json.data.includeMetadata }}` |

---

## Varianta B: WF-001-LOGISTICS — Spedice (rozšířená verze)

**Soubor:** `workflows/WF-001_logistics_extended.json`
**Webhook path:** `wf-001-logistics`

> Toto je rozšíření základního WF-001 — přidává pole pro datum nakládky, počet palet a poznámku.

### System Prompt pro LLM uzel:

```
You are an expert logistics data extraction parser operating in a strict automated pipeline.
Your task is to extract structured shipment information from unstructured emails or text messages.
You must return ONLY a valid JSON object. Do not include markdown formatting, explanations, or any other text.

Required JSON structure:
{
  "loadingCity": "string or null",
  "deliveryCity": "string or null",
  "cargoWeightKg": "number or null",
  "pallets": "number or null",
  "loadingDate": "string (ISO 8601 date) or null",
  "estimatedDistanceKm": "number or null",
  "isUrgent": "boolean",
  "note": "string or null"
}

Extraction rules:
1. If a value is not explicitly mentioned, set it to null.
2. Convert all weight units to kilograms automatically.
3. Convert all distance units to kilometers automatically.
4. loadingDate: always output as ISO 8601 (YYYY-MM-DD). Resolve relative dates (e.g. "tomorrow") using today's date.
5. isUrgent: set to true if text contains: ASAP, urgent, dnes, urgentně, ihned, co nejdříve.
6. note: include any special cargo requirements (fragile, temperature-controlled, hazmat).
```

### Validation Gate — requiredFields:

```javascript
const requiredFields = ['loadingCity', 'deliveryCity', 'cargoWeightKg'];
```

### Google Sheets mapování:

| Sloupec | Expression |
|---|---|
| Datum přijetí | `{{ $now.toISO() }}` |
| Odkud | `{{ $json.data.loadingCity }}` |
| Kam | `{{ $json.data.deliveryCity }}` |
| Váha (kg) | `{{ $json.data.cargoWeightKg }}` |
| Palety | `{{ $json.data.pallets }}` |
| Datum nakládky | `{{ $json.data.loadingDate }}` |
| Vzdálenost (km) | `{{ $json.data.estimatedDistanceKm }}` |
| Urgentní | `{{ $json.data.isUrgent }}` |
| Poznámka | `{{ $json.data.note }}` |

---

## Varianta C: WF-001-MANUFACTURING — Výroba a průmysl

**Soubor:** `workflows/WF-001_manufacturing_variant.json`
**Webhook path:** `wf-001-manufacturing`

> Zpracovává hlášení poruch, směnové reporty a incidenty ze záznamu (text nebo přepis audia přes Whisper).

### System Prompt pro LLM uzel:

```
You are an expert manufacturing incident data extraction parser operating in a strict automated pipeline.
Your task is to extract structured information from shift reports, fault descriptions, or maintenance requests.
You must return ONLY a valid JSON object. Do not include markdown formatting, explanations, or any other text.

Required JSON structure:
{
  "machineId": "string or null",
  "unitsProduced": "number or null",
  "unitsDefective": "number or null",
  "downtimeMinutes": "number or null",
  "asset_id": "string or null",
  "criticality": "low|medium|high|critical or null",
  "system_affected": "string or null",
  "action_required": "string or null"
}

Extraction rules:
1. If a value is not explicitly mentioned, set it to null.
2. machineId / asset_id: extract any machine identifier, serial number, or line designation.
3. criticality: infer from context — "critical" if production is halted, "high" if defect rate > 3%.
4. downtimeMinutes: convert hours to minutes if needed.
5. action_required: one concrete maintenance action in imperative form.
```

### Validation Gate — requiredFields:

```javascript
const requiredFields = ['machineId', 'criticality', 'action_required'];
```

### Google Sheets mapování:

| Sloupec | Expression |
|---|---|
| Datum | `{{ $now.toISO() }}` |
| Stroj ID | `{{ $json.data.machineId }}` |
| Vyrobeno ks | `{{ $json.data.unitsProduced }}` |
| Zmetky ks | `{{ $json.data.unitsDefective }}` |
| Prostoj (min) | `{{ $json.data.downtimeMinutes }}` |
| Závažnost | `{{ $json.data.criticality }}` |
| Systém | `{{ $json.data.system_affected }}` |
| Akce | `{{ $json.data.action_required }}` |

### Slack alert pro výrobu (urgentní eskalace):

Přidej druhý Switch výstup — pokud `criticality === "critical"`, odešli Slack zprávu s `@channel`:

```
🚨 *KRITICKÁ ZÁVADA — okamžitý zásah*
Stroj: {{ $json.data.machineId }}
Systém: {{ $json.data.system_affected }}
Akce: {{ $json.data.action_required }}
```

---

## Varianta D: WF-001-ACCOUNTING — Účetnictví a faktury

**Soubor:** `workflows/WF-001_accounting_variant.json`
**Webhook path:** `wf-001-accounting`

> Zpracovává příchozí PDF faktury přes Vision AI (GPT-4o s image inputem) nebo textový přepis OCR.

### System Prompt pro LLM uzel:

```
You are an expert invoice data extraction parser operating in a strict automated pipeline.
Your task is to extract structured financial information from invoice text or OCR output.
You must return ONLY a valid JSON object. Do not include markdown formatting, explanations, or any other text.

Required JSON structure:
{
  "supplier": "string or null",
  "vat_id": "string or null",
  "iban": "string or null",
  "var_symbol": "string or null",
  "net_amount": "number or null",
  "vat_amount": "number or null",
  "total_amount": "number or null",
  "due_date": "string (ISO 8601 date) or null",
  "validation_status": "ok|missing_fields|suspicious or null"
}

Extraction rules:
1. If a value is not explicitly mentioned, set it to null.
2. vat_id: extract Czech IČO or DIČ (format CZ + 8-10 digits).
3. iban: extract full IBAN if present, otherwise null.
4. All amounts: output as numbers without currency symbols.
5. due_date: always ISO 8601 (YYYY-MM-DD).
6. validation_status: set to "suspicious" if total_amount differs from net_amount + vat_amount by more than 1 CZK.
```

### Validation Gate — requiredFields:

```javascript
const requiredFields = ['supplier', 'net_amount', 'total_amount', 'due_date'];
```

### Google Sheets mapování:

| Sloupec | Expression |
|---|---|
| Datum přijetí | `{{ $now.toISO() }}` |
| Dodavatel | `{{ $json.data.supplier }}` |
| DIČ | `{{ $json.data.vat_id }}` |
| IBAN | `{{ $json.data.iban }}` |
| VS | `{{ $json.data.var_symbol }}` |
| Bez DPH (Kč) | `{{ $json.data.net_amount }}` |
| DPH (Kč) | `{{ $json.data.vat_amount }}` |
| Celkem (Kč) | `{{ $json.data.total_amount }}` |
| Splatnost | `{{ $json.data.due_date }}` |
| Status | `{{ $json.data.validation_status }}` |

### Speciální větev pro "suspicious":

Přidej třetí Switch výstup — pokud `validation_status === "suspicious"`, zastav workflow a odešli alert účetní:

```
⚠️ *Faktura s nesouhlasícími částkami*
Dodavatel: {{ $json.data.supplier }}
Rozdíl: {{ $json.data.net_amount + $json.data.vat_amount - $json.data.total_amount }} Kč
→ Zkontrolujte před zaúčtováním.
```

---

## Sdílený Validation Gate kód (stejný pro všechny varianty)

Zkopíruj přesně, změň jen `requiredFields`:

```javascript
// WF-001 Validation Gate — universal
// Change requiredFields per variant

const rawOutput = $input.item.json.text ?? $input.item.json.output;
let extractedData;
let isValid = true;
let errorMessages = [];

try {
  extractedData = typeof rawOutput === 'string'
    ? JSON.parse(rawOutput)
    : rawOutput;
} catch (error) {
  return [{
    json: {
      status: "error",
      errors: ["Failed to parse LLM output as JSON"],
      rawData: rawOutput
    }
  }];
}

// ⬇️ ZMĚŇ TOTO pro každou variantu
const requiredFields = ['field1', 'field2', 'field3'];

for (const field of requiredFields) {
  if (
    !extractedData.hasOwnProperty(field) ||
    extractedData[field] === null ||
    extractedData[field] === ""
  ) {
    isValid = false;
    errorMessages.push(`Missing critical field: ${field}`);
  }
}

if (isValid) {
  return [{ json: { status: "success", data: extractedData } }];
} else {
  return [{ json: { status: "error", errors: errorMessages, partialData: extractedData } }];
}
```

---

## Test curl příkazy pro každou variantu

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
```

---

## Pořadí implementace (doporučené)

1. **WF-001-LOGISTICS** — nejbližší k hotovému WF-001, minimální změny
2. **WF-001-ACCOUNTING** — nejvyšší ROI pro klienty, ale složitější Switch
3. **WF-001-MANUFACTURING** — specifický pro průmysl, přidej audio trigger (Whisper) jako bonus
4. **WF-001-LEGAL** — nejkomplexnější, RAG vrstva přijde v WF-002

## Co NEDĚLAT

- ❌ Nesdílej credentials mezi workflow — každý má vlastní Google Sheets connection
- ❌ Neměň strukturu Validation Gate — jen `requiredFields` pole
- ❌ Nepřidávej pole do `requiredFields` pokud nejsou vždy přítomná v datech — způsobí falešné errory
- ❌ Nepoužívej `temperature > 0` — způsobí nestabilní JSON výstup
