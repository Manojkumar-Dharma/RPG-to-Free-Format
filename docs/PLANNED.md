# Planned work

Each item is independent and can be worked in parallel. Keep to the project
rules: `.sqlrpgle` sources, fully free format, lines of 90 columns or less,
descriptive names, V7R3 base. Add or update the matching mapping document in
the same commit. Status values: Planned, In progress, Done.

| ID | Converter | Item | Status |
|----|-----------|------|--------|
| OCL-01 | IAOCLTOCLE | PRINTER, BLDFILE | In progress (written, needs a compile and test) |
| OCL-02 | IAOCLTOCLE | Procedure calls other than LOAD and RUN | In progress (written, needs a compile and test) |
| OCL-03 | IAOCLTOCLE | `?F'...'?` file sizes; DATAF1- and ACTIVE- conditions | Planned |
| OCL-04 | IAOCLTOCLE | WAIT, PAUSE, NOHALT, CANCEL | Planned |
| OCL-05 | IAOCLTOCLE | ATTR, ALLOCATE, DEALLOC, SCRATCH | Planned |
| OCL-06 | IAOCLTOCLE | SESSION, MEMBER, LIBRARY, MRTPROC | Planned |
| OCL-07 | IAOCLTOCLE | PROMPT, HELP, INCLUDE | Planned |
| OCL-08 | IAOCLTOCLE | Explicit SRCCCSID for IFS input | Planned |
| DSP-01 | IACNVDSPF | H (help) specs | Planned |
| DSP-02 | IACNVDSPF | Message fields, array fields, edit codes | Planned |
| DSP-03 | IACNVDSPF | Output indicators on input/output fields | Planned |
| DSP-04 | IACNVDSPF | Confirm assumptions: CFnn(nn) command keys, INDARA and INVITE added, OVRDTA/OVRATR override keywords | Planned |
| DSP-05 | IACNVDSPF | Check the layout against a real QS36SRC DSP36 member (needs a sample from the user) | Planned |
| FREE-01 | IACNVFREE | RPG to fully free format, based on the S/36-compatible RPG II guide (SC09-1818) | Planned |
| FREE-02 | IACNVFREE | Evaluate CVTRPGSRC as stage 1 | Planned |

## Notes

- OCL-01 to OCL-07 add to `docs/OCL-MAPPING.md`; DSP-01 to DSP-05 add to
  `docs/DSPF-MAPPING.md`.
- IACNVFREE reuses the shared parameter set and the IAcnvSrv service program.
- Anything that cannot be converted should be reported for review, not
  dropped silently.
