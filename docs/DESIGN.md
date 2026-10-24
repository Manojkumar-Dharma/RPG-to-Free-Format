# Legacy Source Converters: Design

Status: draft v0.1. Decisions marked **(open)** still need confirmation.

> The commands take `SRC(lib/file member)` and `TGT(lib/file member)` as grouped values. The tables below describe what each part means.

## 1. Scope

Three converters, one program (and one command) each. Smallest first.

| Order | Command | Program | Converts |
|---|---|---|---|
| 1 | `IAOCLTOCLE` | `IAoclToCle` | OCL36 to CLLE |
| 2 | `IACNVDSPF` | `IAcnvDspf` | DSPF36 / DSPF38 to DSPF (DDS) |
| 3 | `IACNVFREE` | `IAcnvFree` | RPG36 / RPG38 / RPG3 / RPG4 to fully free format (`**FREE`) |

For `IAcnvFree`, the intended route is two stages: normalize the older dialects to fixed-format RPG IV, then convert fixed RPG IV to `**FREE`. IBM's `CVTRPGSRC` may cover stage 1 and must be evaluated first.

Later: a VS Code extension that drives the same commands (see section 10).

## 2. Targets

- Base IBM i release: **V7R3**. The code must also run on all later releases.
- New source is always `**FREE`.
- Do not use language features or built-ins newer than V7R3 without a documented reason. Compile with `TGTRLS(V7R3)` in the build, and test on at least one later release.

## 3. Common parameters

All three commands take the same parameters.

| Group | Parameter | Meaning |
|---|---|---|
| Input | `SRCLIB` | Source library |
| Input | `SRCFILE` | Source physical file |
| Input | `SRCIFS` | IFS **directory** (trailing `/` optional) |
| Input | `SRCMBR` | Source member name. **Mandatory** in both modes |
| Input | `SRCTYPE` | Source type, must be a valid type. **Mandatory** in both modes |
| Input | `SRCCCSID` | CCSID for reading, default `*DFT`. For an IFS file, `*DFT` uses the CCSID tag of the file; an explicit value ignores the tag and converts the raw bytes from that CCSID to the job CCSID with iconv. Not used for source members |
| Output | `TGT` (grouped: file, library, member) replaces `TGTLIB`, `TGTFILE`, `TGTMBR`; see BUILD.md. Meaning of the old rows: `TGTLIB` | Output library (`*SRCLIB` allowed) |
| Output | `TGTFILE` | Output source physical file |
| Output | `TGTIFS` | IFS output **directory** |
| Output | `TGTMBR` | Output member name. **Mandatory** in both modes (`*SRCMBR` allowed) |
| Output | `TGTTYPE` | Output type. Default depends on the converter: `CLLE`, `DSPF`, `RPGLE` |
| Output | `TGTCCSID` | CCSID for writing, default `*DFT` |
| Control | `REPLACE` | `*NO` (default) or `*YES` |
| Control | (none) | The conversion report is always a plain spooled file (section 4.2) |

### 3.1 Location rules

- Each side has exactly one location mode. Input and output modes are independent, so all four combinations (member/member, member/IFS, IFS/member, IFS/IFS) are valid.
- Member mode: `LIB` and `FILE` given, `IFS` empty.
- IFS mode: `IFS` given, `LIB` and `FILE` empty.
- Any other combination (both, neither, partial) is rejected with a message that names the rule.

### 3.2 IFS file name

The IFS file name is always `<IFS directory>/<MBR>.<TYPE>`.

Example: `SRCIFS(/home/manoj/src/) SRCMBR(pgm1) SRCTYPE(RPG36)` resolves to `/home/manoj/src/pgm1.RPG36`.

There is no separate extension parameter. Existing files with other extensions are renamed to match.

### 3.3 Case handling

- `SRCTYPE` and `TGTTYPE` are validated against the type table ignoring case.
- IFS input: try the exact name first. If not found, scan the directory for a case-insensitive match. One match is used. More than one match is an error that lists the candidates.
- IFS output: the existence check, the `REPLACE(*NO)` check, and the same-file guard all compare names ignoring case. New files are created with the member and type as typed.

### 3.4 Validation order

Done once, in the shared service program, so all converters behave identically.

1. Mandatory parameters present (`SRCMBR`, `SRCTYPE`, `TGTMBR`).
2. Type values valid (`SRCTYPE` against the type table, `TGTTYPE` against the type table and the converter's allowed outputs).
3. Location rules (3.1) for input, then for output.
4. Existence: input source must exist and be readable. Output library/file or directory must exist. Output member/file existing is an error unless `REPLACE(*YES)`.
5. Same-file guard: resolved input and resolved output must differ (case-insensitive).
6. CCSID values valid.

The first failure is returned as an escape message from the message file so CL callers can monitor for it.

## 4. Shared service program

One service program (`IAcnvSrv`) holds everything the converters share. Converters never know whether they are reading a member or a stream file.

- `ValidateIO(params): result`: runs section 3.4 and returns two descriptors (source and target) or an error message id.
- `OpenSource(descriptor)`, `ReadLine(handle)`, `CloseSource(handle)`.
- `OpenTarget(descriptor)`, `WriteLine(handle, text)`, `CloseTarget(handle)`.
- Report writer: one record per conversion item with status `CONVERTED`, `ASSUMPTION` or `REVIEW`, plus a reason. Unconverted constructs are emitted into the output as commented blocks, so output is never silently wrong.
- Message handling, logging, valid-type table.

Descriptor fields: mode (member or IFS), resolved library/file/member or resolved full path, type, CCSID, replace flag.

### 4.1 Line handling

- Source members have fixed record length with sequence and date columns. Stream files have variable-length lines.
- Reader: normalizes both to the same line structure (text, original line number, original sequence/date if present).
- Writer: knows the target's usable line width (the data area of the target record, or the constant `C_STMFWIDTH` for stream files, currently 100). Lines that do not fit are **wrapped at a safe point**, never truncated. Trailing blanks are trimmed for stream output.

Safe-point rules (the writer applies the target's own continuation syntax):

- Never break inside a quoted literal, a hex or graphic literal, or an identifier.
- Prefer breaking after a comma that is within 30 characters of the last blank, otherwise after the last blank, searching backwards from the width limit. Breaking before an operator is not done.
- If no safe point exists before the limit (for example a very long literal), break at the first safe point after it and add a report entry with status `REVIEW`. If there is none at all, the line is written as is and reported as `REVIEW`.
- Free-format RPG: statements continue on the next line naturally. Comment lines wrap into additional `//` comment lines.
- CLLE: continuation uses `+` (or `-`) at the end of the line, following CL rules for blanks at the break.
- DDS: columns are fixed, so wrapping does not apply. A value that does not fit is reported as `REVIEW`.

### 4.2 Conversion report

A plain spooled file, written once per run by the shared report writer. It lists the source and target (resolved names or paths), the types, the CCSIDs, and one line per item with status `CONVERTED`, `ASSUMPTION` or `REVIEW` and a reason, followed by a totals section. There are no report destination parameters.

## 5. Converter pipeline

Every converter has the same stages:

1. Read lines through the shared reader.
2. Parse into an intermediate representation, not text-to-text.
3. Map using table-driven rules. Rules are data, not code, so they can be extended or reused (for example by a future TypeScript implementation).
4. Emit through the shared writer.
5. Write the conversion report.

Rules for what must be flagged rather than guessed will be listed per converter (for example `CABxx`, `TAG`/`GOTO`, the RPG cycle, O-specs for `IAcnvFree`).

## 6. Fidelity policy

Start with faithful 1:1 translation. Restructuring (for example `COMP` plus indicators into `if`) is a later, optional pass. Indicator renaming (named indicators via data-flow) is out of scope for v1.

## 7. Naming standards

Follow the `IA` prefix convention used for the COBOL parser programs, adjusted for the IBM i object name limit of 10 characters.

| Object | Name |
|---|---|
| Commands (same name as their programs, upper case) | `IAOCLTOCLE`, `IACNVDSPF`, `IACNVFREE` |
| Programs (source file names, mixed case) | `IAoclToCle`, `IAcnvDspf`, `IAcnvFree` |
| Shared service program | `IAcnvSrv` |
| Library | One library holds all objects. Source never hard-codes its name. |

- All sources use `.sqlrpgle` (a shop requirement: every module is compiled with CRTSQLRPGI). The activation group is set at CRTPGM/CRTSRVPGM, not with `dftactgrp` in a module.
- Procedures are PascalCase verbs (`ValidateIO`, `OpenSource`, `ReadLine`, `WriteLine`).
- Database objects and columns use upper-case names with underscores.

Variable prefixes (RPG is case-insensitive, so letter case of the prefix is cosmetic):

| Prefix | Meaning |
|---|---|
| `l_` | Local variable |
| `g_` | Global (program-level) variable |
| `i_` | Input parameter |
| `o_` | Output parameter |
| `io_` | Input/output parameter |
| `C_` | Constant, upper-case name (for example `C_STMFWIDTH`) |

## 8. Repository layout (proposal)

```
README.md
LICENSE                 (open: license choice)
docs/DESIGN.md
src/                    free-format RPGLE, one folder per module group
  common/               service program source (IAcnvSrv)
  oclcle/               IAoclToCle
  dspf/                 IAcnvDspf
  tofree/               IAcnvFree
cmd/                    command definitions
msg/                    message file source
rules/                  mapping tables (data)
tests/                  sample source members and expected output
```

Build tooling: none for now. The author pulls the repo with Code for IBM i and compiles manually; the manual steps are in [BUILD.md](BUILD.md). A project file and build scripts can be added later without changing the source layout.

## 9. Git workflow

- Single branch: `main`.
- Before every push: fetch `origin`, check for drift, and merge or rebase before pushing. No force pushes.
- Compilation and testing happen on the author's IBM i, after pulling. Compiler messages and test output come back into the conversation so fixes can be pushed.

## 10. VS Code extension (future)

The IFS parameters are the integration point: an extension can upload the open file to a directory, call the command with `SRCIFS`/`TGTIFS`, and read the result back. Keeping mapping rules as data keeps a client-side implementation possible if it is ever wanted.

## 11. Open items

- Library name, to be chosen when the objects are first compiled.
- Whether `CVTRPGSRC` is good enough to use as stage 1 of `IAcnvFree`.
