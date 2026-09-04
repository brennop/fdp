import { Controller } from "@hotwired/stimulus"
import {animate, springValue, motionValue, mapValue, styleEffect} from "motion";

// Connects to data-controller="card"
export default class extends Controller {
  static values = { card: String }

  connect() {
    console.log(this.cardValue)

    this.xPctValue = springValue(0);
    this.yPctValue = springValue(0);
    this.scale = springValue(1);

    const rotateX = mapValue(this.yPctValue, [0.5, -0.5], ["20deg", "-20deg"])
    const rotateY = mapValue(this.xPctValue, [0.5, -0.5], ["-20deg", "20deg"])

    styleEffect(this.element, { rotateX , rotateY, scale: this.scale })
  }

  mouseMove(event) {
    const rect = this.element.getBoundingClientRect();
    const { width, height } = rect;
    const mouseX = event.clientX - rect.left;
    const mouseY = event.clientY - rect.top;

    const xPct = mouseX/width - 0.5;
    const yPct = mouseY/height - 0.5;

    this.xPctValue.set(xPct);
    this.yPctValue.set(yPct);
    this.scale.set(1.1);
  }

  mouseLeave() {
    this.xPctValue.set(0);
    this.yPctValue.set(0);
    this.scale.set(1);
  }
}
