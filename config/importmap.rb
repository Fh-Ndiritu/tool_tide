# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@rails/activestorage", to: "@rails--activestorage.js" # @8.0.200
pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"
pin "@stimulus-components/dropdown", to: "@stimulus-components--dropdown.js" # @3.0.0
pin "stimulus-use" # @0.52.3
pin "@stimulus-components/password-visibility", to: "@stimulus-components--password-visibility.js" # @3.0.0
pin "masonry-layout" # @4.2.2
pin "imagesloaded" # @5.0.0
pin "desandro-matches-selector" # @2.0.2
pin "ev-emitter" # @2.1.2
pin "fizzy-ui-utils" # @2.0.7
pin "get-size" # @2.0.3
pin "outlayer" # @2.1.1
pin "ejs" # @0.7.1
pin "fs" # @2.1.0
pin "photoswipe", to: "https://unpkg.com/photoswipe@5.4.3/dist/photoswipe.esm.js"
pin "photoswipe-lightbox", to: "https://unpkg.com/photoswipe@5.4.3/dist/photoswipe-lightbox.esm.js"
pin "driver.js", to: "https://cdn.jsdelivr.net/npm/driver.js@1.0.1/dist/driver.js.mjs"
pin "canvas-confetti" # @1.9.4
pin "imagesloaded" # @5.0.0
pin "masonry-layout" # @4.2.2
pin "desandro-matches-selector" # @2.0.2
pin "ev-emitter" # @2.1.2
pin "fizzy-ui-utils" # @2.0.7
pin "get-size" # @2.0.3
pin "outlayer" # @2.1.1
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.13
pin "chart.js" # @4.5.1
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "chart.js/auto", to: "https://ga.jspm.io/npm:chart.js@4.4.2/auto/auto.js"
pin "chartkick" # @5.0.1
pin "chartjs-adapter-date-fns" # @3.0.0
pin "date-fns", to: "https://cdn.jsdelivr.net/npm/date-fns@4.1.0/+esm"
