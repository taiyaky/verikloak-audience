# verikloak-audience

[![CI](https://github.com/taiyaky/verikloak-audience/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/taiyaky/verikloak-audience/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/verikloak-audience)](https://rubygems.org/gems/verikloak-audience)
![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.1-blue)
[![Downloads](https://img.shields.io/gem/dt/verikloak-audience)](https://rubygems.org/gems/verikloak-audience)

Rack middleware for validating the `aud` claim of Keycloak-issued tokens on top of the Verikloak stack. It ships with deploy-friendly presets that address common Keycloak patterns such as `account` co-existence and `resource_access`-driven role enforcement.

For the full error behaviour (response shapes, exception classes, logging hints), see [ERRORS.md](ERRORS.md).

> Insert the middleware immediately **after** `Verikloak::Middleware`. Doing so ensures the token is already verified and the claims are available via `env["verikloak.user"]` (default).

## Why
- Keycloak often emits multiple audiences (e.g. `["rails-api","account"]`)
- Some deployments primarily rely on `resource_access[client].roles`
- Re-implementing permissive/strict `aud` checks per app is a maintenance burden

## Profiles

| Profile | Summary | Suggested scenarios / when `suggest_in_logs` points here |
|---------|---------|-----------------------------------------------------------|
| `:strict_single` *(recommended)* | Requires `aud` to match `required_aud` exactly (order-insensitive, no extras). | APIs where audiences are cleanly separated. Logged suggestion when the observed `aud` already equals the configured list. |
| `:allow_account` | Allows `account` in addition to required audiences (e.g. `["rails-api","account"]`). | SPA + API mixes where Keycloak always emits `account`. Suggested when strict mode fails and the log shows `profile=:allow_account`. |
| `:any_match` | Passes when at least one of the required audiences is present. | Shared APIs where multiple clients may have overlapping audiences. More permissive than `:strict_single`. |
| `:resource_or_aud` | Passes when `resource_access[client].roles` is present; otherwise falls back to `:allow_account`. | Services relying on resource roles. Suggested when logs output `profile=:resource_or_aud`. |

## Installation

```bash
bundle add verikloak-audience
```

In Rails applications, run the generator to create a configuration initializer:

```bash
rails g verikloak:audience:install
```

This creates `config/initializers/verikloak_audience.rb` with configuration options.
The middleware is automatically inserted by the Railtie after `Verikloak::Middleware`.

## Manual Rack / Rails setup

Alternatively, you can manually insert **after** `Verikloak::Middleware`:

```ruby
# config/application.rb
config.middleware.insert_after Verikloak::Middleware, Verikloak::Audience::Middleware,
  profile: :allow_account,
  required_aud: ["rails-api"],
  resource_client: "rails-api",
  env_claims_key: "verikloak.user",
  suggest_in_logs: true
```

See [`examples/rack.ru`](examples/rack.ru) for a full Rack sample. In Rails, always insert immediately after the core middleware; otherwise `env['verikloak.user']` will be empty and every request will fail with 403.

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `profile` | Symbol | `:strict_single` | Profile selector. Accepts `:strict_single`, `:allow_account`, `:any_match`, or `:resource_or_aud`. |
| `required_aud` | Array/String/Symbol | `[]` | Required audience values; coerced to an array internally. |
| `resource_client` | String | `"rails-api"` | Keycloak client id used to look up `resource_access[client].roles`. |
| `env_claims_key` | String | `"verikloak.user"` | Rack env key where verified claims are stored. |
| `suggest_in_logs` | Boolean | `true` | Emits a WARN log with the suggested profile when validation fails. |

`env_claims_key` assumes the preceding `Verikloak::Middleware` populates the Rack env. If the middleware order changes, claims will be missing and the audience check will always reject.

### Operational safeguards
- Middleware initialisation now fails fast when `required_aud` is empty. When Rails loads via the supplied Railtie, `Verikloak::Audience.config.validate!` runs after boot so configuration mistakes surface during startup instead of returning 403 for every request.
- When audience validation fails, the middleware consults `env['verikloak.logger']`, `env['rack.logger']`, and `env['action_dispatch.logger']` (in that order) before falling back to Ruby's `Kernel#warn`, keeping failure logs consistent with Rails and Verikloak observers.
- For the `:resource_or_aud` profile, `resource_client` must match one of the values in `required_aud`. A single-element `required_aud` automatically infers the client id, ensuring the same client identifier is shared with downstream BFF/Pundit integrations.

## Keycloak Integration

### Default Audience Behavior

Keycloak access tokens include `aud: "account"` by default. This is often unexpected for developers who expect the client ID to appear in the audience claim.

| Token Type | Default `aud` Value |
|------------|---------------------|
| Access Token | `"account"` |
| ID Token | Client ID |

### Common Issue

```ruby
# Configuration
config.verikloak.audience = 'rails-api'

# Actual token payload
{
  "aud": "account",  # NOT "rails-api"!
  "sub": "user-123",
  ...
}

# Result: 403 Forbidden - audience validation fails
```

### Solution: Configure Audience Mapper in Keycloak

To add a custom audience to access tokens:

1. Go to **Clients** → Select your client (e.g., `rails-api`)
2. Navigate to **Client scopes** tab
3. Click on the dedicated scope (e.g., `rails-api-dedicated`)
4. Go to **Mappers** tab → **Add mapper** → **By configuration**
5. Select **Audience**
6. Configure:
   - **Name**: `rails-api-audience`
   - **Included Client Audience**: `rails-api`
   - **Add to access token**: ON
7. Save

After this configuration, tokens will include:
```json
{
  "aud": ["rails-api", "account"],
  ...
}
```

### Configuration Examples

#### Option 1: Allow both custom and account audience

```ruby
# config/initializers/verikloak.rb
Rails.application.configure do
  config.verikloak.audience = ['rails-api', 'account']
end
```

#### Option 2: Use :allow_account profile

```ruby
# With verikloak-audience middleware
use Verikloak::Audience::Middleware,
  profile: :allow_account,
  required_aud: ['rails-api']
```

#### Option 3: Strict single audience (requires Keycloak Mapper)

```ruby
# Only works if Keycloak Audience Mapper is configured
use Verikloak::Audience::Middleware,
  profile: :strict_single,
  required_aud: ['rails-api']
```

### Troubleshooting

#### "Audience validation failed" errors

1. Check your token's `aud` claim:
   ```bash
   # Decode JWT (paste your token)
   echo "YOUR_TOKEN" | cut -d. -f2 | base64 -d | jq .aud
   ```

2. If `aud` is only `"account"`:
   - Add an Audience Mapper in Keycloak (see above)
   - OR use `:allow_account` profile

3. If using oauth2-proxy:
   - Ensure the correct client ID is configured
   - Check that the token is being forwarded correctly

## Testing
All pull requests and pushes are automatically tested with [RSpec](https://rspec.info/) and [RuboCop](https://rubocop.org/) via GitHub Actions.
See the CI badge at the top for current build status.

To run the test suite locally:

```bash
docker compose run --rm dev rspec
docker compose run --rm dev rubocop -a
```

## Contributing
Bug reports and pull requests are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Security
If you find a security vulnerability, please follow the instructions in [SECURITY.md](SECURITY.md).

## License
This project is licensed under the [MIT License](LICENSE).

## Publishing (for maintainers)
Gem release instructions are documented separately in [MAINTAINERS.md](MAINTAINERS.md).

## Changelog
See [CHANGELOG.md](CHANGELOG.md) for release history.

## References
- Verikloak (core): https://github.com/taiyaky/verikloak
- verikloak-rails (Rails integration): https://github.com/taiyaky/verikloak-rails
- verikloak-audience on RubyGems: https://rubygems.org/gems/verikloak-audience
