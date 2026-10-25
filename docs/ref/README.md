# Reference text files

Plain text copies of the IBM manuals used for the converters, so they can be
searched and read without opening the PDFs. Made with
`pdftotext -layout file.pdf file.txt`, then trailing blanks removed. A form
feed character starts each page.

| Text file | PDF in `docs/` | Manual | Used for |
|---|---|---|---|
| `sc091818-rpg2-guide.txt` | `c0918180.pdf` | SC09-1818-00, System/36-Compatible RPG II User's Guide and Reference (June 1994) | Source side of IACNVFREE: column layouts and operation codes |
| `sc091817-rpg400-reference.txt` | `c0918170.pdf` | SC09-1817-00, RPG/400 Reference (June 1994) | Source side of RPG III (RPG/400 and System/38 RPG III): specification layouts (chapters 4 to 10, "Positions" instead of "Columns") and operation codes (chapter 11) |
| `sc091816-rpg400-guide.txt` | `c0918160.pdf` | SC09-1816-00, RPG/400 User's Guide (June 1994) | RPG III programming, CRTRPGPGM, Appendix E: System/38 Environment Option, differences between S/38 RPG III and RPG/400 |
| `sc092508-ile-rpg-reference.txt` | `sc092508.pdf` | ILE RPG Reference, IBM i 7.5 | Target side of IACNVFREE: free-form syntax |
| `sc092507-ile-rpg-programmers-guide.txt` | `sc092507.pdf` | ILE RPG Programmer's Guide, IBM i 7.6 | CVTRPGSRC (Conversion Aid), source member types |

Notes when reading the text:

- Figures and coding forms come out as scattered fragments. The entry tables
  ("Entry / Explanation") and the operation code tables are fine. Open the PDF
  page for anything that depends on a drawing.
- Both ILE RPG manuals are newer than the project's V7R3 base. Their "What's
  New in 7.x" chapters say which release added a feature.
- The older SC41-4730 and SC41-4731 manuals stay as PDFs only.
