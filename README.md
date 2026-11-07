![Build Status](https://github.com/bv-hh/bv-hh/workflows/CI/badge.svg)

# BV-HH

https://bv-hh.de

Eine unabhängige, quelloffene Weboberfläche für den Sitzungsdienst (das
Ratsinformationssystem ALLRIS) der sieben Hamburger Bezirksversammlungen. BV-HH
ist kein offizielles Angebot der Stadt Hamburg. Es begann als Hobby-Projekt
eines Mitglieds der Bezirksversammlung Hamburg-Nord; die Hintergründe stehen auf
[bv-hh.de/about](https://bv-hh.de/about).

## Für wen?

**Menschen, die in und für die Bezirke arbeiten:** Mitglieder der
Bezirksversammlungen und Ausschüsse, ihre Mitarbeitenden und die Bezirksämter.
Für sie soll der Zugang zu den Informationen schnell gehen, auch auf dem Handy
in einer Sitzung: einfache Navigation, eine Suche über alle sieben Bezirke
("Wurde das schon in einem anderen Bezirk beantragt?"), neue Drucksachen und die
nächsten Tagesordnungen auf einen Blick.

**Bürgerinnen und Bürger,** die nicht wissen, was in ihrem Bezirk passiert, und
oft nicht einmal, dass es Bezirkspolitik und Bezirksversammlungen gibt. Sie
wollen wissen, was in ihrer Nachbarschaft los ist. Für sie geht BV-HH von Orten
und Themen aus statt von Ausschüssen und Drucksachen-Nummern: Was wird in meinem
Stadtteil, in meiner Straße beraten und entschieden? Welche Sitzungen sind
öffentlich, und wie kann ich mitreden?

## Was BV-HH bietet

- Drucksachen, Sitzungen und Tagesordnungen aller sieben Bezirke, aufbereitet
  für Handy und Desktop
- Volltextsuche über alle Bezirke, auch in Anhängen und Protokollen
- Orte in den Texten: Straßen, Stadtteile und bekannte Orte werden erkannt und
  auf Karten und Stadtteilseiten gezeigt
- Themen: jede Drucksache wird automatisch einem oder mehreren von 20 Themen
  zugeordnet
- Statistiken je Bezirk und für ganz Hamburg
- RSS-Feeds für eine Straße, einen Stadtteil oder ein Thema
- Erklärseiten zur Bezirkspolitik und zur Beteiligung
- Ein [MCP-Server](https://bv-hh.de/mcp) für LLM-Werkzeuge

Es gibt nur öffentlich zugängliche Daten. Nicht-öffentliche Sitzungen und
Unterlagen für Mandatsträgerinnen und Mandatsträger bleiben im offiziellen
System. ALLRIS wird zurückhaltend abgefragt, neue Daten erscheinen daher mit
etwas Verzögerung.

## Lokale Installation

Nötig sind:

- Ruby (Version in `.ruby-version`)
- PostgreSQL mit der Erweiterung `pgvector`
- Node.js und Yarn
- Für die Systemtests: Chrome

Die Datenbank lässt sich mit Docker starten (`docker compose up db`, legt
Benutzer und Datenbank `bezirkr` / `bezirkr_dev` an). Danach:

```bash
bundle install
yarn install
bin/rails db:create db:schema:load
```

## Daten

**Bezirke anlegen:** `bin/rails db:seed` legt die sieben Bezirke an (siehe
`db/seeds.rb`). `oldest_allris_document_id` und `oldest_allris_meeting_date`
geben an, wie weit zurück Daten aus ALLRIS geholt werden. Zum lokalen Entwickeln
reicht ein Monat zurück völlig; die Werte in `seeds.rb` reichen bis 2019, damit
dauert die erste Synchronisierung sehr lange.

**Geo-Register importieren:** Orte werden in den Texten über lokale Register
gefunden: Straßen, Stadtteile und OpenStreetMap-Orte. Diese müssen einmal
importiert werden:

```bash
rake quarters:import   # Stadtteile         (~2 s)
rake streets:import    # Straßen            (~40 s)
rake pois:import       # OpenStreetMap-Orte (~10 min)
```

**Erste Synchronisierung**, in der Rails-Konsole:

```ruby
CheckForDocumentUpdatesJob.perform_now(District.first)
CheckForMeetingUpdatesJob.perform_now(District.first)
```

Danach startet `bin/rails server` die Anwendung wie gewohnt.

## Entwickeln

```bash
bin/rails test           # Unit- und Controller-Tests
bin/rails test:system    # Systemtests (Chrome)
bundle exec rubocop      # Linter
```

Architektur, Hintergrundjobs, Datenbesonderheiten und Konventionen für die
Oberfläche stehen in [AGENTS.md](AGENTS.md). Die Datei richtet sich an
Coding-Agents, ist aber auch für Menschen die beste Einführung in den Code.

## Beitragen

Pull-Requests sind ausdrücklich erwünscht! Anmerkungen, Ideen und
Fehlermeldungen gern als Issue oder an
[timo@bv-hh.de](mailto:timo@bv-hh.de).

## Daten und Quellen

- Drucksachen, Sitzungen und Tagesordnungen: Sitzungsdienste der Hamburger
  Bezirksämter
- Straßen, Bezirks- und Stadtteilgrenzen: Freie und Hansestadt Hamburg,
  Landesbetrieb Geoinformation und Vermessung (LGV), Datenlizenz Deutschland –
  Namensnennung 2.0
- Orte und Kartenkacheln: © OpenStreetMap-Mitwirkende, ODbL 1.0
- Einwohnerzahlen: Statistikamt Nord, Hamburger Stadtteil-Profile

Die vollständigen Angaben stehen im [Impressum](https://bv-hh.de/imprint).

## Lizenz

MIT, siehe [LICENSE](LICENSE)
