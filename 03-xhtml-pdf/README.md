## 📁 03-xhtml-pdf/README.md

# XHTML → PDF → CBZ Workflow

Scripts and stylesheets for converting fixed-layout EPUBs to PDF/CBZ when PrincePDF cannot handle the rendering correctly.

## When to Use This

Some EPUBs use absolute positioning with `transform: scale()` on text containers (e.g., `scale(0.031242)`).    
PrincePDF does not handle these well so that text disappears or the layout breaks into fragments.

This workflow renders each XHTML page using `wkhtmltopdf`, producing a perfect visual replica of the original page.

* A3 output gives room to crop later. Use `PDF Arranger` or `ImageMagick` for joining and the final trimmings.

## Prerequisites

- `wkhtmltopdf` (On Debian 13 was deprecated from sources but still available from backports)
```bash
wget -O /tmp/wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb

sudo dpkg -i /tmp/wkhtmltox.deb
sudo apt install -f
```
- A tool to join & crop PDF pages (as, for example, PDF Arranger).

---

## Stylesheet fixes 

- [`a3-fix.css`](./a3-fix.css)

This forces A3 page size with zero margins, white background, while preserving a **1106×1502 px viewport**.

```css
@page {
  size: A3;
  margin: 0 !important;
}

html, body {
  margin: 0 !important;
  padding: 0 !important;
  width: 100% !important;
  height: 100% !important;
  background-color: #FFFFFF !important;
}

.PageContainer {
  background-color: #FFFFFF !important;
  width: 1106px !important;
  height: 1502px !important;
  margin: 0 auto !important;
  padding: 0 !important;
  position: relative !important;
}

img, div, p, span {
  margin: 0 !important;
  padding: 0 !important;
}
```

## Automated processing

```bash
./xhtml-pdf.sh

📂 Enter the full path to the EPUB file:
/home/test.epub
✅ EPUB found: /home/test.epub

📁 Enter the output directory for PDF files:
/home/export/
✅ Output directory: /home/export/

⚠  This will extract the EPUB and convert all pages to PDF.
   Temporary files will be created and cleaned up automatically.
   Proceed? (y/N): y
🔧 Creating temporary workspace: /tmp/xhtml2pdf-YfwaRh
📦 Extracting EPUB...
✅ EPUB extracted successfully
✅ OEBPS found: /tmp/xhtml2pdf-YfwaRh/OEBPS
⚠  print-fix.css not found. Creating default...
✅ print-fix.css created
✅ Found 330 XHTML files to process

════════════════════════════════════════════════════════════
🔄 Converting XHTML to PDF...
════════════════════════════════════════════════════════════
[1/330] Processing: cover.xhtml
  ✅ cover.pdf generated
[2/330] Processing: page002.xhtml
  ✅ page002.pdf generated

...


[330/330] Processing: page330.xhtml
  ✅ page330.pdf generated

📦 Moving PDFs to output directory...
✅ 330 PDFs moved to: /home/export/test_pdfs/
🧹 Cleaning up temporary files...
✅ Cleanup complete

════════════════════════════════════════════════════════════
✅ All done!
📁 PDFs are in: /home/export/test_pdfs/
📄 Total PDFs generated: 330
════════════════════════════════════════════════════════════
```

## Troubleshooting

### "Blocked access to file" errors

Add `--enable-local-file-access` and `--allow /full/path/to/OEBPS/`.

### Content overflows to multiple pages

Use A3 (`--page-size A3`) instead of A4. The original viewport for comics tenf to be **1106×1502 px**; A3 provides enough space.

### Grey background or borders

Ensure `background-color: #FFFFFF !important;` is applied to `html`, `body`, and `.PageContainer`.

### Headers/footers appear

This version of `wkhtmltopdf` does not add headers/footers by default. If they appear, check eaxch xHTML itself.

## Why Not PrincePDF?

PrincePDF is a professional tool, but it struggles with EPUBs that use:

*   `transform: scale()` on text containers
*   Absolute positioning with large coordinate values
*   Custom fonts loaded via `@font-face`

The `wkhtmltopdf` approach renders the page exactly as a browser would, preserving the visual layout including text layers.


