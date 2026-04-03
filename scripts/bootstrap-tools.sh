#!/usr/bin/env bash
set -e

# pdfmerge
if [ ! -d "$HOME/.local/share/pdfmerge/venv" ]; then
    python -m venv "$HOME/.local/share/pdfmerge/venv"
    "$HOME/.local/share/pdfmerge/venv/bin/pip" install reportlab
fi

# pdf2docx
if [ ! -d "$HOME/.local/share/pdf2docx/venv" ]; then
    python -m venv "$HOME/.local/share/pdf2docx/venv"
    "$HOME/.local/share/pdf2docx/venv/bin/pip" install pdf2docx
fi
