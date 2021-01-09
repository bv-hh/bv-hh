# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
#

District.create! name: "Hamburg-Nord", allris_base_url: "https://sitzungsdienst-hamburg-nord.hamburg.de",
  oldest_allris_document_id: 1007791, oldest_allris_meeting_date: "2019-01-01"

District.create! name: "Wandsbek", allris_base_url: "https://sitzungsdienst-wandsbek.hamburg.de",
  oldest_allris_document_id: 1010480, oldest_allris_meeting_date: "2019-01-01"

District.create! name: "Altona", allris_base_url: "https://sitzungsdienst-altona.hamburg.de",
  oldest_allris_document_id: 1008906, oldest_allris_meeting_date: "2019-01-01"

District.create! name: "Hamburg-Mitte", allris_base_url: "https://sitzungsdienst-hamburg-mitte.hamburg.de",
  oldest_allris_document_id: 1011795, oldest_allris_meeting_date: "2019-01-01"

District.create! name: "Eimsbüttel", allris_base_url: "https://sitzungsdienst-eimsbüttel.hamburg.de",
  oldest_allris_document_id: 1004634, oldest_allris_meeting_date: "2019-01-01"

District.create! name: "Harburg", allris_base_url: "https://sitzungsdienst-harburg.hamburg.de",
  oldest_allris_document_id: 1006690, oldest_allris_meeting_date: "2019-01-01"

District.create! name: "Bergedorf", allris_base_url: "https://sitzungsdienst-bergedorf.hamburg.de",
  oldest_allris_document_id: 1004374, oldest_allris_meeting_date: "2019-01-01"

