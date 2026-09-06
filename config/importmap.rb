# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# config/importmap.rb
pin "motion", to: "https://esm.sh/motion"
pin "@dnd-kit/dom", to: "https://esm.sh/@dnd-kit/dom"
pin "@dnd-kit/dom/sortable", to: "https://esm.sh/@dnd-kit/dom/sortable"
pin "@use-gesture/vanilla", to: "https://esm.sh/@use-gesture/vanilla"
