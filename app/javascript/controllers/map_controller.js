import { Controller } from "@hotwired/stimulus"

import "leaflet"
import "leaflet.markercluster"

// Connects to data-controller="map"
export default class extends Controller {
  static targets = ['container', 'month']

  connect(){
    this.createMap()

    let center = [this.data.get('lat'), this.data.get('lng')]
    this.map.setView(center, this.data.get('zoom'))

    this.showLocations(3)
  }

  createMap() {
    this.map = L.map(this.containerTarget)
    this.markers = L.markerClusterGroup()
    this.map.addLayer(this.markers)

    let tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(this.map)
  }

  showLocations(months) {
    months = parseInt(months)

    this.markers.clearLayers()

    let url = `${this.data.get('markers')}?months=${months}`

    fetch(url, { headers: { "Content-Type": "application/json; charset=utf-8" }})
      .then(res => res.json())
      .then(response => {
        for (var loc of response) {
          let marker = L.marker(loc.position)
          marker.bindPopup(this.popupContent(loc))
          this.markers.addLayer(marker)
        }
      })

    this.monthTargets.forEach(month => {
      if (parseInt(month.dataset.months) == months) {
        month.classList.add('btn-secondary')
        month.classList.remove('btn-outline-secondary')
      } else {
        month.classList.add('btn-outline-secondary')
        month.classList.remove('btn-secondary')
      }
    })
  }

  load(event) {
    this.showLocations(event.target.dataset.months)
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
