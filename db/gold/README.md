# Topic gold set

`topics.jsonl` is a fixed sample of documents with checked topics. `rake
topics:evaluate` measures the rules against it (see `TopicEvaluation`), and so
will the classifier of phase 2. Each line identifies a document by district and
number, which mean the same in every environment.

## Workflow

```bash
rake topics:gold_sample                         # once: draw the sample (refuses to replace it)
rake topics:gold_texts                          # unlabelled documents as markdown batches in tmp/gold
rake "topics:gold_import[labels.txt,claude]"    # labels back into topics.jsonl
rake topics:evaluate                            # precision and recall per topic
rake "topics:evaluate[verbose]"                 # plus every wrong (+) and missing (-) tag
```

A labels file has one line per document, `-` for no topic:

```
hamburg-nord/22-1234: radverkehr, strassenverkehr
altona/21-0567: -
```

`labeler` is `claude` or `human`. An import never replaces a label by a human,
so to correct a label, edit its line in `topics.jsonl` and set `"labeler":
"human"`.

## How to label

The texts are shown without what the rules made of them, so the label does not
lean on them.

- A topic applies when the request, question or decision of the document is
  about it. A place or subject mentioned in passing does not count.
- Assign every topic that applies. Usually one or two, sometimes none.
- Judge by the content, not by the committee it went to.
- The topics and what each covers are in `config/topics.yml` (`label`,
  `description`). Money for a project counts as Sondermittel & Haushalt and
  as the project's own topic.
- Only the start of long texts is shown. If it is not enough to decide, label
  what the title and the shown text support.

## Conventions used so far

The first labelling (all 324 documents, `"labeler": "claude"`) settled these
boundary cases. Change them only together with the labels they affect.

- **Sondermittel & Haushalt** is money the district decides on or reports:
  Sondermittel, Quartiersfonds, Zuwendungen, Rahmenzuweisungen, Haushalt. A
  request to a state authority to find funding for something is not.
- **Soziales & Gesundheit** includes Barrierefreiheit wherever it is part of the
  request, also for bus stops, pavements and toilets.
- **Kultur & Erinnerung** includes Straßen(um)benennungen, Denkmalschutz and
  Gedenken; **Schule & Bildung** includes libraries only where learning is the
  point (a women's library: both).
- A **Spielplatz** includes Bolzplätze and play areas in parks.
- Appointments to a Beirat or committee are **Gremien & Verwaltung**, plus the
  Beirat's subject when the document discusses it.
- Safety near a school or Kita (Tempo 30, crossings, Elterntaxis) is
  **Straßenverkehr**, not Schule or Kinder.
- A pure listing without content ("Beschlüsse des Hauptausschusses") gets no
  topic.
