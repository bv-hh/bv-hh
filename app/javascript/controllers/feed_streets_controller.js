import { Controller } from "@hotwired/stimulus"

// Street picker for the RSS feed config page.
//
// ~9500 streets is far too many for a select, so this queries streets#suggest
// as you type and renders picks as removable chips backed by hidden inputs.
// The form is a plain GET form, so without JavaScript the page still works —
// you just lose the autocomplete.
export default class extends Controller {
  static targets = ["input", "suggestions", "chips"]
  static values = { suggestUrl: String, minLength: { type: Number, default: 2 } }

  connect() {
    this.abortController = null
    this.onDocumentClick = (event) => {
      if (!this.element.contains(event.target)) this.hideSuggestions()
    }
    document.addEventListener("click", this.onDocumentClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    this.abortController?.abort()
  }

  // Debounced so a fast typist issues one request, not one per keystroke.
  search() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.fetchSuggestions(), 200)
  }

  async fetchSuggestions() {
    const term = this.inputTarget.value.trim()
    if (term.length < this.minLengthValue) return this.hideSuggestions()

    // Supersede the in-flight request so slow responses cannot overwrite fast
    // ones and show results for an older term.
    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const response = await fetch(this.suggestUrlValue.replace("QUERY", encodeURIComponent(term)), {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal,
      })
      if (!response.ok) return this.hideSuggestions()
      this.renderSuggestions(await response.json())
    } catch (error) {
      if (error.name !== "AbortError") this.hideSuggestions()
    }
  }

  renderSuggestions(streets) {
    this.suggestionsTarget.replaceChildren()

    if (streets.length === 0) return this.hideSuggestions()

    for (const street of streets) {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "list-group-item list-group-item-action"
      button.dataset.action = "feed-streets#add"
      button.dataset.name = street.name

      const name = document.createElement("strong")
      name.textContent = street.name
      button.append(name)

      if (street.quarters.length > 0) {
        const hint = document.createElement("span")
        hint.className = "text-secondary small ms-2"
        hint.textContent = street.quarters.join(", ")
        button.append(hint)
      }

      this.suggestionsTarget.append(button)
    }

    this.suggestionsTarget.classList.remove("d-none")
  }

  add(event) {
    const name = event.currentTarget.dataset.name
    if (!this.selectedNames().includes(name)) this.chipsTarget.append(this.buildChip(name))

    this.inputTarget.value = ""
    this.hideSuggestions()
  }

  remove(event) {
    event.currentTarget.closest("[data-street-name]").remove()
  }

  // Enter picks the first suggestion rather than submitting the form — a
  // half-typed street name would otherwise silently drop out of the selection.
  keydown(event) {
    if (event.key !== "Enter") return

    event.preventDefault()
    this.suggestionsTarget.querySelector("button")?.click()
  }

  buildChip(name) {
    const chip = document.createElement("span")
    chip.className = "badge bg-secondary d-inline-flex align-items-center gap-2"
    chip.dataset.streetName = name

    const label = document.createElement("span")
    label.textContent = name

    const field = document.createElement("input")
    field.type = "hidden"
    field.name = "streets[]"
    field.value = name

    const close = document.createElement("button")
    close.type = "button"
    close.className = "btn-close btn-close-white"
    close.setAttribute("aria-label", "Entfernen")
    close.dataset.action = "feed-streets#remove"

    chip.append(label, field, close)
    return chip
  }

  selectedNames() {
    return Array.from(this.chipsTarget.querySelectorAll("input[name='streets[]']")).map((field) => field.value)
  }

  hideSuggestions() {
    this.suggestionsTarget.classList.add("d-none")
    this.suggestionsTarget.replaceChildren()
  }
}
