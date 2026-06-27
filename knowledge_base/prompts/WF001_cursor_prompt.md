# WF-001: Inteligentní extraktor nestrukturovaných dat — n8n modul

## Kontext projektu

Vytváříme produkční n8n workflow knihovnu pro AI SME Integrátor. Tento modul (WF-001) je první a nejuniverzálnější — řeší extrakci strukturovaných dat z příchozích e-mailů nebo textových zpráv. Nasazuje se na klientovu vlastní n8n instanci (on-premise / VPS). Žádná data neopouštějí klientovu infrastrukturu.

## Cíl

Vybudovat robustní n8n workflow, které:
1. Přijme nestrukturovaný text (e-mail, formulář, webhook)
2. Extrahuje klíčová data přes LLM (Claude / GPT-4o)
3. Zvaliduje výstup — zabrání průchodu defektních dat do ERP
4. Routuje: validní data → Google Sheets / ERP, nevalidní → Slack notifikace

---

## Architektura (4 uzly v řadě)

```
[Webhook / Email Trigger]
        ↓
[LLM Node — extrakce do JSON]
        ↓
[Code Node — validační brána]
        ↓
[Switch Node]
    ↓           ↓
[Google Sheets] [Slack/Email alert]
```

---

## Uzel 1: Trigger

- Typ: `n8n-nodes-base.webhook` nebo `n8n-nodes-base.emailReadImap`
- Výstup: surový text e-mailu v poli `body.text` nebo `body.html`

---

## Uzel 2: LLM Node (AI Agent)

- Typ: `@n8n/n8n-nodes-langchain.openAi` nebo `lmChatAnthropic`
- **Temperature: `0`** — maximální determinismus, žádná kreativita
- Model: `gpt-4o` nebo `claude-sonnet-4-6`

### System Prompt (zkopíruj přesně):

```
You are an expert data extraction parser operating in a strict automated pipeline.
Your task is to extract structured information from the provided unstructured user text.
You must return ONLY a valid JSON object. Do not include markdown formatting, explanations, or any other text.

Required JSON structure:
{
  "originCity": "string or null",
  "destinationCity": "string or null",
  "weightKg": "number or null",
  "isUrgent": "boolean"
}

Extraction rules:
1. If a specific value is not explicitly mentioned in the text, you must set its value to null.
2. Convert all weight units to kilograms (Kg) automatically.
3. If the text contains words implying fast processing (e.g., ASAP, urgent, dnes, urgentně), set "isUrgent" to true.
```

- User message (expression): `{{ $json.body.text }}`

---

## Uzel 3: Code Node — Validační brána

- Typ: `n8n-nodes-base.code`
- Jazyk: JavaScript

```javascript
// WF-001 Validation Gate
// Validates LLM JSON output before passing to ERP/Database
// Returns status: "success" | "error"

const rawOutput = $input.item.json.text;
let extractedData;
let isValid = true;
let errorMessages = [];

// Parse LLM output — LLM může vrátit string nebo objekt
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

// Pole, která MUSÍ být vyplněna pro průchod do ERP
const requiredFields = ['originCity', 'destinationCity', 'weightKg'];

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
  return [{
    json: {
      status: "success",
      data: extractedData
    }
  }];
} else {
  return [{
    json: {
      status: "error",
      errors: errorMessages,
      partialData: extractedData
    }
  }];
}
```

---

## Uzel 4: Switch Node

- Typ: `n8n-nodes-base.switch`
- Podmínka 1: `{{ $json.status }}` === `"success"` → větev **ERP / Google Sheets**
- Podmínka 2: `{{ $json.status }}` === `"error"` → větev **Slack / E-mail alert**

### Slack alert zpráva (expression):

```
⚠️ *WF-001: Neúplná poptávka*

Byla přijata poptávka, ale chybí kritická data:
{{ $json.errors.join('\n• ') }}

Částečná data:
{{ JSON.stringify($json.partialData, null, 2) }}

👉 Zkontrolujte prosím ručně a doplňte.
```

---

## Google Sheets uzel (success větev)

Mapování polí (expressions):

| Sloupec v sheetu | n8n expression |
|---|---|
| Datum přijetí | `{{ $now.toISO() }}` |
| Odkud | `{{ $json.data.originCity }}` |
| Kam | `{{ $json.data.destinationCity }}` |
| Váha (kg) | `{{ $json.data.weightKg }}` |
| Urgentní | `{{ $json.data.isUrgent }}` |
| Status | `Nová poptávka` |

---

## Pravidla pro rozšíření (pokud chceš přidat pole)

1. Přidej pole do JSON struktury v System Promptu LLM uzlu
2. Přidej název pole do pole `requiredFields` v Code Nodu (jen pokud je povinné)
3. Přidej mapování do Google Sheets uzlu

## Adaptace pro e-commerce (místo spedice)

Nahraď JSON strukturu v System Promptu:

```json
{
  "customerName": "string or null",
  "productSku": "string or null",
  "quantity": "number or null",
  "deliveryAddress": "string or null",
  "isUrgent": "boolean"
}
```

A `requiredFields` v Code Nodu: `['customerName', 'productSku', 'quantity']`

---

## Co NEDĚLAT

- ❌ Neměň Temperature LLM nad `0` — způsobí nedeterministické výstupy
- ❌ Neodstraňuj Code Node validaci — bez ní budou prázdná pole procházet do ERP
- ❌ Nepoužívej `$input.all()` místo `$input.item` — vrátí array, ne single item
- ❌ Neupravuj System Prompt za provozu bez testování na min. 10 vzorcích

