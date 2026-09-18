---
name: docx-manipulation
description: Reads, creates, and edits Microsoft Word `.docx` documents with Python `python-docx`, including paragraphs, runs, styles, tables, images, headers, footers, and sections. Use when the user mentions Word automation, document inspection, report generation, or programmatic `.docx` changes.
license: MIT
compatibility: opencode
metadata:
  audience: general
  language: python
---

# DOCX Manipulation

## When to use this skill

Use this skill for Microsoft Word document automation with `python-docx`.
Prefer it when document structure, text formatting, styles, tables, images, headers, footers, or sections matter.
Do not use it for legacy binary `.doc` files.

## Usage

**DO NOT CREATE A NEW SCRIPT!** Use the pre-installed wrapper:

```bash
./docx-manipulation-skill.sh - <<'PY'
from docx import Document

doc = Document()
doc.add_heading("Quarterly Update", level=1)
doc.add_paragraph("Revenue increased by 18%.")
doc.save("output.docx")
PY
```

The wrapper runs Python from the skill-local virtual environment at `./venv/`.
Use `uv`, not `pip` or `python -m venv`, to manage this environment. If `./venv/` is missing, bootstrap it once:

```bash
cd /path/to/docx-manipulation && uv venv venv && uv pip install --python venv/bin/python -r requirements.txt
```

## Workflow

1. Confirm the file type and goal: inspect, transform, restyle, or generate.
2. For existing documents, inspect paragraphs, runs, tables, styles, sections, headers, and footers before editing.
3. Use `Document()` for a new document and `Document(path)` for an existing document.
4. Make focused edits and save to a new path unless the user clearly wants in-place overwrite.
5. Reload the saved document and verify key text, tables, styles, sections, headers, footers, and media relationships.

## Common patterns

```python
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt

doc = Document("report.docx")
for paragraph in doc.paragraphs:
    print(paragraph.style.name, paragraph.text)
for table in doc.tables:
    print([[cell.text for cell in row.cells] for row in table.rows])
heading = doc.add_heading("Results", level=1)
heading.alignment = WD_ALIGN_PARAGRAPH.CENTER
paragraph = doc.add_paragraph()
run = paragraph.add_run("Revenue increased by 18%.")
run.bold = True
run.font.size = Pt(12)
table = doc.add_table(rows=2, cols=2)
table.style = "Light Shading Accent 1"
table.cell(0, 0).text = "Region"
table.cell(0, 1).text = "Sales"
table.cell(1, 0).text = "EMEA"
table.cell(1, 1).text = "$1.2M"
doc.add_picture("chart.png", width=Inches(5.5))
section = doc.sections[0]
section.header.paragraphs[0].text = "Quarterly Update"
section.footer.paragraphs[0].text = "Confidential"
doc.core_properties.title = "Quarterly Update"
doc.save("report-updated.docx")
```

## Important caveats

- `python-docx` supports Word 2007+ `.docx` files, not legacy binary `.doc` files.
- Saving to the same path overwrites the original document without prompting.
- Assigning `paragraph.text` or `cell.text` replaces existing runs and their character-level formatting; edit runs when formatting must be preserved.
- Headers and footers are section-specific and may be linked to the previous section.
- Built-in style names use their English names in the API, even when Word displays localized names.
- Low-level features such as complex numbering, fields, comments, tracked changes, and content controls may require direct XML editing or another tool.
- `python-docx` does not render documents, convert them to PDF, or update fields such as a table of contents.
- Images can be added as inline shapes; floating image positioning is not directly supported by the high-level API.

## Useful APIs

- `Document()`, `doc.paragraphs`, `doc.tables`, `doc.sections`, `doc.styles`, `doc.core_properties`
- `doc.add_heading()`, `doc.add_paragraph()`, `doc.add_table()`, `doc.add_picture()`, `doc.add_section()`
- `paragraph.runs`, `paragraph.add_run()`, `run.font`, `table.rows`, `table.columns`, `table.cell()`
- `section.header`, `section.footer`, `section.top_margin`, `section.orientation`
- `Inches()`, `Cm()`, `Pt()`, `WD_ALIGN_PARAGRAPH`, `WD_SECTION`, `WD_ORIENT`
