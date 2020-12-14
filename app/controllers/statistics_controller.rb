class StatisticsController < ApplicationController

  def show
    @proposals = [{
      name: 'CDU',
      color: '#222',
      data: {
        "Anträge" => @district.documents.proposals('CDU').count,
      }
    }, {
      name: 'SPD',
      color: '#dc3545',
      data: {
        "Anträge" => @district.documents.proposals('SPD').count,
      }
    }, {
      name: 'Grüne',
      color: '#28a745',
      data: {
        "Anträge" => @district.documents.proposals('Grüne').count,
      }
    }, {
      name: 'FDP',
      color: '#ffc107',
      data: {
        "Anträge" => @district.documents.proposals('FDP').count,
      }
    }, {
      name: 'Linke',
      color: '#c535dc',
      data: {
        "Anträge" => @district.documents.proposals('Linke').count,
      }
    }, {
      name: 'AfD',
      color: '#17a2b8',
      data: {
        "Anträge" => @district.documents.proposals('AfD').count,
      }
     }]
  end
end
