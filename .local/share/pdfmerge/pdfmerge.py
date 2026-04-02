#!/usr/bin/env python

import os
import sys
import argparse
from pypdf import PdfReader, PdfWriter
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

parser = argparse.ArgumentParser()
parser.add_argument("dir", nargs="?", default=".")
args = parser.parse_args()

if not os.path.isdir(args.dir):
    print("Invalid directory")
    sys.exit(1)

os.chdir(args.dir)

files = sorted(
    [f for f in os.listdir(".") if f.lower().endswith(".pdf")],
    key=lambda f: os.path.getmtime(f)
)

if not files:
    print("No PDF files found")
    sys.exit(1)

pdfs = []
offsets = []
current_page = 1

for f in files:
    reader = PdfReader(f)
    pdfs.append((f, reader))
    offsets.append((f, current_page))
    current_page += len(reader.pages)

TOC_FILE = "_toc.pdf"

c = canvas.Canvas(TOC_FILE, pagesize=A4)
width, height = A4

y = height - 50
c.setFont("Helvetica-Bold", 14)
c.drawString(50, y, "Table of Contents")

c.setFont("Helvetica", 10)
y -= 30

for name, page in offsets:
    c.drawString(50, y, f"{name} .......... {page + 1}")
    y -= 15
    if y < 50:
        c.showPage()
        y = height - 50

c.save()

writer = PdfWriter()

toc_reader = PdfReader(TOC_FILE)
for p in toc_reader.pages:
    writer.add_page(p)

current_page = len(toc_reader.pages)

for name, reader in pdfs:
    start = current_page
    for p in reader.pages:
        writer.add_page(p)
    writer.add_outline_item(name, start)
    current_page += len(reader.pages)

with open("final.pdf", "wb") as f:
    writer.write(f)

os.remove(TOC_FILE)

print("final.pdf created")
