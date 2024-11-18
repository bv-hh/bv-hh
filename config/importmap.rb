# Pin npm packages by running ./bin/importmap

pin "application"

pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"

pin "bootstrap", to: "bootstrap.min.js"
pin "@popperjs/core", to: "popper.js"

pin "@hotwired/turbo-rails", to: "turbo.min.js"

pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

pin "process" # @2.1.0
pin "leaflet" # @1.9.4

pin_all_from "app/javascript/controllers", under: "controllers"

