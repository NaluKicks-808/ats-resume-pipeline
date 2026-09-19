#!/bin/zsh
# Render a resume HTML file to TWO PDFs with headless Chrome: the designed page, and the same page plain
# (black Helvetica, no color) from the file's own #plain switch. Then prove both are one page and both read
# cleanly to an applicant-tracking parser.
# Usage: ./render.sh path/to/resume.html [path/to/output.pdf]      (the plain one lands beside it as <output>-plain.pdf)
set -e
IN="${1:?usage: ./render.sh resume.html [out.pdf]}"
IN_ABS="$(cd "$(dirname "$IN")" && pwd)/$(basename "$IN")"
OUT="${2:-${IN_ABS%.html}.pdf}"
OUT_PLAIN="${OUT%.pdf}-plain.pdf"

# Chrome's binary path. Override with the CHROME environment variable if yours lives
# somewhere else; otherwise this falls back to the usual macOS and Linux locations.
if [ -z "${CHROME:-}" ]; then
  if [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  else
    for candidate in google-chrome google-chrome-stable chromium-browser chromium; do
      if command -v "$candidate" >/dev/null 2>&1; then
        CHROME="$(command -v "$candidate")"
        break
      fi
    done
  fi
fi
if [ -z "${CHROME:-}" ]; then
  echo "Chrome/Chromium not found. Set the CHROME environment variable to your browser's binary path." >&2
  exit 1
fi

"$CHROME" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$OUT" "file://$IN_ABS" 2>/dev/null
"$CHROME" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$OUT_PLAIN" "file://$IN_ABS#plain" 2>/dev/null

command -v pdftotext >/dev/null 2>&1 || { echo "pdftotext is missing (brew install poppler, or apt install poppler-utils): cannot run the parser check"; exit 1; }

# What this check guards against, and why each rule exists:
#   - "position: relative" (or similar) on list items can move every bullet to the END of the
#     text layer instead of leaving it next to the role it belongs under.
#   - wide letter-spacing on headings can turn "EXPERIENCE" into "E X PERIENCE" once the text is
#     extracted, so a parser never recognizes the section.
#   - a two-column layout can pass a check that only reads the text in stream order and still fail
#     a real ATS parser, because a position-based parser reads ACROSS the page: two sections placed
#     side by side come out as one interleaved line. So this check reads the page BOTH ways, and
#     refuses anything side by side except a date sitting next to the role it belongs to.
for PDF in "$OUT" "$OUT_PLAIN"; do
python3 - "$PDF" <<'PY'
import re, subprocess, sys
pdf = sys.argv[1]
raw = pdf_bytes = open(pdf, 'rb').read()
pages = len(re.findall(rb'/Type\s*/Page[^s]', pdf_bytes))
name = pdf.split('/')[-1]
fails = []
if pages != 1:
    fails.append(f"{pages} pages: trim and render again")
stream = subprocess.run(['pdftotext', pdf, '-'], capture_output=True, text=True).stdout.splitlines()
layout = subprocess.run(['pdftotext', '-layout', pdf, '-'], capture_output=True, text=True).stdout.splitlines()
DATE = re.compile(r'((19|20)\d\d|Present|Expected)')

# 1. Standard headings a parser files things under, each alone on its own line when read across the page.
lines_across = [l.strip() for l in layout]
for h in ('EDUCATION', 'EXPERIENCE', 'SKILLS'):
    if h not in lines_across:
        fails.append(f"heading {h} is missing or not alone on its line")
for bad, good in (('BUILDING', 'SKILLS'), ('HONORS', 'AWARDS'), ('SKILLS & HONORS', 'SKILLS and AWARDS as two sections')):
    if bad in lines_across:
        fails.append(f"heading {bad} is not one a parser recognizes: use {good}")

# 2. One column. Read across the page, the only thing allowed to sit beside other text is a date.
for l in layout:
    parts = [p for p in re.split(r'\s{3,}', l.strip()) if p]
    if len(parts) > 1 and not DATE.search(parts[-1]):
        fails.append("two things side by side: " + ' || '.join(parts)[:150])

# 3. Reading order in the text stream: bullets sit between the role headers, not after all of them.
dated = [i for i, l in enumerate(stream) if re.search(r'(19|20)\d\d\s*[-–]\s*((19|20)\d\d|Present|[A-Z][a-z]{2} (19|20)\d\d)', l)]
if len(dated) >= 2 and not any(len(l) > 80 for l in stream[dated[0]:dated[-1]]):
    fails.append("no bullet text between the first and last dated role: the bullets have drifted to the end of the text layer")

# 4. Contact details where a parser looks for them: in the first lines of the page, as plain text.
top = ' '.join([l for l in stream if l.strip()][:6])
if not re.search(r'[\w.+-]+@[\w-]+\.\w+', top): fails.append("no email in the first lines of the page")
if not re.search(r'\d{3}[-.\s]\d{3}[-.\s]\d{4}', top): fails.append("no phone number in the first lines of the page")

if fails:
    print(f"PARSER CHECK FAILED: {name}")
    for f in fails: print("  - " + f)
    sys.exit(1)
print(f"ok: {name}: 1 page, standard headings, one column, bullets in order, contact on top")
PY
done
echo "wrote $OUT"
echo "wrote $OUT_PLAIN"
