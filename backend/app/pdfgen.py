"""PDF generation for interview preparation packs (fpdf2, Unicode font when available)."""
from __future__ import annotations

import os
from datetime import datetime

from fpdf import FPDF

from .ai import InterviewPrep

_FONT_CANDIDATES = [
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
    ("C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/arialbd.ttf"),
]


def _setup_font(pdf: FPDF) -> str:
    for regular, bold in _FONT_CANDIDATES:
        if os.path.exists(regular) and os.path.exists(bold):
            pdf.add_font("Body", "", regular)
            pdf.add_font("Body", "B", bold)
            return "Body"
    return "helvetica"


def _safe(text: str, font: str) -> str:
    if font != "helvetica":
        return text
    return text.encode("latin-1", "replace").decode("latin-1")


def build_interview_pdf(path: str, title: str, company: str, prep: InterviewPrep) -> str:
    pdf = FPDF(format="A4")
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()
    font = _setup_font(pdf)
    w = pdf.epw

    def h(text: str, size: int = 13) -> None:
        pdf.set_font(font, "B", size)
        pdf.set_text_color(15, 23, 42)
        pdf.multi_cell(w, 7, _safe(text, font))
        pdf.ln(1)

    def p(text: str, size: int = 10) -> None:
        pdf.set_font(font, "", size)
        pdf.set_text_color(51, 65, 85)
        pdf.multi_cell(w, 5.5, _safe(text, font))
        pdf.ln(2)

    pdf.set_fill_color(14, 165, 233)
    pdf.rect(0, 0, 210, 4, "F")
    h("Interview Preparation", 18)
    p(f"{title} — {company}\nGenerated {datetime.now():%Y-%m-%d %H:%M}", 10)

    h("Company overview")
    p(prep.company_overview)
    if prep.logistics:
        h("Logistics")
        p(prep.logistics)
    h("What they will focus on")
    for item in prep.role_focus:
        p(f"•  {item}")
    h("Likely questions & suggested answers")
    for i, qa in enumerate(prep.questions, 1):
        pdf.set_font(font, "B", 10.5)
        pdf.set_text_color(2, 132, 199)
        pdf.multi_cell(w, 5.5, _safe(f"{i}. {qa.question}", font))
        p(qa.suggested_answer)
    h("Questions to ask the interviewer")
    for q in prep.questions_to_ask:
        p(f"•  {q}")
    pdf.output(path)
    return path
