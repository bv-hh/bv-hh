import { Controller } from "@hotwired/stimulus"

import "leaflet"

// Connects to data-controller="map"
export default class extends Controller {
  static targets = ["container"]

  connect(){
    this.createMap()

    let center = [this.data.get('lat'), this.data.get('lng')];
    this.map.setView(center, this.data.get('zoom'));

    this.showLocations()
  }

  createMap() {
    this.map = L.map(this.containerTarget)

    var tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(this.map);
  }

  showLocations() {
    fetch(this.data.get('markers'), { headers: { "Content-Type": "application/json; charset=utf-8" }})
      .then(res => res.json())
      .then(response => {
        for (var marker of response) {
          L.marker(marker.position).addTo(this.map).bindPopup(this.popupContent(marker))
        }
      })
  }

  popupContent(marker) {
    let documentList = marker.documents.map(doc => `<li><a href="${doc.path}">${doc.number}</a> ${doc.title}</li>`).join('')
    return `
      <h5>${marker.name}</h5>
      <p>${marker.address}</p>
      <ul>${documentList}</ul>
    `
  }

  disconnect(){
    this.map.remove()
  }
}
