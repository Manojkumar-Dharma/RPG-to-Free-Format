# Planned work

Each item is independent and can be worked in parallel. Keep to the project
rules: `.sqlrpgle` sources, fully free format, lines of 90 columns or less,
descriptive names, V7R3 base. Add or update the matching mapping document in
the same commit. Status values: Planned, In progress, Done.

| ID | Converter | Item | Status |
|----|-----------|------|--------|
| OCL-01 | IAOCLTOCLE | PRINTER, BLDFILE | In progress (written, needs a compile and test) |
| OCL-02 | IAOCLTOCLE | Procedure calls other than LOAD and RUN | In progress (written, needs a compile and test) |
| OCL-03 | IAOCLTOCLE | `?F'...'?` file sizes; DATAF1- and ACTIVE- conditions | In progress (`?F'A,..'?`, DATAF1 and ACTIVE written, need a compile and test) |
| OCL-09 | IAOCLTOCLE | Open items from OCL-03: `?F'S,..'?` written as initial records (field name PHRCDC to verify), DATAF1 date form (DATAF1 `'name,ALL'` is written, needs a compile and test) | In progress |
| OCL-04 | IAOCLTOCLE | WAIT, PAUSE, NOHALT, CANCEL | In progress (written, needs a compile and test; `CANCEL PRT,...` for spool entries moved to OCL-10) |
| OCL-05 | IAOCLTOCLE | ATTR, ALLOCATE, DEALLOC, SCRATCH | In progress (written, needs a compile and test; device names and priorities are untested constants) |
| OCL-06 | IAOCLTOCLE | SESSION, MEMBER, LIBRARY, MRTPROC | In progress (LIBRARY, SESSION for APPC and MRTPROC calls written, need a compile and test; MEMBER is part of OCL-11; MRTPROC is a sample procedure name, not a statement) |
| OCL-07 | IAOCLTOCLE | PROMPT, HELP, INCLUDE | In progress (INCLUDE written as a procedure call, needs a compile and test; PROMPT and HELP reported R; PROMPT conversion waits for a DSPF sample) |
| OCL-08 | IAOCLTOCLE | Explicit SRCCCSID for IFS input (common reader, so it also serves IACNVDSPF) | In progress (written, needs a compile and test) |
| OCL-10 | IAOCLTOCLE | `// CANCEL PRT,...` (spool file entries) | In progress (written, needs a compile and test; printer ID taken as an output queue name, own entries only for ALL and FORMS) |
| OCL-11 | IAOCLTOCLE | `// *` and `// **` message statements, MEMBER, `?Mmic?` expressions | In progress (written, needs a compile and test; the message ID prefix `USR` is assumed, check against a real message file) |
| DSP-01 | IACNVDSPF | H (help) specs | Done (tested) |
| DSP-02 | IACNVDSPF | Message fields, array fields, edit codes | In progress (message fields written as MSGID fields; edit codes written as EDTCDE, needs a compile and test; array fields are WSU only, not supported on the AS/400 and not converted) |
| DSP-03 | IACNVDSPF | Output indicators on input/output fields | In progress (written as two definitions of the field, needs a compile and test: DDS may not allow one name with usage B and I) |
| DSP-04 | IACNVDSPF | Confirm assumptions: CFnn(nn) command keys, INDARA and INVITE added, OVRDTA/OVRATR override keywords | Done (checked against the manuals, see `docs/DSPF-MAPPING.md`; open: `CFnn(nn)` response indicator, `CF` against `CA`, `PUTOVR` and `ERASEINP` behaviour need a compile or display test) |
| DSP-05 | IACNVDSPF | Check the layout against a real QS36SRC DSPF36 member (needs a sample from the user) | Planned |
| DSP-06 | IACNVDSPF | Subfile candidates: detect repeated continuous rows of the same D specifications and report them (status R, output unchanged); subfile DDS (`SFL`, `SFLCTL`) only once a real example shows how the program was changed | Planned (waiting for a DSPF36 member that was converted to a subfile, from the user) |
| FREE-01 | IACNVFREE | RPG to fully free format, based on the S/36-compatible RPG II guide (SC09-1818). Umbrella for FREE-03 to FREE-07; decisions and evidence in `docs/RPG-MAPPING.md` | In progress (decisions made, no code yet) |
| FREE-02 | IACNVFREE | Evaluate CVTRPGSRC as stage 1 | Done (answered from the manual: CVTRPGSRC does not convert RPG36 or RPT36, SC09-2507 Table 125; no stage 1 for RPG36) |
| FREE-03 | IACNVFREE | Command, driver, report; H and F specifications to `ctl-opt` and `dcl-f` (E specifications moved to FREE-07) | In progress (written, needs a compile and test; `samples/FREEHF.rpg36`) |
| FREE-04 | IACNVFREE | I specifications to D statements (rename or data structure, external or internal) | Planned |
| FREE-05 | IACNVFREE | C specifications to free-form calculations (Table 124 and the "Free-Form Syntax" lines of SC09-2508); `TAG`, `GOTO`, `CABxx` reported R | Planned |
| FREE-06 | IACNVFREE | O specifications to an externally described printer file (DDS) and `WRITE`/`EXCEPT` | Planned |
| FREE-07 | IACNVFREE | E specifications (arrays and tables) to `dcl-s`/`dcl-ds`, compile-time data | Planned |

## Notes

- OCL-01 to OCL-07 and OCL-09 to OCL-11 add to `docs/OCL-MAPPING.md`; DSP-01 to DSP-06 add to
  `docs/DSPF-MAPPING.md`.
- FREE-01 to FREE-07 add to `docs/RPG-MAPPING.md`.
- IACNVFREE reuses the shared parameter set and the IAcnvSrv service program.
- Anything that cannot be converted should be reported for review, not
  dropped silently.
