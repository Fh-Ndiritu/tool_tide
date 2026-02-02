# frozen_string_literal: true

# Pagy v43 - Require pagy to make constants available
require "pagy"

# v43 says: "Configuration requirements reduced by 99%"
# and "It autoloads ONLY the methods that you actually use, with almost zero configuration"
# The pagy method call accepts options like `limit:` directly.
