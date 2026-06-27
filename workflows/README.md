# WF-001: Inteligentní extraktor nestrukturovaných dat

Produkční n8n workflow modul pro AI SME Integrátor. Extrahuje strukturovaná data z e-mailů nebo textových zpráv, validuje je a routuje do Google Sheets nebo Slack alertu.

## Soubory

| Soubor | Účel |
|---|---|
| `WF-001_intelligent_extractor.json` | Výchozí varianta — spedice / logistika |
| `WF-001_ecommerce_variant.json` | E-commerce varianta (objednávky) |

## Architektura

```
[Webhook / Email Trigger]
        ↓
[LLM Extract + OpenAI Chat Model]
        ↓
[Validation Gate — Code Node]
        ↓
[Route by Status — Switch]
    ↓           ↓
[Google Sheets] [Slack Alert]
```

## Import do n8n

1. Spusťte lokální n8n (`start_all.bat` nebo `npx n8n start`)
2. V editoru: **⋯ → Import from File**
3. Vyberte příslušný JSON soubor
4. Nakonfigurujte credentials:
   - **OpenAI account** — API klíč
   - **Google Sheets account** — OAuth2
   - **Slack account** — Bot token
5. V uzlech Google Sheets a Slack vyberte cílový dokument / kanál
6. Aktivujte workflow

## Testování (Webhook)

```bash
curl -X POST http://localhost:5678/webhook/wf-001-extract \
  -H "Content-Type: application/json" \
  -d "{\"body\":{\"text\":\"Dobrý den, potřebujeme odvézt 3 palety z Brna do Hamburku. Celková váha je cca 1450 kg. Prosím o rychlou kalkulaci.\"}}"
```

Očekávaný výsledek: řádek v Google Sheets s `originCity=Brno`, `destinationCity=Hamburg`, `weightKg=1450`.

## E-mail trigger (produkce)

Nahraďte uzel **Webhook Trigger** uzlem **Email Trigger (IMAP)**. Výstup zůstane v `$json.body.text` — žádná úprava LLM uzlu není potřeba.

## Pravidla (nesmí se porušit)

- **Temperature = 0** — deterministická extrakce
- **Code Node validace** — bez ní projdou prázdná pole do ERP
- **`$input.item`** v Code Node — ne `$input.all()`
- System Prompt neměnit bez testu na min. 10 vzorcích

## Rozšíření polí

1. Přidejte pole do JSON struktury v System Promptu (LLM Extract)
2. Přidejte do `requiredFields` v Code Node (jen povinná pole)
3. Přidejte mapování do Google Sheets uzlu
