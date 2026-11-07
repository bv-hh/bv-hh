import { Controller } from "@hotwired/stimulus"

import { tileLayer, latLngs, OUTLINE, POPUP, pinIcon, clusterGroup } from "lib/map_support"

// The map leading a Quarter's page. Draws the Quarter boundary and pins the
// locations of the documents on the current page, so the map and the list
// always agree. Where the title card floats on the map, the map keeps the
// area under it free.
//
// Separate from map_controller, which counts and pins a whole range of
// Drucksachen with a list following the view. The pins and popups look the
// same (lib/map_support); the popups come rendered from the server, the same
// partial as there.
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
    tileLayer({ opacity: 0.7 }).addTo(this.map)

    this.markers = clusterGroup()
    this.map.addLayer(this.markers)
  }

  async load() {
    const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
    if (!response.ok) return

    const data = await response.json()

    this.drawBoundary(data.boundary)
    this.drawMarkers(data.markers)
    this.fit(data)
  }

  drawBoundary(polygons) {
    if (!polygons) return

    L.polygon(latLngs(polygons), OUTLINE).addTo(this.map)
  }

  drawMarkers(markers) {
    for (const marker of markers) {
      L.marker(marker.position, { icon: pinIcon(marker.count), title: marker.name })
        .bindPopup(marker.popup, POPUP)
        .addTo(this.markers)
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
}
