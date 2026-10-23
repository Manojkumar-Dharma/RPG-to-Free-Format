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
| OCL-05 | IAOCLTOCLE | ATTR, ALLOCATE, DEALLOC, SCRATCH | Planned |
| OCL-06 | IAOCLTOCLE | SESSION, MEMBER, LIBRARY, MRTPROC | Planned |
| OCL-07 | IAOCLTOCLE | PROMPT, HELP, INCLUDE | Planned |
| OCL-08 | IAOCLTOCLE | Explicit SRCCCSID for IFS input | Planned |
| OCL-10 | IAOCLTOCLE | `// CANCEL PRT,...` (spool file entries): printer ID mapping and `*JOBCTL` scope to decide | Planned |
| DSP-01 | IACNVDSPF | H (help) specs | Done (tested) |
| DSP-02 | IACNVDSPF | Message fields, array fields, edit codes | In progress (message fields written as MSGID fields; edit codes written as EDTCDE, needs a compile and test; array fields are WSU only, not supported on the AS/400 and not converted) |
| DSP-03 | IACNVDSPF | Output indicators on input/output fields | In progress (written as two definitions of the field, needs a compile and test: DDS may not allow one name with usage B and I) |
| DSP-04 | IACNVDSPF | Confirm assumptions: CFnn(nn) command keys, INDARA and INVITE added, OVRDTA/OVRATR override keywords | Planned |
| DSP-05 | IACNVDSPF | Check the layout against a real QS36SRC DSPF36 member (needs a sample from the user) | Planned |
| FREE-01 | IACNVFREE | RPG to fully free format, based on the S/36-compatible RPG II guide (SC09-1818) | Planned |
| FREE-02 | IACNVFREE | Evaluate CVTRPGSRC as stage 1 | Planned |

## Notes

- OCL-01 to OCL-07, OCL-09 and OCL-10 add to `docs/OCL-MAPPING.md`; DSP-01 to DSP-05 add to
  `docs/DSPF-MAPPING.md`.
- IACNVFREE reuses the shared parameter set and the IAcnvSrv service program.
- Anything that cannot be converted should be reported for review, not
  dropped silently.
