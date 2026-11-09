# Yoga

En Apple TV-app som visar veckans yogaklasser hos Hot Yoga Stockholm. Formspråket är inspirerat av [hotyogasthlm.se](https://www.hotyogasthlm.se/): studions salvia, oliv och guld, flyttade in i en varm kvällspalett som passar ett mörkt vardagsrum.

## Funktioner

- **Veckoschema:** hela veckan på en skärm, sju kolumner. Dagens kolumn markeras i guld, avslutade pass tonas ned, och nästa pass glöder och får fokus direkt.
- **Jämna och udda veckor:** studion växlar vissa pass mellan jämna och udda veckor. Appen räknar ut ISO-veckan och visar rätt pass. Du kan växla mellan *Denna vecka* och *Nästa vecka*.
- **Klassdetalj:** välj ett pass för att se en helskärmsvy med ett klot i klassens färg, beskrivning, längd, sal, klimat, nivå och bokningsregler.

## Data

Schemat parsas när appen startar:

1. `Yoga/Resources/schedule.json` innehåller studions säsongsschema (Höst 2026), transkriberat från studions [PDF-översikt](https://www.hotyogasthlm.se/wp-content/uploads/2026/06/Hot-Yoga-Stockholm-Host-2026-A4.pdf). `ScheduleParser` validerar filen och lägger ut den på riktiga datum för tre veckor framåt.
2. **Live (valfritt):** studions aktuella schema finns bara i Mindbody, som kräver en API-nyckel. Lägg en `Yoga/Resources/Mindbody.plist` med nycklarna `ApiKey` och `SiteId` (`28625`), så hämtar appen från Mindbody Public API v6. Om hämtningen misslyckas visas säsongsschemat. Filen är git-ignorerad.

När säsongen byts uppdaterar du `schedule.json`.

## Bygga

Öppna `Yoga.xcodeproj` i Xcode 26 eller senare och kör på en Apple TV-simulator eller enhet (tvOS 18+).

## Grafik

App-ikonen (tre parallax-lager), Top Shelf-bilderna och klotet ritas i kod:

```sh
swift tools/render-artwork.swift
```
