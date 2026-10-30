import { Controller } from "@hotwired/stimulus"

import "leaflet"
import "leaflet.markercluster"

// The map leading a Quarter's page. Draws the Quarter boundary and pins the
// locations of the documents on the current page, so the map and the list
// always agree. Where the title card floats on the map, the map keeps the
// area under it free.
//
// Separate from map_controller because that one is built around the whole-city
// view: a month toolbar, a fixed centre and zoom, and no boundary.
export default class extends Controller {
  static targets = ["container", "empty", "card"]
  static values = { url: String }

  connect() {
    this.createMap()
    this.load()
  }

  disconnect() {
    this.map?.remove()
  }

  createMap() {
    // Zoom buttons on the right: the title card covers the top left.
    this.map = L.map(this.containerTarget, { scrollWheelZoom: false, zoomControl: false })
    L.control.zoom({ position: "topright" }).addTo(this.map)
    this.markers = L.markerClusterGroup()
    this.map.addLayer(this.markers)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map)
  }

  async load() {
    const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
    if (!response.ok) return

    const data = await response.json()

    this.drawBoundary(data.boundary)
    this.drawMarkers(data.markers)
    this.fit(data)
  }

  // GeoJSON is [polygon][ring][point][lng, lat]; Leaflet wants [lat, lng].
  drawBoundary(polygons) {
    if (!polygons) return

    const rings = polygons.map((polygon) => polygon.map((ring) => ring.map(([lng, lat]) => [lat, lng])))

    L.polygon(rings, { color: "#0d6efd", weight: 2, fillOpacity: 0.06, interactive: false }).addTo(this.map)
  }

  drawMarkers(markers) {
    for (const marker of markers) {
      L.marker(marker.position).bindPopup(this.popupContent(marker)).addTo(this.markers)
    }

    this.emptyTarget.classList.toggle("d-none", markers.length > 0)
  }

  // Prefer the markers' own extent, but fall back to the Quarter's bounding
  // box when nothing has been geocoded here yet.
  fit(data) {
    const bounds = this.markers.getBounds()

    if (bounds.isValid()) {
      this.map.fitBounds(bounds, { ...this.padding(30), maxZoom: 15 })
    } else {
      this.map.fitBounds(data.bounds, this.padding(10))
    }
  }

  // Extra room on the left while the card floats on the map (from lg up).
  padding(base) {
    const card = this.hasCardTarget ? this.cardTarget : null
    const floating = card && getComputedStyle(card).position === "absolute"
    const left = floating ? card.offsetLeft + card.offsetWidth + base : base

    return { paddingTopLeft: [left, base], paddingBottomRight: [base, base] }
  }

  popupContent(marker) {
    const documents = marker.documents
      .map((doc) => `<li><a href="${doc.path}">${doc.number}</a> ${doc.title}</li>`)
      .join("")

    return `
      <h6>${marker.name}</h6>
      <p class="mb-1 small text-secondary">${marker.address ?? ""}</p>
      <ul class="ps-3 mb-1">${documents}</ul>
      <a href="${marker.path}">Alles an diesem Ort</a>
    `
  }
}
