# Observatory API Auth

Status: `done`
Suggested branch: `feat/observatory-api-auth`
Priority: `low`

## Goal

Add optional authentication to the Attic Observatory UI/API to protect it when
exposed to the public internet.

## Scope

- Research minimal auth options (Basic Auth via Nginx, or OIDC via a proxy).
- Add options to `services.attic-observatory.nginx` for auth configuration.
- Implement Basic Auth helper if requested.
- Update documentation with security recommendations.
