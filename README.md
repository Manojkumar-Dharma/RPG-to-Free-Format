# RPG-to-Free-Format

Converters for legacy IBM i source, written in free-format RPGLE (`**FREE`).

| Command | Converts |
|---|---|
| `IAOCLTOCLE` | OCL36 to CLLE |
| `IACNVDSPF` | DSP36 / DSP38 to DSPF |
| `IACNVFREE` | RPG36 / RPG38 / RPG3 / RPG4 to fully free format |

Each converter reads from a source member or an IFS stream file and writes to either. Base release is IBM i V7R3, with support for later releases.

Status: design phase. See [docs/DESIGN.md](docs/DESIGN.md).

## License

MIT. See [LICENSE](LICENSE).
