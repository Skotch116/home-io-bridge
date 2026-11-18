# Contributing

> **This is Home.io Bridge, a fork of PlayOnAir** (from its 0.4.0 release). What follows is PlayOnAir's own text, kept
> as its author wrote it. In the fork the add-on folder is `home_io_bridge/` (not `play-on-air/`), the image is
> `ghcr.io/skotch116/home-io-bridge`, the add-on has its own version in `home_io_bridge/config.yaml`, and the fork's
> changes have not been put through the format and lint gates described here. See `README.md`.

PlayOnAir is personal MIT open source maintained by Felipe Lima. Useful patches are welcome.

## Language

American English in code, commits, docs, comments, and PR text.

## Toolchain

- **MSRV:** Rust **1.88** (`rust-version` in the workspace `Cargo.toml`)
- Format: `rustfmt.toml` (width 120, 2-space indent, edition 2024)
- Clippy: workspace deny bar (`-D warnings` in the quality gate)

## Quality gate

From the repository root (with [just](https://github.com/casey/just) installed):

```bash
just check
```

That runs format check, clippy, tests, and supply-chain gates. Prefer `cargo nextest` when available (`just test`). Do not land work that fails format, clippy, or deny/audit/machete.

## Conventions

- Conventional commits: `type(scope): subject` (lowercase subject, no trailing period)
- Branches: `type/description` kebab-case
- Product rules: zero required config; AirPlay 2 only; Chromecast only; no second lossy Cast encode by default — see [AGENTS.md](AGENTS.md) and [VISION.md](VISION.md)
- Architecture forks with more than one valid option → ask before implementing

## Git hygiene

- Never commit secrets or device pairing material
- Do not add `Co-Authored-By` trailers (including AI tooling attribution)
- Do not amend published history
