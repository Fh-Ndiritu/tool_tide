# Testing Guidelines

## Core Principles

1.  **No FactoryBot**: We do not use `factory_bot` or `factory_bot_rails`.
2.  **Use Fixtures**: Prefer Rails Fixtures for setting up test data.
3.  **Direct Creation**: For simple, one-off setups, direct ActiveRecord creation (e.g., `User.create!`) is also acceptable.

## Why Fixtures?

- **Speed**: Fixtures are loaded once per test run into the database, making them significantly faster than creating records for every example.
- **Simplicity**: They provide a fixed, known state for tests.
- **Standard Rails**: They are the default testing tool for Rails and integrate deeply with the framework.

## Examples

### ❌ Bad (FactoryBot)

```ruby
# Do NOT do this
let(:user) { create(:user) }
```

### ✅ Good (Fixtures)

```ruby
# spec/fixtures/users.yml
# alice:
#   email: alice@example.com
#   name: Alice

# In your spec:
let(:user) { users(:alice) }
```

### ✅ Good (Direct Creation)

```ruby
let(:user) { User.create!(email: "test@example.com", password: "password") }
```

## Configuration

If you see `require 'factory_bot_rails'` or `config.include FactoryBot::Syntax::Methods`, please remove it.
