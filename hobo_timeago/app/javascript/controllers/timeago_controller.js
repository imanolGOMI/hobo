import { Controller } from "@hotwired/stimulus"

// Keep "3 minutes ago" true while the page stays open.
//
// The server already painted the phrase, so a browser with no JavaScript shows
// a correct one -- just one that stops being correct. This re-paints it from
// the machine-readable moment in `datetime`, and does it in the reader's
// locale, which the server does not know.
export default class extends Controller {
  static values = { at: String }

  connect() {
    this.refresh()
    this.timer = setInterval(() => this.refresh(), 60000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  refresh() {
    const at = Date.parse(this.atValue)
    if (isNaN(at)) return

    const seconds = (at - Date.now()) / 1000
    const format = new Intl.RelativeTimeFormat(undefined, { numeric: "auto" })

    for (const [unit, size] of UNITS) {
      if (Math.abs(seconds) >= size || unit === "minute") {
        this.element.textContent = format.format(Math.trunc(seconds / size), unit)
        return
      }
    }
  }
}

const UNITS = [
  ["year", 31557600],
  ["month", 2629800],
  ["week", 604800],
  ["day", 86400],
  ["hour", 3600],
  ["minute", 60]
]
