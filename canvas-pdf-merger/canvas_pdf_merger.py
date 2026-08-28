#!/usr/bin/env python3
"""Download every PDF submission for one assignment in one Canvas section
and merge them into a single, size-capped PDF for easier grading.

Usage:
    export CANVAS_URL="https://yourschool.instructure.com"
    export CANVAS_TOKEN="1234~abc..."
    python canvas_pdf_merger.py --course-id 12345 --assignment-id 67890 --section-name "Section 02"

See README.md for details.
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

from canvas_client import CanvasAPIError, CanvasClient, StudentSubmission
from pdf_utils import build_with_size_cap

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

logger = logging.getLogger("canvas_pdf_merger")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--url", default=os.environ.get("CANVAS_URL"), help="Canvas base URL, e.g. https://school.instructure.com")
    p.add_argument("--token", default=os.environ.get("CANVAS_TOKEN"), help="Canvas API access token")
    p.add_argument("--course-id", type=int, required=True)
    p.add_argument("--assignment-id", type=int, required=True)

    section = p.add_mutually_exclusive_group(required=True)
    section.add_argument("--section-id", type=int, help="Numeric Canvas section id")
    section.add_argument("--section-name", help="Exact section name (looked up via the Canvas API)")

    p.add_argument("-o", "--output", default="merged_submissions.pdf", help="Output PDF path")
    p.add_argument("--download-dir", default=None, help="Where to cache downloaded submissions (default: ./canvas_downloads/<assignment_id>)")
    p.add_argument("--dpi", type=int, default=150, help="Starting render resolution for screenshots/pages (default: 150)")
    p.add_argument("--quality", type=int, default=60, help="Starting JPEG quality 1-95 (default: 60)")
    p.add_argument("--max-size-mb", type=float, default=None, help="Shrink dpi/quality automatically until the merged file is under this size")
    p.add_argument("--min-dpi", type=int, default=72, help="Floor for automatic shrinking (default: 72)")
    p.add_argument("--min-quality", type=int, default=25, help="Floor for automatic shrinking (default: 25)")
    p.add_argument("--no-cover-pages", action="store_true", help="Don't insert a divider page with the student's name before each submission")
    p.add_argument("--dry-run", action="store_true", help="List what would be downloaded/merged without doing it")
    p.add_argument("-v", "--verbose", action="store_true")
    return p.parse_args(argv)


def sanitize_filename(name: str) -> str:
    return "".join(c if c.isalnum() or c in " ._-" else "_" for c in name).strip()


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO, format="%(levelname)s: %(message)s")

    if not args.url or not args.token:
        logger.error("Canvas URL and API token are required (via --url/--token or CANVAS_URL/CANVAS_TOKEN env vars)")
        return 2

    client = CanvasClient(args.url, args.token)

    try:
        section_id = args.section_id or client.find_section_id(args.course_id, args.section_name)
        logger.info("Fetching submissions for section %s, assignment %s", section_id, args.assignment_id)
        submissions = client.list_section_submissions(section_id, args.assignment_id)
    except CanvasAPIError as exc:
        logger.error("%s", exc)
        return 1

    missing: list[StudentSubmission] = []
    non_pdf: list[tuple[StudentSubmission, str]] = []
    usable: list[StudentSubmission] = []

    for sub in submissions:
        if not sub.has_submission or not sub.attachments:
            missing.append(sub)
            continue
        pdf_attachments = [a for a in sub.attachments if a.is_pdf]
        if not pdf_attachments:
            non_pdf.append((sub, ", ".join(a.filename for a in sub.attachments)))
            continue
        usable.append(sub)

    logger.info(
        "%d students in section: %d with PDF submissions, %d missing/unsubmitted, %d with non-PDF files",
        len(submissions), len(usable), len(missing), len(non_pdf),
    )
    if missing:
        logger.info("Missing/unsubmitted: %s", ", ".join(s.student_name for s in missing))
    if non_pdf:
        for sub, files in non_pdf:
            logger.warning("Skipping %s: no PDF attachment (has: %s)", sub.student_name, files)

    if args.dry_run:
        for sub in usable:
            pdf_names = [a.filename for a in sub.attachments if a.is_pdf]
            logger.info("Would merge %s: %s", sub.student_name, pdf_names)
        logger.info("Dry run complete, nothing downloaded or written.")
        return 0

    if not usable:
        logger.error("No PDF submissions found to merge.")
        return 1

    download_dir = Path(args.download_dir or f"canvas_downloads/{args.assignment_id}")
    download_dir.mkdir(parents=True, exist_ok=True)

    sections: list[tuple[str, list[str]]] = []
    for sub in usable:
        student_dir = download_dir / sanitize_filename(f"{sub.student_name}_{sub.user_id}")
        student_dir.mkdir(parents=True, exist_ok=True)
        local_paths: list[str] = []
        for attachment in sub.attachments:
            if not attachment.is_pdf:
                continue
            dest = student_dir / sanitize_filename(attachment.filename)
            if not dest.exists():
                logger.info("Downloading %s -> %s", attachment.filename, dest)
                client.download_attachment(attachment, str(dest))
            else:
                logger.debug("Using cached %s", dest)
            local_paths.append(str(dest))
        sections.append((sub.student_name, local_paths))

    logger.info("Merging %d submissions into %s", len(sections), args.output)
    size_mb, settings = build_with_size_cap(
        sections=sections,
        output_path=args.output,
        start_dpi=args.dpi,
        start_quality=args.quality,
        cover_pages=not args.no_cover_pages,
        max_size_mb=args.max_size_mb,
        min_dpi=args.min_dpi,
        min_quality=args.min_quality,
    )

    logger.info(
        "Done: %s (%.1f MB, dpi=%d quality=%d, %d students merged)",
        args.output, size_mb, settings.dpi, settings.quality, len(sections),
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
