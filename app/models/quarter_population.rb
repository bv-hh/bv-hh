# frozen_string_literal: true

# Residents per Stadtteil, so a map can shade Stadtteile by Drucksachen per
# resident rather than by raw count, which mostly follows size.
#
# Statistikamt Nord, "Hamburger Stadtteil-Profile", Berichtsjahr 2025,
# population on 31 December 2025:
# https://www.statistik-nord.de/fileadmin/Dokumente/Stadtteilprofile2026.xlsx
# (listed on https://www.statistik-nord.de/stadtteilprofile).
#
# Four pairs of thinly populated Stadtteile are counted together there and
# share one figure here (AREAS). Neuwerk has none.
class QuarterPopulation
  AS_OF = Date.new(2025, 12, 31)

  # In the source's order, by Bezirk.
  RESIDENTS = {
    'Hamburg-Altstadt' => 2_567,
    'HafenCity' => 9_308,
    'Neustadt' => 12_725,
    'St. Pauli' => 22_028,
    'St. Georg' => 12_557,
    'Hammerbrook' => 7_107,
    'Borgfelde' => 8_901,
    'Hamm' => 39_210,
    'Horn' => 39_393,
    'Billstedt' => 73_206,
    'Billbrook' => 1_805,
    'Rothenburgsort' => 11_304,
    'Veddel' => 4_437,
    'Wilhelmsburg' => 53_767,
    'Kleiner Grasbrook und Steinwerder' => 1_069,
    'Waltershof und Finkenwerder' => 11_441,
    'Altona-Altstadt' => 29_623,
    'Sternschanze' => 7_767,
    'Altona-Nord' => 26_824,
    'Ottensen' => 36_780,
    'Bahrenfeld' => 31_473,
    'Groß Flottbek' => 11_330,
    'Othmarschen' => 16_624,
    'Lurup' => 38_237,
    'Osdorf' => 26_811,
    'Nienstedten' => 7_145,
    'Blankenese' => 13_448,
    'Iserbrook' => 11_480,
    'Sülldorf' => 9_259,
    'Rissen' => 16_431,
    'Eimsbüttel' => 57_607,
    'Rotherbaum' => 17_155,
    'Harvestehude' => 17_652,
    'Hoheluft-West' => 13_753,
    'Lokstedt' => 31_901,
    'Niendorf' => 42_082,
    'Schnelsen' => 31_670,
    'Eidelstedt' => 37_230,
    'Stellingen' => 29_376,
    'Hoheluft-Ost' => 9_868,
    'Eppendorf' => 25_067,
    'Groß Borstel' => 10_848,
    'Alsterdorf' => 15_688,
    'Winterhude' => 61_200,
    'Uhlenhorst' => 19_271,
    'Hohenfelde' => 10_135,
    'Barmbek-Süd' => 37_145,
    'Dulsberg' => 17_321,
    'Barmbek-Nord' => 44_669,
    'Ohlsdorf' => 17_667,
    'Fuhlsbüttel' => 14_014,
    'Langenhorn' => 49_260,
    'Eilbek' => 22_849,
    'Wandsbek' => 38_706,
    'Marienthal' => 13_846,
    'Jenfeld' => 29_754,
    'Tonndorf' => 15_734,
    'Farmsen-Berne' => 38_651,
    'Bramfeld' => 53_952,
    'Steilshoop' => 19_842,
    'Wellingsbüttel' => 11_185,
    'Sasel' => 24_457,
    'Poppenbüttel' => 24_644,
    'Hummelsbüttel' => 18_680,
    'Lemsahl-Mellingstedt' => 7_043,
    'Duvenstedt' => 5_911,
    'Wohldorf-Ohlstedt' => 4_779,
    'Bergstedt' => 10_798,
    'Volksdorf' => 20_508,
    'Rahlstedt' => 95_688,
    'Lohbrügge' => 41_711,
    'Bergedorf' => 37_392,
    'Curslack' => 4_207,
    'Altengamme' => 2_339,
    'Neuengamme' => 3_734,
    'Kirchwerder' => 10_458,
    'Ochsenwerder' => 3_053,
    'Reitbrook' => 497,
    'Allermöhe' => 1_380,
    'Billwerder' => 4_174,
    'Moorfleet' => 1_232,
    'Tatenberg' => 545,
    'Spadenland' => 543,
    'Neuallermöhe' => 23_169,
    'Harburg' => 29_217,
    'Neuland und Gut Moor' => 1_880,
    'Wilstorf' => 18_168,
    'Rönneburg' => 3_289,
    'Langenbek' => 4_104,
    'Sinstorf' => 4_357,
    'Marmstorf' => 9_519,
    'Eißendorf' => 25_741,
    'Heimfeld' => 23_219,
    'Moorburg und Altenwerder' => 696,
    'Hausbruch' => 16_943,
    'Neugraben-Fischbek' => 35_512,
    'Francop' => 738,
    'Neuenfelde' => 5_453,
    'Cranz' => 857,
  }.freeze

  # The combined entries above, and the Stadtteile they stand for.
  AREAS = {
    'Kleiner Grasbrook und Steinwerder' => ['Kleiner Grasbrook', 'Steinwerder'],
    'Waltershof und Finkenwerder' => %w[Waltershof Finkenwerder],
    'Neuland und Gut Moor' => ['Neuland', 'Gut Moor'],
    'Moorburg und Altenwerder' => %w[Moorburg Altenwerder],
  }.freeze

  class << self
    # The Stadtteile counted together with +name+ (itself included) and their
    # residents, or nil where there is no figure.
    def area(name)
      label, quarters = AREAS.find { |_label, members| members.include?(name) }
      label ? [quarters, RESIDENTS.fetch(label)] : ([[name], RESIDENTS[name]] if RESIDENTS.key?(name))
    end
  end
end
