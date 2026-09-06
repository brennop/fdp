import { Controller } from "@hotwired/stimulus"
import {} from "motion";

// Connects to data-controller="card"
export default class extends Controller {
  static values = { card: String }

  connect() {
    console.log(this.cardValue)
  }
}
