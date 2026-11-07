import { Controller } from "@hotwired/stimulus"

import "leaflet"

// Leaflet sets tooltip content as HTML.
const escape = (text) => text.replace(/[&<>"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[char])

// A district's Stadtteile shaded by Drucksachen per resident (QuarterChoropleth
// gives the features, colours included). Hovering names a Stadtteil and its
// figures, clicking opens its page. A Stadtteil wide enough on screen carries
// its name as a label; the rest show it on hover only.
//
// The table next to the map holds the same figures for keyboards and screen
// readers, which cannot reach the shapes.
export default class extends Controller {
  static targets = ["container"]
  // bounds is the district's own box: Hamburg-Mitte includes Neuwerk, an
  // island 100 km out in the North Sea, and fitting every shape would show
  // the district as a speck. Neuwerk stays in the table.
  static values = { features: Array, bounds: Array }

  // Room a label needs, in pixels: roughly its text at 12px semibold. The
  // circle around the label point may be a little narrower than the name,
  // which can run on into the wider parts of the Stadtteil.
  static CHAR_WIDTH = 7.5
  static LABEL_FIT = 0.6
  static LABEL_HEIGHT = 20

  connect() {
    this.map = L.map(this.containerTarget, { scrollWheelZoom: false, zoomSnap: 0.25 })

    // Faint, so the shades carry the map and the streets only orient.
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      opacity: 0.35,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map)

    this.shapes = L.featureGroup().addTo(this.map)
    this.labels = L.layerGroup().addTo(this.map)
    this.polygons = this.featuresValue.map((feature) => this.drawFeature(feature))

    if (this.polygons.length === 0) return

    const bounds = this.boundsValue.length ? this.boundsValue : this.shapes.getBounds()
    this.map.fitBounds(bounds, { padding: [8, 8] })
    this.map.on("zoomend", () => this.drawLabels())
    this.drawLabels()
  }

  disconnect() {
    this.map?.remove()
  }

  drawFeature(feature) {
    const style = { color: "#fff", weight: 1.5, fillColor: feature.color, fillOpacity: 0.85 }
    const polygon = L.polygon(this.latLngs(feature.polygons), style).addTo(this.shapes)

    polygon.bindTooltip(this.tooltip(feature), { sticky: true })
    polygon.on("mouseover", () => polygon.setStyle({ color: "#212529", weight: 3 }).bringToFront())
    polygon.on("mouseout", () => polygon.setStyle(style))
    polygon.on("click", () => Turbo.visit(feature.path))

    return { feature, polygon }
  }

  // GeoJSON is [polygon][ring][point][lng, lat]; Leaflet wants [lat, lng].
  latLngs(polygons) {
    return polygons.map((polygon) => polygon.map((ring) => ring.map(([lng, lat]) => [lat, lng])))
  }

  tooltip(feature) {
    // Two Stadtteile counted together are named together.
    const area = feature.area === feature.name ? escape(feature.name) : `${escape(feature.area)} <small>(zusammen gezählt)</small>`
    const rate = feature.rate === null ? "zu wenige Menschen wohnen hier für einen Vergleich" : `${feature.rate} je 10.000 Menschen, die hier wohnen`

    return `<strong>${area}</strong><br>${feature.count.toLocaleString("de-DE")} Drucksachen<br>${rate}`
  }

  // A label goes on the point farthest from the Stadtteil's edges (label is
  // [lng, lat, radius] from Quarter#label_point), if the circle that fits
  // there is wide enough for most of the name.
  drawLabels() {
    this.labels.clearLayers()

    for (const { feature } of this.polygons) {
      const [lng, lat, radius] = feature.label
      const centre = this.map.latLngToContainerPoint([lat, lng])
      const edge = this.map.latLngToContainerPoint([lat + radius, lng])
      const diameter = 2 * Math.abs(centre.y - edge.y)
      const width = (feature.name.length + 2) * this.constructor.CHAR_WIDTH
      if (diameter < width * this.constructor.LABEL_FIT || diameter < this.constructor.LABEL_HEIGHT) continue

      const className = `quarter-choropleth-label${feature.light_text ? " text-white" : ""}`
      L.tooltip({ permanent: true, direction: "center", className, interactive: false })
        .setLatLng([lat, lng])
        .setContent(escape(feature.name))
        .addTo(this.labels)
    }
  }
}
