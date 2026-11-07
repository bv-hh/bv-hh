import { Controller } from "@hotwired/stimulus"

// The search field above the map: Stadtteile from the page, streets from
// streets#suggest as you type. Picking one dispatches map-search:select with
// the place, which the map zooms to (map_controller#showPlace).
//
// A combobox: arrow keys move through the suggestions, Enter picks, Escape
// closes.
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { suggestUrl: String, quarters: Array, minLength: { type: Number, default: 2 } }

  connect() {
    this.options = []
    this.active = -1
    this.onDocumentClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    document.addEventListener("click", this.onDocumentClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    this.cancel()
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.suggest(), 200)
  }

  async suggest() {
    const term = this.inputTarget.value.trim()
    if (term.length < this.minLengthValue) return this.close()

    const needle = term.toLocaleLowerCase("de")
    const quarters = this.quartersValue
      .filter((quarter) => quarter.name.toLocaleLowerCase("de").startsWith(needle))
      .slice(0, 4)
      .map((quarter) => ({ kind: "quarter", name: quarter.name, hint: `Stadtteil in ${quarter.district}`, bounds: quarter.bounds, quarters: [quarter] }))

    // Supersede the request in flight, so a slow answer cannot overwrite a
    // newer one.
    this.abortController?.abort()
    this.abortController = new AbortController()

    let streets = []
    try {
      const response = await fetch(this.suggestUrlValue.replace("QUERY", encodeURIComponent(term)), {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal,
      })
      if (response.ok) streets = (await response.json()).filter((street) => street.positions.length > 0).map((street) => this.street(street))
    } catch (error) {
      if (error.name === "AbortError") return
    }

    this.render([...quarters, ...streets].slice(0, 10))
  }

  street(street) {
    const quarters = street.quarters.map((name) => this.quartersValue.find((quarter) => quarter.name === name)).filter(Boolean)
    const lats = street.positions.map(([lat]) => lat)
    const lngs = street.positions.map(([, lng]) => lng)

    return {
      kind: "street",
      name: street.name,
      hint: street.quarters.join(", "),
      positions: street.positions,
      bounds: [[Math.min(...lats), Math.min(...lngs)], [Math.max(...lats), Math.max(...lngs)]],
      quarters,
    }
  }

  render(options) {
    this.options = options
    this.active = -1
    this.resultsTarget.replaceChildren()

    if (options.length === 0) {
      const empty = document.createElement("li")
      empty.className = "list-group-item small text-secondary"
      empty.textContent = "Keine Straße und kein Stadtteil gefunden."
      this.resultsTarget.append(empty)
    }

    options.forEach((option, index) => {
      const item = document.createElement("li")
      item.id = `map-search-option-${index}`
      item.className = "list-group-item list-group-item-action"
      item.setAttribute("role", "option")
      item.setAttribute("aria-selected", "false")
      item.addEventListener("mousedown", (event) => event.preventDefault())
      item.addEventListener("click", () => this.pick(index))

      const name = document.createElement("strong")
      name.textContent = option.name
      item.append(name)

      if (option.hint) {
        const hint = document.createElement("span")
        hint.className = "text-secondary small ms-2"
        hint.textContent = option.hint
        item.append(hint)
      }

      this.resultsTarget.append(item)
    })

    this.resultsTarget.classList.remove("d-none")
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  keydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.move(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.move(-1)
        break
      case "Enter":
        // Never submit the filter form from here.
        event.preventDefault()
        if (this.options.length) this.pick(Math.max(this.active, 0))
        break
      case "Escape":
        this.close()
        break
    }
  }

  move(step) {
    if (this.options.length === 0) return

    this.active = (this.active + step + this.options.length) % this.options.length
    this.resultsTarget.querySelectorAll("[role=option]").forEach((item, index) => {
      const selected = index === this.active
      item.classList.toggle("active", selected)
      item.setAttribute("aria-selected", String(selected))
      if (selected) item.scrollIntoView({ block: "nearest" })
    })
    this.inputTarget.setAttribute("aria-activedescendant", `map-search-option-${this.active}`)
  }

  pick(index) {
    const option = this.options[index]
    if (!option) return

    this.inputTarget.value = option.name
    this.close()
    this.dispatch("select", { detail: option })
  }

  // Closing also drops the suggestions still to come, so a late answer cannot
  // open the list again.
  close() {
    this.cancel()
    this.options = []
    this.active = -1
    this.resultsTarget.classList.add("d-none")
    this.resultsTarget.replaceChildren()
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  cancel() {
    clearTimeout(this.timeout)
    this.abortController?.abort()
  }
}
