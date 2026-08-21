# PrincePDF Plugin Collection

This directory contains the PrincePDF plugin and its installer for Calibre.

## Contents

* `prince_pdf-1.6.0.zip` - [Calibre GUI plugin for PrinceXML](https://www.mobileread.com/forums/showthread.php?t=230027)
* `prince_16.2-1_debian13_amd64.deb` - PrinceXML engine installer for Debian 13 (Trixie) and compatibles (Official [link](https://www.princexml.com/download/16/) )

## Installation

1.   Install the PrinceXML engine:

   ```bash
   sudo dpkg -i prince_16.2-1_debian13_amd64.deb
   sudo apt install -f
   ```

2.   In Calibre, go to **Preferences → Plugins → Load plugin from file** and select `prince_pdf-1.6.0.zip`.

3.   Restart Calibre and locate the PrincePDF button in the toolbar.

---

## Custom Stylesheet

### Case 1:  Comic, A4, **no fonts embedded++

This example stylesheet was used for a fixed-layout comic EPUB (**1106×1502 px viewport**).  
It forces A4 output with zero margins and ensures the content fills the page.

```css
/*
 * prince-fix.css - Force A4, zero margins, content at 100%
 * Used for fixed-layout EPUBs where PrincePDF fails to scale correctly.
 */

@page {
  size: A4;
  margin: 0 !important;
}

@page:first {
  margin: 0 !important;
  @top-left { content: normal; }
  @top-center { content: normal; }
  @top-right { content: normal; }
  @bottom-left { content: normal; }
  @bottom-center { content: normal; }
  @bottom-right { content: normal; }
}

html, body {
  margin: 0 !important;
  padding: 0 !important;
  width: 100% !important;
  height: 100% !important;
  background: #FFFFFF !important;
}

.PageContainer {
  background: #FFFFFF !important;
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

### Case 2:  Comic, A3, no fonts embedded

This example stylesheet was used for a fixed-layout comic EPUB (1106×1502 px viewport) where the content does not fit on A4.  

By forcing A3 output, the entire page is rendered without clipping.   
The watermark (if any from PrincePDF) or any extra whitespace can later be removed using PDF Arranger or pdfcrop in batch mode.  

```css
/*
 * prince-fix-a3.css - Force A3, zero margins, content at 100%
 * Used for fixed-layout EPUBs that overflow A4.
 * Output is A3, leaving room for manual cropping later.
 */

@page {
  size: A3;
  margin: 0 !important;
}

@page:first {
  margin: 0 !important;
  @top-left { content: normal; }
  @top-center { content: normal; }
  @top-right { content: normal; }
  @bottom-left { content: normal; }
  @bottom-center { content: normal; }
  @bottom-right { content: normal; }
}

html, body {
  margin: 0 !important;
  padding: 0 !important;
  width: 100% !important;
  height: 100% !important;
  background: #FFFFFF !important;
}

.PageContainer {
  background: #FFFFFF !important;
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

## Notes

* For complex fixed-layout EPUBs (especially those with text layers), PrincePDF may fail to render correctly.  
  Check the [03 - XHTML to PDF](../03-xhtml-pdf/)` directory for an alternative approach.

## License

PrinceXML is proprietary. The plugin is open-source (GPL). Respect both licences.
