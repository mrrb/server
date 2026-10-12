"""Extract text from a PDF into a .txt file (pdfplumber).

Params (double-brace placeholders are substituted by run_template):
  input_path    absolute path to the PDF inside /exchange
  output_path   absolute path for the extracted text (e.g. /exchange/outputs/out.txt)

Note: /exchange/outputs is the home of run_template outputs; use save_artifact
to publish anything else you want to keep. Each page's text is separated by a
form feed (\\f) so downstream tools can split pages.
"""

import pdfplumber

INPUT = "{{input_path}}"
OUTPUT = "{{output_path}}"

pages = []
with pdfplumber.open(INPUT) as pdf:
  for page in pdf.pages:
    pages.append(page.extract_text() or "")

with open(OUTPUT, "w", encoding="utf-8") as fh:
  fh.write("\f".join(pages))

print(f"extracted {len(pages)} page(s) -> {OUTPUT}")
