# Canvas Submission PDF Merger

Grabs every PDF submission for one assignment in one section of a Canvas
course, and merges them into a single PDF for easier grading. Since student
submissions are often screenshots dropped into a doc and exported to PDF,
every page is re-rendered and recompressed as it's merged, so the final
file stays a reasonable size even for a large class.

## Setup

```bash
cd canvas-pdf-merger
python3 -m venv .venv && source .venv/bin/activate   # optional
pip install -r requirements.txt
```

Get a Canvas API token: Canvas → **Account** → **Settings** → **+ New Access
Token**. Treat it like a password.

```bash
export CANVAS_URL="https://yourschool.instructure.com"
export CANVAS_TOKEN="1234~your-token"
```

(Or copy `.env.example` to `.env` and fill it in — `python-dotenv` is picked
up automatically if it's installed.)

## Finding the course, assignment, and section IDs

Open the assignment in Canvas and look at the URL:

```
https://yourschool.instructure.com/courses/12345/assignments/67890
                                             ^^^^^               ^^^^^
                                          course id        assignment id
```

For the section, either pass `--section-name "Section 02"` exactly as it
appears on the course's **People** page, or find the numeric id under
**Settings → Sections** (hover a section link) and pass `--section-id`.

## Usage

```bash
python canvas_pdf_merger.py \
  --course-id 12345 \
  --assignment-id 67890 \
  --section-name "Section 02" \
  --output "section02_merged.pdf" \
  --max-size-mb 40
```

Preview who/what would be merged without downloading anything:

```bash
python canvas_pdf_merger.py --course-id 12345 --assignment-id 67890 \
  --section-name "Section 02" --dry-run
```

Downloaded originals are cached under `canvas_downloads/<assignment_id>/`
(by student) so re-running the tool — e.g. to try different compression
settings — doesn't re-download from Canvas.

### Options

| Flag | Default | Description |
|---|---|---|
| `--dpi` | 150 | Starting render resolution for each page |
| `--quality` | 60 | Starting JPEG quality (1-95) |
| `--max-size-mb` | none | If set, dpi/quality are automatically lowered (down to `--min-dpi`/`--min-quality`) until the merged PDF fits |
| `--no-cover-pages` | off | Skip the divider page with each student's name |
| `--download-dir` | `canvas_downloads/<assignment_id>` | Where originals are cached |
| `--dry-run` | off | List students/files without downloading or merging |
| `-v` | off | Verbose logging |

## How it works

1. Calls the Canvas API's section-scoped submissions endpoint
   (`GET /api/v1/sections/:id/assignments/:id/submissions`) to list every
   student in the section and their current submission.
2. Skips students with no submission, and warns about submissions that
   aren't a PDF (reported at the end, nothing is silently dropped).
3. Downloads each PDF attachment.
4. Renders every page to an image at `--dpi` and re-encodes it as a JPEG at
   `--quality`, using [PyMuPDF](https://pymupdf.readthedocs.io/), then
   assembles the pages (with an optional name divider page per student)
   into one output PDF. If `--max-size-mb` is set, it retries with lower
   dpi/quality until the file fits or the floor settings are hit.

## Limitations

- Only handles PDF attachments (per the task: submissions are all PDFs).
  Non-PDF submissions are listed as warnings, not converted.
- Uses each student's current/latest submission, not resubmission history.
- Group assignments aren't specially handled — submissions are merged per
  submitting user as Canvas reports them.
- Rendering every page to an image means merged pages are no longer
  text-searchable/selectable (this is what makes size predictable and
  robust to "screenshot" PDFs); use `--dpi`/`--quality` higher, or drop
  `--max-size-mb`, if you need higher fidelity and file size isn't a concern.
