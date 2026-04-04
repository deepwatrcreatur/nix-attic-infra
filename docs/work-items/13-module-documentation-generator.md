# Module Documentation Generator

Status: `in-progress`
Suggested branch: `feat/module-docs-generator`
Priority: `medium`

## Goal

Automatically generate Markdown documentation for the NixOS and Home Manager
modules to ensure the documentation is always up-to-date with the available
options.

## Scope

- Create a script (e.g., using `nix-pkgs.lib.nixosOptionsDoc`) to extract
  option descriptions.
- Generate a Markdown table of options for each module.
- Integrate this into `nix flake check` or a standalone script.
- Update `docs/OPTIONS.md` with the generated content.
