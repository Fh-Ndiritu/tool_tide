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
pin "masonry" # @0.0.2
pin "ejs" # @0.7.1
pin "fs" # @2.1.0
pin "photoswipe", to: "https://unpkg.com/photoswipe@5.4.3/dist/photoswipe.esm.js"
pin "photoswipe-lightbox", to: "https://unpkg.com/photoswipe@5.4.3/dist/photoswipe-lightbox.esm.js"
