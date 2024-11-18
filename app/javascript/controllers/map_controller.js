import { Controller } from "@hotwired/stimulus"

import "leaflet"
import "leaflet-css"

// Connects to data-controller="map"
export default class extends Controller {
  connect(){
    let center = [this.data.get('lat'), this.data.get('lng')];
    var map = L.map('map').setView(center, this.data.get('zoom'));

    var tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(map);

    fetch(this.data.get('markers'), { headers: { "Content-Type": "application/json; charset=utf-8" }})
      .then(res => res.json())
      .then(response => {
        for (var marker of response) {
          L.marker(marker.position).addTo(map).bindPopup(marker.text)
        }
      })
  }

  disconnect(){
    this.map.remove()
  }
}
