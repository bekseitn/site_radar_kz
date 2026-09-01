import { Controller } from "@hotwired/stimulus"

// Backs the site-detail modal on the site list: a <dialog> containing a
// Turbo Frame that's empty until a row is clicked, at which point its
// src is set to that site's show page (loading it into the frame the
// same way a Turbo Frame link would) and the dialog is shown.
//
// Lives on a wrapper around both the (repeatedly Turbo-Frame-replaced)
// site list and the dialog itself, so it keeps working across filter/
// sort updates without needing to reconnect.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  // Bound to each row's click — reads the site's show-page URL off the
  // row's own data attribute (data-modal-url-value) rather than off
  // event.currentTarget.dataset directly, since the action can also
  // fire from something nested inside the row.
  open(event) {
    // Let an actual link/button inside the row (the site's own URL,
    // external profile links, ...) keep its own default behavior
    // instead of also opening the modal.
    if (event.target.closest("a, button")) return

    const url = event.currentTarget.dataset.modalUrlValue
    if (!url) return

    this.frameTarget.src = url
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // <dialog>'s own backdrop is a pseudo-element, not a real child node —
  // a click that lands directly on the <dialog> element itself (not on
  // anything inside it) is a click outside the visible modal box.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
