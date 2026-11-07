import "leaflet"
import "leaflet.markercluster"

// What the maps share: the map page (map_controller), a Stadtteil page
// (quarter_map_controller) and the choropleths (choropleth_controller).

// Leaflet sets tooltip and popup content as HTML.
export const escape = (text) =>
  String(text).replace(/[&<>"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[char])

export function tileLayer(options = {}) {
  return L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    ...options,
  })
}

// GeoJSON is [polygon][ring][point][lng, lat]; Leaflet wants [lat, lng].
export function latLngs(polygons) {
  return polygons.map((polygon) => polygon.map((ring) => ring.map(([lng, lat]) => [lat, lng])))
}

// The outline of a Bezirk or Stadtteil around what is on the map.
export const OUTLINE = { color: "#0d6efd", weight: 2, fillOpacity: 0.06, interactive: false }

// Popups look like the choropleth tooltips (.map-popup in application.sass).
export const POPUP = { className: "map-popup", minWidth: 220, maxWidth: 300, autoPanPadding: [16, 16] }

// A place, as a dot: blue, or red while one of its Drucksachen is still to be
// discussed. Wider for more Drucksachen, up to a point.
export function pinIcon(count = 1, upcoming = false) {
  const size = Math.round(12 + Math.min(8, 2 * Math.log2(count)))

  return L.divIcon({
    className: `map-pin${upcoming ? " map-pin-upcoming" : ""}`,
    iconSize: [size, size],
    // A popup points at the dot's top, not its centre.
    popupAnchor: [0, -size / 2],
    html: "",
  })
}

// Pins close together, as a bubble with their number, like the area bubbles.
export function clusterGroup(options = {}) {
  return L.markerClusterGroup({
    maxClusterRadius: 40,
    showCoverageOnHover: false,
    iconCreateFunction: (cluster) => {
      const upcoming = cluster.getAllChildMarkers().some((marker) => marker.options.upcoming)
      return bubbleIcon(cluster.getChildCount(), { upcoming, small: true })
    },
    ...options,
  })
}

// A circle with a number, sized by its square root: an area's Drucksachen, or a
// cluster's pins. label names the area below the circle.
export function bubbleIcon(count, { label = null, upcoming = false, small = false } = {}) {
  const size = Math.round((small ? 26 : 30) + Math.min(small ? 14 : 34, Math.sqrt(count) * (small ? 1.5 : 2)))
  const caption = label ? `<span class="map-bubble-label">${escape(label)}</span>` : ""

  return L.divIcon({
    className: "map-bubble-icon",
    iconSize: [size, size],
    html: `<span class="map-bubble${upcoming ? " map-bubble-upcoming" : ""}" style="width:${size}px;height:${size}px">${count.toLocaleString("de-DE")}</span>${caption}`,
  })
}

// Binds a popup that fetches its content when first opened.
export function lazyPopup(marker, url) {
  let loaded = false

  marker.bindPopup('<span class="text-secondary">Wird geladen …</span>', POPUP)
  marker.on("popupopen", async () => {
    if (loaded) return

    try {
      const response = await fetch(url, { headers: { Accept: "text/html" } })
      if (!response.ok) throw new Error(response.statusText)

      marker.setPopupContent(await response.text())
      loaded = true
    } catch {
      marker.setPopupContent('<span class="text-secondary">Konnte nicht geladen werden.</span>')
    }
  })
}
