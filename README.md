# RPG-to-Free-Format

Converters for legacy IBM i source, written in free-format RPGLE (`**FREE`).

| Command | Converts |
|---|---|
| `IAOCLTOCLE` | OCL36 to CLLE |
| `IACNVDSPF` | DSPF36 / DSPF38 to DSPF |
| `IACNVFREE` | RPG36 to fully free format (RPG38, RPG and RPGLE fixed form are being added) |

Each converter reads from a source member or an IFS stream file and writes to either. Base release is IBM i V7R3, with support for later releases.

Status: first code written, not yet compiled. `IAOCLTOCLE` is the first converter.

- Design: [docs/DESIGN.md](docs/DESIGN.md)
- OCL rules: [docs/OCL-MAPPING.md](docs/OCL-MAPPING.md)
- Manual build steps: [docs/BUILD.md](docs/BUILD.md)

## License

MIT. See [LICENSE](LICENSE).
