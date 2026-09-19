# ats-resume-pipeline

A one-page HTML resume that renders to PDF with headless Chrome, plus a check that
reads the PDF the way an applicant-tracking system (ATS) parser actually does, not
just the way it looks on screen.

Most resume templates are designed to look good and never checked against how a
parser extracts their text. This one flips that: the layout rules below exist
specifically because a real parser failed the first version of this resume, for
reasons that were invisible just by looking at the PDF.

## What this is

- `resume.html` - a single-page resume template with a sample fictional person filled
  in, plus a built-in "plain" version. Open it directly and it is the designed page
  (an accent color and a subtle header bar). Open `resume.html#plain` and the exact
  same content renders in black Helvetica with no color, for a portal or a checker
  that strips or objects to styling. There is only one file to keep in sync.
- `render.sh` - renders `resume.html` to two PDFs (the designed one and the plain one)
  with headless Chrome, then runs the parser check against both. It fails loudly if
  either PDF is not exactly one page, or fails the parser check.

## The layout rules, and why each one exists

A real ATS parser does not read a resume the way a person does. Two different
failure modes matter, and `render.sh` checks for both by reading the PDF's text in
plain stream order AND across the page by horizontal position:

- **One column, everywhere.** A position-based parser reads across the page by
  location, not by visual grouping. A two-column layout - a footer with two sections
  side by side, or a name sharing a line with the phone number - comes out of the
  parser as one interleaved line with both columns mixed together. The only things
  allowed to share a line in this template are a role and its dates.
- **Standard section names.** Use Education, Experience, Projects, Skills, Awards,
  Languages. A parser matches these against a fixed list of headings it recognizes;
  a creative heading like "Building" or "Honors" or a combined "Skills & Honors"
  often is not recognized at all, and everything under it gets filed as unstructured
  text.
- **Contact details in the first few lines of the page, as plain text.** Parsers
  typically only look for an email and phone number near the top of the document.
  Put the city, phone number and email on the very first line under the name.
- **Skills as separate, comma-separated terms.** Keyword matching is usually literal
  string matching, so "React/Next.js" may only ever match "React/Next.js" and never
  match a job posting that just says "Next.js". Write each skill as its own term,
  separated by commas.
- **Dates as `Mon YYYY - Mon YYYY` with a plain hyphen.** This is the one exception to
  "nothing shares a line" - a role and its date range may sit side by side, because a
  parser is built to expect a date at the end of an experience line.
- **No CSS `position` on anything that holds text, and heading letter-spacing kept
  small (at or under roughly 1px).** Absolute or relative positioning can move a
  bullet in the rendered PDF's text layer to somewhere far from where it visually
  sits - often to the very end of the document. Wide letter-spacing between
  characters can insert enough space that the extracted text reads "E X P E R I E N
  C E" instead of "EXPERIENCE", which then fails to match the standard heading list.
- **Color is safe.** A text-based parser never sees it. Keep an accent color if you
  want the human reader to see something distinct - it costs nothing on the parsing
  side.

## Start here

You do not need to know how to code to use this. You do need two small pieces of
software installed once:

1. **Google Chrome** (or Chromium on Linux) - used to render the HTML to PDF exactly
   the way a browser would.
2. **`pdftotext`**, part of the free `poppler` toolkit - used to read the PDF's text
   back out, the way a parser would. On a Mac with [Homebrew](https://brew.sh)
   installed, run `brew install poppler`. On Ubuntu or Debian, run
   `sudo apt install poppler-utils`.

Then:

3. Open `resume.html` in a text editor and replace the sample content (the "Sam
   Rivera" placeholder) with your own information, keeping the same section
   structure and one-column layout.
4. From this folder, run:
   ```
   ./render.sh resume.html out/resume.pdf
   ```
5. Read the output. If both checks pass, you will see two lines like:
   ```
   ok: resume.pdf: 1 page, standard headings, one column, bullets in order, contact on top
   ok: resume-plain.pdf: 1 page, standard headings, one column, bullets in order, contact on top
   wrote out/resume.pdf
   wrote out/resume-plain.pdf
   ```
   If a check fails, it names exactly what is wrong (for example, "two things side by
   side" or "heading EXPERIENCE is missing or not alone on its line") so you can go
   fix that spot in the HTML and render again.

By default `render.sh` looks for Chrome at the standard macOS install location, or
for `google-chrome`, `google-chrome-stable`, `chromium-browser` or `chromium` on
Linux. If your browser lives somewhere else, set the `CHROME` environment variable
to its exact path before running the script, for example:
```
CHROME=/usr/bin/chromium ./render.sh resume.html out/resume.pdf
```

## Making the plain version

You do not run anything separate for the plain version - `render.sh` always renders
both from the same `resume.html`, using the file's own `#plain` URL fragment to
switch styling off. If you only want to preview the plain version in a browser
without rendering a PDF, just open `resume.html` and add `#plain` to the address bar.

## License

MIT. See `LICENSE`.

Built by Evan Nalu Foster.
