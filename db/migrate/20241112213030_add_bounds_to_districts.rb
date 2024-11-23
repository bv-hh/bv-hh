class AddBoundsToDistricts < ActiveRecord::Migration[7.2]

  LOCATIONS = {
    "Hamburg-Mitte" => {
      ne_lat: 53.5671511, ne_lng: 10.1694834,
      sw_lat: 53.4538019, sw_lng: 9.77806809,
    },
    "Altona" => {
      ne_lat: 53.6275269, ne_lng: 9.97726709,
      sw_lat: 53.541252, sw_lng: 9.73176180,
    },
    "Eimsbüttel" => {
      ne_lat: 53.653394, ne_lng: 10.0068389,
      sw_lat: 53.557676, sw_lng: 9.871931,
    },
    "Hamburg-Nord" => {
      ne_lat: 53.6819221, ne_lng: 10.089918,
      sw_lat: 53.556154, sw_lng: 9.9588098,
    },
    "Wandsbek" => {
      ne_lat: 53.5991653, ne_lng: 10.104319,
      sw_lat: 53.5684361, sw_lng: 10.0583829,
    },
    "Bergedorf" => {
      ne_lat: 53.4979679, ne_lng: 10.2692351,
      sw_lat: 53.466171, sw_lng: 10.1613167,
    },
    "Harburg" => {
      ne_lat: 53.5455129, ne_lng: 10.0531509,
      sw_lat: 53.4139399, sw_lng: 9.76353679,
    },
  }

  def change
    reversible do |dir|
      dir.up do
        LOCATIONS.each do |name, bounds|
          district = District.find_by(name: name)
          district.update!(bounds)
        end
      end
    end
  end
end
