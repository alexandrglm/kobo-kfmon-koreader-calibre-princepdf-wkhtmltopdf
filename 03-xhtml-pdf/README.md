# XHTML → PDF Workflow

Tools and stylesheets for converting fixed-layout EPUBs to PDF when PrincePDF cannot handle the rendering correctly.


## When to Use This

Some EPUBs use absolute positioning with `transform: scale()` on text containers (e.g., `scale(0.031242)`).    
PrincePDF does not handle these well so that text disappears or the layout breaks into fragments.

This workflow renders each XHTML page using `wkhtmltopdf`, producing a perfect visual replica of the original page.

Different layouts, DPI, and fixes are supported:

*   A4/A3/A2 page sizes
*   96/150/300/Custom DPI
*   Different pre-defined CSS fixes
*   Custom CSS fixes can be applied

> [!IMPORTANT]
> Generally, it is recommended to test all options before converting a book; each publisher has its own final viewport, orientation, and resolution settings.  
> Although the `no-optimisation` approach often gives the best result, it is advisable to compare before choosing a converting option.


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

Various CSS fixes are included ( [check files here]](./css-fixes) ) with different settings.  
It is also possible to link to a custom CSS file to operate under other conditions.  

## DPI Selection

Now you can choose DPI: **96, 150,300 (or custom values)**.  

> [!IMPORTANT]
> **Wrong DPI is often the cause of broken/missing text.**  
> Increasing the final DPI of the PDF output will not improve the quality of the original illustrations; this is precisely why a test with different DPI values is included.

---

## Usage

The tool offers three modes:

1. **Test** – Tests all 6 approaches × 3 sizes × 3 DPIs on a single page.
2. **Convert** – Converts the full EPUB to PDF with your chosen size, DPI, and approach.
3. **Extract** – Simple extraction of EPUB content (XHTML, CSS, fonts, images).

```bash
./xhtml-pdf.sh
```

For a fast conversion, max. page size (A2) with default CSS fix applied conversion, a `xhtml-pdf-fast-a2.sh` is included.

---

*Updated: *2026, August, 27.*


