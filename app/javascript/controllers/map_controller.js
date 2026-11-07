import { Controller } from "@hotwired/stimulus"

import { escape, tileLayer, latLngs, OUTLINE, POPUP, pinIcon, clusterGroup, bubbleIcon, lazyPopup } from "lib/map_support"

// The map page (MapsController). Zoomed out, a bubble per Bezirk (city map
// only) or Stadtteil counts the Drucksachen naming a place there; zoomed in,
// the places themselves are pins, red while one of their Drucksachen is still
// to be discussed. A pin's popup is fetched when it opens.
//
// Beside the map, a turbo frame lists the Drucksachen in view. The view is
// kept in the address (#zoom/lat/lng) and the filters in the query, so a map
// can be shared as it is.
export default class extends Controller {
  static targets = ["container", "form", "list", "coverage"]
  static values = {
    bounds: Array,
    city: Boolean,
    areasUrl: String,
    markersUrl: String,
    documentsUrl: String,
    placeUrl: String,
    feedUrl: String,
    maxPlaces: { type: Number, default: 20 },
  }

  // Below these zooms the city map counts per Bezirk, and any map per Stadtteil.
  static DISTRICT_ZOOM = 12
  static PIN_ZOOM = 13

  connect() {
    // Aborts what is still loading when the page is left.
    this.aborter = new AbortController()
    this.markersRequest = 0

    this.map = L.map(this.containerTarget, { scrollWheelZoom: false, zoomSnap: 0.5 })
    tileLayer({ opacity: 0.7 }).addTo(this.map)

    // The wheel zooms once the map has been clicked, not while scrolling past.
    this.map.on("click focus", () => this.map.scrollWheelZoom.enable())
    this.map.on("blur mouseout", () => this.map.scrollWheelZoom.disable())

    this.outlines = L.featureGroup().addTo(this.map)
    this.quarterOutlines = L.featureGroup()
    this.bubbles = L.layerGroup().addTo(this.map)
    this.pins = clusterGroup({ chunkedLoading: true })
    this.highlight = L.layerGroup().addTo(this.map)

    this.restoreView()

    this.map.on("zoomend", () => this.drawLevel())
    this.map.on("moveend", () => {
      this.storeView()
      this.scheduleList()
    })

    this.areas = { districts: [], quarters: [] }
    this.markerData = null
    this.loadAreas()
    this.loadMarkers()
    this.loadList()
  }

  disconnect() {
    this.aborter.abort()
    clearTimeout(this.listTimeout)
    this.map?.remove()
  }

  // A filter changed: reload what depends on it, keep the view.
  filter(event) {
    if (!["zeitraum", "thema"].includes(event.target.name)) return

    const url = new URL(window.location.href)
    for (const [key, value] of Object.entries(this.filters())) {
      value ? url.searchParams.set(key, value) : url.searchParams.delete(key)
    }
    history.replaceState(history.state, "", url)

    this.loadMarkers()
    this.loadList()
  }

  filters() {
    const form = new FormData(this.formTarget)
    return { zeitraum: form.get("zeitraum") || "", thema: form.get("thema") || "" }
  }

  withFilters(base, extra = {}) {
    const url = new URL(base, window.location.origin)
    for (const [key, value] of Object.entries({ ...this.filters(), ...extra })) {
      if (value) url.searchParams.set(key, value)
    }
    return url.toString()
  }

  // The view from the address, or the district's or city's box. Without a box,
  // Hamburg until the outlines are loaded (loadAreas).
  restoreView() {
    const [zoom, lat, lng] = window.location.hash.slice(1).split("/").map(Number)

    if ([zoom, lat, lng].every(Number.isFinite) && zoom > 0) {
      this.map.setView([lat, lng], zoom)
    } else if (this.boundsValue.length === 2) {
      this.map.fitBounds(this.boundsValue, { padding: [8, 8] })
    } else {
      this.map.setView([53.5511, 9.9937], 10)
      this.fitOutlines = true
    }
  }

  storeView() {
    const center = this.map.getCenter()
    const hash = `#${this.map.getZoom()}/${center.lat.toFixed(4)}/${center.lng.toFixed(4)}`
    history.replaceState(history.state, "", hash)
  }

  // JSON from the server, or null when it fails or the page was left meanwhile.
  async fetchJSON(url) {
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: this.aborter.signal })
      return response.ok ? await response.json() : null
    } catch (error) {
      if (error.name === "AbortError") return null
      throw error
    }
  }

  async loadAreas() {
    const areas = await this.fetchJSON(this.areasUrlValue)
    if (!areas) return

    this.areas = areas
    for (const district of areas.districts) {
      L.polygon(latLngs(district.polygons), { ...OUTLINE, weight: 2.5, fillOpacity: this.cityValue ? 0 : 0.04 }).addTo(this.outlines)
    }
    for (const quarter of areas.quarters) {
      L.polygon(latLngs(quarter.polygons), { ...OUTLINE, weight: 1, opacity: 0.7, fillOpacity: 0 }).addTo(this.quarterOutlines)
    }

    if (this.fitOutlines && this.outlines.getLayers().length) this.map.fitBounds(this.outlines.getBounds(), { padding: [8, 8] })
    this.drawLevel()
  }

  // Only the answer to the latest request counts: the filters may have changed
  // while an earlier one was loading.
  async loadMarkers() {
    const request = ++this.markersRequest
    const data = await this.fetchJSON(this.withFilters(this.markersUrlValue))
    if (!data || request !== this.markersRequest) return

    this.markerData = data
    this.drawPins()
    this.drawLevel()
    this.showCoverage()
  }

  drawPins() {
    this.pins.clearLayers()

    const markers = this.markerData.places.map(([id, lat, lng, count, upcoming]) => {
      const title = `${count} ${count === 1 ? "Drucksache" : "Drucksachen"}${upcoming ? ", demnächst beraten" : ""}`
      const marker = L.marker([lat, lng], { icon: pinIcon(count, upcoming === 1), upcoming: upcoming === 1, title })
      lazyPopup(marker, this.withFilters(this.placeUrlValue.replace("ID", id)))
      return marker
    })

    this.pins.addLayers(markers)
  }

  level() {
    const zoom = this.map.getZoom()

    if (zoom >= this.constructor.PIN_ZOOM) return "pins"
    if (this.cityValue && zoom < this.constructor.DISTRICT_ZOOM) return "districts"
    return "quarters"
  }

  // Bubbles or pins for the zoom, and the Stadtteil outlines once they matter.
  drawLevel() {
    const level = this.level()

    this.toggle(this.quarterOutlines, level !== "districts")
    this.toggle(this.pins, level === "pins" && this.markerData)

    this.bubbles.clearLayers()
    if (!this.markerData || level === "pins") return

    if (level === "districts") {
      for (const district of this.areas.districts) {
        this.drawBubble(district, this.markerData.areas.districts[district.number], "Bezirk")
      }
    } else {
      for (const quarter of this.areas.quarters) {
        this.drawBubble(quarter, this.markerData.areas.quarters[quarter.name], "Stadtteil")
      }
    }
  }

  toggle(layer, visible) {
    if (visible && !this.map.hasLayer(layer)) layer.addTo(this.map)
    if (!visible && this.map.hasLayer(layer)) layer.remove()
  }

  // On the area's label point; a click zooms into the area.
  drawBubble(area, count, unit) {
    if (!count || !area.label) return

    const [lng, lat] = area.label
    const label = this.level() === "districts" || this.map.getZoom() >= this.constructor.PIN_ZOOM - 0.5 ? area.name : null
    const bubble = L.marker([lat, lng], { icon: bubbleIcon(count, { label }), title: `${area.name}: ${count} Drucksachen` })

    const what = count === 1 ? "Drucksache nennt" : "Drucksachen nennen"
    bubble.bindTooltip(
      `<strong>${escape(area.name)}</strong><br>${count.toLocaleString("de-DE")} ${what} hier einen Ort<br>` +
        `<span class="text-secondary">Klicken, um den ${unit} zu sehen</span>`,
      { direction: "top", offset: [0, -12] },
    )
    bubble.on("click", () => this.map.fitBounds(L.polygon(latLngs(area.polygons)).getBounds(), { padding: [16, 16] }))
    bubble.addTo(this.bubbles)
  }

  showCoverage() {
    const { documents, placed, pinned } = this.markerData.counts
    const number = (value) => value.toLocaleString("de-DE")

    if (documents === 0) {
      this.coverageTarget.textContent = "Im gewählten Zeitraum gibt es dazu keine Drucksachen."
      return
    }

    let text = `Von ${number(documents)} Drucksachen im gewählten Zeitraum nennen ${number(placed)} einen Ort, den die Karte kennt.`
    if (placed > pinned) {
      text += ` ${number(placed - pinned)} mit mehr als ${this.maxPlacesValue} Orten stehen nur in der Liste.`
    }
    this.coverageTarget.textContent = text
  }

  // The list follows the view, but not every frame of a pan.
  scheduleList() {
    clearTimeout(this.listTimeout)
    this.listTimeout = setTimeout(() => this.loadList(), 400)
  }

  loadList() {
    const bounds = this.map.getBounds()
    const bbox = [bounds.getSouth(), bounds.getWest(), bounds.getNorth(), bounds.getEast()].map((value) => value.toFixed(4)).join(",")

    this.listTarget.src = this.withFilters(this.documentsUrlValue, { bbox })
  }

  // A street or Stadtteil picked in the search (map_search_controller).
  showPlace(event) {
    const place = event.detail
    const bounds = L.latLngBounds(place.bounds)

    this.highlight.clearLayers()
    this.map.fitBounds(bounds, { padding: [24, 24], maxZoom: place.kind === "street" ? 16 : 15 })

    const where = place.quarters.map((quarter) => `<a href="${escape(quarter.path)}">${escape(quarter.name)}</a>`).join(", ")
    const districts = [...new Set(place.quarters.map((quarter) => quarter.district))].join(", ")
    const subscribe = this.feedUrlValue + (place.kind === "street" ? "?streets[]=" : "?quarters[]=") + encodeURIComponent(place.name)
    const content = `
      <strong>${escape(place.name)}</strong>
      ${where ? `<div class="text-secondary">${where}${districts ? ` · ${escape(districts)}` : ""}</div>` : ""}
      <div class="mt-1"><a href="${escape(subscribe)}">Neues ${place.kind === "street" ? "aus dieser Straße" : `aus ${escape(place.name)}`} abonnieren</a></div>
    `

    const positions = place.positions?.length ? place.positions : [bounds.getCenter()]
    for (const position of positions) {
      L.circleMarker(position, { radius: 14, color: "#212529", weight: 2, fill: false, interactive: false }).addTo(this.highlight)
    }
    L.popup({ ...POPUP, offset: [0, -14], autoPan: false }).setLatLng(positions[0]).setContent(content).openOn(this.map)
  }
}
