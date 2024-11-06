# Pin npm packages by running ./bin/importmap

pin "application"

pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"

pin "bootstrap", to: "bootstrap.min.js"
pin "@popperjs/core", to: "popper.js"

pin "@hotwired/turbo-rails", to: "turbo.min.js"

pin "process" # @2.1.0
