![Build Status](https://github.com/bv-hh/bv-hh/workflows/CI/badge.svg)

# BV-HH

https://bv-hh.de

Eine alternative Weboberfläche für den Sitzungsdienst (Parlamentsdatenbank) der Hamburger Bezirksversammlungen.

## Lokale Installation

Um BV-HH lokal zu installieren und daran zu entwickeln, sind diese Dinge nötig:

- Ruby
- PostgreSQL
- NodeJS
- Redis

## NER Modell herunterladen

Für die Analyze der Texte mittels NLP wird ein neuronales Netz verwendet.
Das nötige Modell muss hier heruntergeladen werden:

https://github.com/mit-nlp/MITIE/releases/download/v0.4/MITIE-models-v0.2-German.tar.bz2

Die ausgepackte Datei muss im Verzeichnis `data` verfügbar sein.

## Beitragen

Nach der lokalen Installation muss mindestens ein Bezirk angelegt werden. Siehe hierzu `seeds.rb`. Die Attribute `oldest_allris_document_id`
und `oldest_allris_meeting_date` geben an, wie weit zurück in die Vergangenheit Daten von Allris synchronisiert werden sollen. Zum lokalen
Entwickeln ist ein Monat zurück locker ausreichend (dauert sonst sehr lange).

Sobald ein Bezirk angelegt wurde, einmal auf der Rails Console dies ausführen: `CheckForDocumentUpdatesJob.perform_now(District.first)` bzw.
`CheckForMeetingUpdatesJob.perform_now(District.first)`. Damit sollten ausreichend Testdaten synchronisiert werden.

Danach kann die lokale Umgebung ganz normal per `rails s` gestartet werden.

Pull-Requests sind ausdrücklich erwünscht!

## Lizenz

MIT, siehe LICENSE
