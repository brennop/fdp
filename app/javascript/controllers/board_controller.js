import { Controller } from "@hotwired/stimulus"
import { motionValue, springValue, transformValue, styleEffect, animate } from "motion";
import { DragGesture } from "@use-gesture/vanilla";

const WIDTH = 36 * 4;
const insideRect = ({ x, y }, rect) => x > rect.left && x <= rect.left + rect.width && y > rect.top && y <= rect.top + rect.height

// from lodash-move
const move = (array, moveIndex, toIndex) => {
  const item = array[moveIndex];
  const length = array.length;
  const diff = moveIndex - toIndex;

  if (diff > 0) {
    // move left
    return [
      ...array.slice(0, toIndex),
      item,
      ...array.slice(toIndex, moveIndex),
      ...array.slice(moveIndex + 1, length)
    ];
  } else if (diff < 0) {
    // move right
    const targetIndex = toIndex + 1;
    return [
      ...array.slice(0, moveIndex),
      ...array.slice(moveIndex + 1, targetIndex),
      item,
      ...array.slice(targetIndex, length)
    ];
  }
  return array;
}

function clamp(number, lower, upper) {
  return Math.min(Math.max(number, lower), upper);
}

const RANK_ORDER = { ["3C"]: 36, ["3H"]: 35, ["3S"]: 34, ["3D"]: 33, ["2C"]: 32, ["2H"]: 31, ["2S"]: 30, ["2D"]: 29, ["AC"]: 28, ["AH"]: 27, ["AS"]: 38, ["AD"]: 26, ["KC"]: 25, ["KH"]: 24, ["KS"]: 23, ["KD"]: 22, ["QC"]: 21, ["QH"]: 20, ["QS"]: 19, ["QD"]: 18, ["JC"]: 17, ["JH"]: 16, ["JS"]: 15, ["JD"]: 14, ["7C"]: 13, ["7H"]: 39, ["7S"]: 12, ["7D"]: 37, ["6C"]: 11, ["6H"]: 10, ["6S"]: 9, ["6D"]: 8, ["5C"]: 7, ["5H"]: 6, ["5S"]: 5, ["5D"]: 4, ["4C"]: 40, ["4H"]: 3, ["4S"]: 0, ["4D"]: 1 }

class Card {
  constructor(element, position, ref, amount, update) {
    this.element = element
    this.ref = ref;
    this.position = position;
    this.amount = amount;

    this.value = element.dataset.card;
    this.index = element.dataset.index;

    this.x = motionValue(0);
    this.y = motionValue(0);

    this.drag = new DragGesture(this.element, ({ active, first, xy: [x, y] }) => {
      this.active = active;

      if (first) {
        this.grabOffsetX = x - (this.x.get() + this.xOff);
        this.grabOffsetY = y - (this.y.get() + this.yOff);
      }

      if (this.active && this.position == "hand") {
        this.x.set(-this.grabOffsetX + x - this.xOff)
        this.y.set(-this.grabOffsetY + y - this.yOff)
      } else {
        this.x.set(0);
        this.y.set(0);
      }

      update(this, { x, y });
    });

    this.xPos = transformValue(() => this.x.get() + this.xOff)
    this.yPos = transformValue(() => this.y.get() + this.yOff)

    this.springX = springValue(this.xPos, { stiffness: 1000, damping: 50 })
    this.springY = springValue(this.yPos, { stiffness: 1000, damping: 50 })

    this.styleEffect = styleEffect(this.element, { x: this.springX, y: this.springY })
  }

  get refRect() {
    return this.ref.getBoundingClientRect();
  }

  get xOff() {
    return this.ref.clientWidth / 2 + this.refRect.left - ((this.amount - 1) * WIDTH / 2) + this.index * WIDTH
  }

  get yOff() {
    return this.ref.clientHeight / 2 + this.refRect.top
  }

  get isHand() {
    return this.position === "hand"
  }

}

// Connects to data-controller="board"
export default class extends Controller {
  static targets = ["handCard", "tableCard", "hand", "table"]

  connect() {
    this.cards = this.handCardTargets
      .map(cardTarget => new Card(cardTarget, "hand", this.handTarget, this.handCardTargets.length, this.update))
      .concat(
        this.tableCardTargets
          .map(cardTarget => new Card(cardTarget, "table", this.tableTarget, this.tableCardTargets.length, this.update.bind(this))));
  }

  // compute layout and set each Card's x&y
  update = (card, point) => {
    const oldXOff = card.xOff;
    const oldYOff = card.yOff;

    if (insideRect(point, this.tableTarget.getBoundingClientRect())) {
      card.position = "table";
      card.ref = this.tableTarget;
      card.x.set(0);
      card.y.set(0);
    } else {
      card.position = "hand";
      card.ref = this.handTarget;

      const curIndex = card.index
      const curColumn = clamp(Math.round((curIndex * WIDTH + point.x - card.xOff) / WIDTH), 0, card.amount - 1)

      move(this.cards.filter(card => card.isHand)
        .sort((a, b) => a.index - b.index), curIndex, curColumn)
        .forEach((card, index) => {
          card.index = index;
          card.amount = this.cards.filter(c => c.isHand).length
        })
    }

    const newXOff = card.xOff;
    const newYOff = card.yOff;

    if (newXOff !== oldXOff || newYOff !== oldYOff) {
      card.x.set(card.x.get() + oldXOff - newXOff);
      card.y.set(card.y.get() + oldYOff - newYOff);
    }

    // update hand cards
    
  }
}
