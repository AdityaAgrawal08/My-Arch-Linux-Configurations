#!/usr/bin/env python3

import os
import sys
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas


OUTPUT_FILE = "final.pdf"
TEMP_TOC = ".__pdfmerge_toc__.pdf"


def get_pdf_files():
    files = []

    for f in sorted(os.listdir(".")):
        path = Path(f)

        if (
            path.is_file()
            and path.suffix.lower() == ".pdf"
            and path.name != OUTPUT_FILE
            and path.name != TEMP_TOC
        ):
            files.append(path)

    return files


def build_toc(entries, toc_pages):
    c = canvas.Canvas(TEMP_TOC, pagesize=A4)

    width, height = A4

    y = height - 50

    c.setFont("Helvetica-Bold", 16)
    c.drawString(50, y, "Table of Contents")

    y -= 35

    c.setFont("Helvetica", 11)

    for name, page in entries:
        actual_page = page + toc_pages

        dots = "." * max(5, 90 - len(name))

        c.drawString(
            50,
            y,
            f"{name} {dots} {actual_page}"
        )

        y -= 18

        if y < 50:
            c.showPage()
            c.setFont("Helvetica", 11)
            y = height - 50

    c.save()


def main():
    files = get_pdf_files()

    if not files:
        print("No PDF files found")
        sys.exit(1)

    pdfs = []
    entries = []

    current_page = 1

    for file in files:
        reader = PdfReader(str(file))

        pdfs.append((file.name, reader))
        entries.append((file.name, current_page))

        current_page += len(reader.pages)

    build_toc(entries, 0)

    toc_pages = len(PdfReader(TEMP_TOC).pages)

    build_toc(entries, toc_pages)

    writer = PdfWriter()

    toc_reader = PdfReader(TEMP_TOC)

    for page in toc_reader.pages:
        writer.add_page(page)

    current_page = len(toc_reader.pages)

    for name, reader in pdfs:
        start_page = current_page

        for page in reader.pages:
            writer.add_page(page)

        writer.add_outline_item(name, start_page)

        current_page += len(reader.pages)

    with open(OUTPUT_FILE, "wb") as f:
        writer.write(f)

    os.remove(TEMP_TOC)

    print(f"{OUTPUT_FILE} created")


if __name__ == "__main__":
    main()
