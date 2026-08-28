"""PDF merging + image downsizing built on PyMuPDF.

Every page of every source submission is rendered to a JPEG at a chosen DPI
and re-inserted as a full-page image in the output document. This keeps
behavior predictable regardless of how a source PDF was produced (a real
export vs. "screenshot pasted into a doc and printed to PDF"), and gives a
single, reliable knob (dpi + jpeg quality) for controlling final file size.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import pymupdf

logger = logging.getLogger(__name__)


@dataclass
class CompressionSettings:
    dpi: int
    quality: int


def add_cover_page(doc: pymupdf.Document, title: str, subtitle: str = "") -> None:
    page = doc.new_page(width=612, height=792)  # US Letter
    page.insert_text((72, 300), title, fontsize=24, fontname="helv")
    if subtitle:
        page.insert_text((72, 335), subtitle, fontsize=12, fontname="helv", color=(0.35, 0.35, 0.35))


def append_rasterized(doc: pymupdf.Document, src_path: str, settings: CompressionSettings) -> int:
    """Render every page of src_path into doc as a compressed full-page image.

    Returns the number of pages appended.
    """
    src = pymupdf.open(src_path)
    try:
        zoom = settings.dpi / 72
        matrix = pymupdf.Matrix(zoom, zoom)
        pages_added = 0
        for src_page in src:
            pix = src_page.get_pixmap(matrix=matrix, alpha=False)
            jpg_bytes = pix.tobytes("jpg", jpg_quality=settings.quality)
            out_page = doc.new_page(width=src_page.rect.width, height=src_page.rect.height)
            out_page.insert_image(out_page.rect, stream=jpg_bytes)
            pages_added += 1
        return pages_added
    finally:
        src.close()


def build_merged_pdf(
    sections: list[tuple[str, list[str]]],
    settings: CompressionSettings,
    cover_pages: bool,
) -> pymupdf.Document:
    """sections: list of (student_name, [pdf_paths]) in the order they should appear."""
    doc = pymupdf.open()
    for student_name, pdf_paths in sections:
        if cover_pages:
            add_cover_page(doc, student_name, subtitle=f"{len(pdf_paths)} file(s)")
        for path in pdf_paths:
            append_rasterized(doc, path, settings)
    return doc


def save_and_get_size_mb(doc: pymupdf.Document, output_path: str) -> float:
    doc.save(output_path, garbage=4, deflate=True)
    import os

    return os.path.getsize(output_path) / (1024 * 1024)


def build_with_size_cap(
    sections: list[tuple[str, list[str]]],
    output_path: str,
    start_dpi: int,
    start_quality: int,
    cover_pages: bool,
    max_size_mb: float | None,
    min_dpi: int = 72,
    min_quality: int = 25,
    max_attempts: int = 6,
) -> tuple[float, CompressionSettings]:
    """Build the merged PDF, shrinking dpi/quality until it fits under max_size_mb
    (if given) or until the floor settings are reached.

    Returns (final_size_mb, settings_used).
    """
    dpi, quality = start_dpi, start_quality
    for attempt in range(1, max_attempts + 1):
        settings = CompressionSettings(dpi=dpi, quality=quality)
        logger.info("Building merged PDF (attempt %d): dpi=%d quality=%d", attempt, dpi, quality)
        doc = build_merged_pdf(sections, settings, cover_pages)
        try:
            size_mb = save_and_get_size_mb(doc, output_path)
        finally:
            doc.close()
        logger.info("  -> %.1f MB", size_mb)

        if max_size_mb is None or size_mb <= max_size_mb:
            return size_mb, settings
        if dpi <= min_dpi and quality <= min_quality:
            logger.warning(
                "Reached minimum dpi/quality (%d/%d) but file is still %.1f MB (target %.1f MB)",
                min_dpi, min_quality, size_mb, max_size_mb,
            )
            return size_mb, settings

        dpi = max(min_dpi, int(dpi * 0.85))
        quality = max(min_quality, int(quality * 0.85))

    return size_mb, settings
