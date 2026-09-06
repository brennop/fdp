// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener("turbo:before-frame-render", (event) => {
  const originalRender = event.detail.render
  event.detail.render = (currentElement, newElement) => {
    document.startViewTransition(()=> originalRender(currentElement, newElement))
  }
});
