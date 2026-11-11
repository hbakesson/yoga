# Yoga

En Apple TV-app som visar veckans yogaklasser hos Hot Yoga Stockholm. Formspråket är inspirerat av [hotyogasthlm.se](https://www.hotyogasthlm.se/): studions salvia, oliv och guld, flyttade in i en varm kvällspalett som passar ett mörkt vardagsrum.

## Funktioner

- **Startskärm:** en gyllene sol stiger medan schemat läses in och glider sedan upp i sidhuvudet när veckan tonas fram.
- **Veckoschema:** hela veckan på en skärm, sju kolumner. Dagens kolumn markeras i guld, avslutade pass tonas ned, pågående pass pulserar och nästa pass glöder och får fokus direkt. Sidhuvudet visar veckonummer, klocka och vad som är nästa pass.
- **Jämna och udda veckor:** studion växlar vissa pass mellan jämna och udda veckor. Appen räknar ut ISO-veckan och visar rätt pass. Du kan växla mellan *Denna vecka* och *Nästa vecka*.
- **Klassdetalj:** välj ett pass för att se en helskärmsvy med ett klot i klassens färg, beskrivning, längd, sal, klimat, nivå och bokningsregler. När du stänger vyn hamnar fokus på passet du öppnade, så du tappar inte din plats i veckan.

## Data

Schemat parsas när appen startar:

1. `Yoga/Resources/schedule.json` innehåller studions säsongsschema (Höst 2026), transkriberat från studions [PDF-översikt](https://www.hotyogasthlm.se/wp-content/uploads/2026/06/Hot-Yoga-Stockholm-Host-2026-A4.pdf). `ScheduleParser` validerar filen och lägger ut den på riktiga datum för tre veckor framåt.
2. **Live (valfritt):** studions aktuella schema finns bara i Mindbody, som kräver en API-nyckel. Lägg en `Yoga/Resources/Mindbody.plist` med nycklarna `ApiKey` och `SiteId` (`28625`), så hämtar appen från Mindbody Public API v6. Om hämtningen misslyckas visas säsongsschemat med en diskret notis. Filen är git-ignorerad.

### Byta säsong

När säsongen byts uppdaterar du `schedule.json`: `season`, `source`, och vid behov `rooms` och `classTypes`. Varje pass i `sessions` ser ut så här:

```json
{ "day": "tor", "start": "16.00", "minutes": 60, "classes": ["HH"], "weeks": "even" }
```

- `day`: `mån`, `tis`, `ons`, `tor`, `fre`, `lör` eller `sön`
- `classes`: en eller flera koder från `classTypes`
- valfritt: `level`, `room` (id från `rooms`), `note` och `weeks` (`even` eller `odd`; utelämna för varje vecka)

Okända dagar, tider, klasskoder eller salar ger ett tydligt felmeddelande i appen.

## Bygga

Öppna `Yoga.xcodeproj` i Xcode 26 eller senare och kör på en Apple TV-simulator eller enhet (tvOS 18+, Swift 6). Projektet är inställt på ett eget utvecklarteam för kodsignering. För att köra på en egen enhet väljer du ditt team under *Signing & Capabilities* och vid behov ett eget bundle-id (`se.hbakesson.yoga`).

## Struktur

```
Yoga/
  App/        appens ingång
  Data/       ScheduleParser, ScheduleStore, MindbodySource
  Design/     Theme (färger, typsnitt, rörelse) och Atmosphere (bakgrund, klot)
  Model/      Schedule, Session, ClassType
  Views/      RootView (start), WeekScheduleView, SessionDetailView
  Resources/  schedule.json och Assets.xcassets
tools/        render-artwork.swift
```

## Grafik

App-ikonen (tre parallax-lager), Top Shelf-bilderna och klotet ritas i kod och skrivs direkt till `Assets.xcassets`:

```sh
swift tools/render-artwork.swift
```
