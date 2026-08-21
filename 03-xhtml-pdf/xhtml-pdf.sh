#!/bin/bash
# xhtml-to-pdf.sh - Convert fixed-layout EPUB to individual PDF pages
# Usage: ./xhtml-to-pdf.sh

set -e

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}      XHTML → PDF Converter for Fixed-Layout EPUBs${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# 1. Ask for the EPUB path
echo -e "${YELLOW}📂 Enter the full path to the EPUB file:${NC}"
read -r EPUB_PATH

# Validate that the file exists
if [ ! -f "$EPUB_PATH" ]; then
  echo -e "${RED}❌ Error: File not found: $EPUB_PATH${NC}"
  exit 1
fi

# Validate it's an EPUB
if [[ ! "$EPUB_PATH" =~ \.epub$ ]]; then
  echo -e "${RED}❌ Error: File must have .epub extension${NC}"
  exit 1
fi

EPUB_BASENAME=$(basename "$EPUB_PATH" .epub)
echo -e "${GREEN}✅ EPUB found: $EPUB_PATH${NC}"
echo ""

# 2. Ask for the output directory
echo -e "${YELLOW}📁 Enter the output directory for PDF files:${NC}"
read -r OUTPUT_DIR

# If nothing is entered, use the current directory
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$PWD"
  echo -e "${YELLOW}⚠️  No directory specified. Using current directory.${NC}"
fi

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Verify it is writable
if [ ! -w "$OUTPUT_DIR" ]; then
  echo -e "${RED}❌ Error: Cannot write to $OUTPUT_DIR${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Output directory: $OUTPUT_DIR${NC}"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}⚠️  This will extract the EPUB and convert all pages to PDF.${NC}"
echo -e "${YELLOW}   Temporary files will be created and cleaned up automatically.${NC}"
echo -e -n "${YELLOW}   Proceed? (y/N): ${NC}"
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo -e "${RED}❌ Aborted.${NC}"
  exit 0
fi

# 3. Create temporary workspace
TEMP_DIR=$(mktemp -d -t xhtml2pdf-XXXXXX)
echo -e "${BLUE}🔧 Creating temporary workspace: $TEMP_DIR${NC}"

# 4. Extract the EPUB
echo -e "${BLUE}📦 Extracting EPUB...${NC}"
unzip -q "$EPUB_PATH" -d "$TEMP_DIR" 2>/dev/null || {
  echo -e "${RED}❌ Error: Failed to extract EPUB${NC}"
  rm -rf "$TEMP_DIR"
  exit 1
}
echo -e "${GREEN}✅ EPUB extracted successfully${NC}"

# 5. Locate the OEBPS folder
OEBPS_DIR=$(find "$TEMP_DIR" -type d -name "OEBPS" | head -1)

if [ -z "$OEBPS_DIR" ]; then
  echo -e "${RED}❌ Error: OEBPS folder not found in EPUB${NC}"
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo -e "${GREEN}✅ OEBPS found: $OEBPS_DIR${NC}"

# 6. Check for a3-fix.css, create if missing
CSS_FILE="$OEBPS_DIR/a3-fix.css"

if [ ! -f "$CSS_FILE" ]; then
  echo -e "${YELLOW}⚠️  a3-fix.css not found. Creating default...${NC}"
  cat > "$CSS_FILE" << 'EOF'
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
EOF
  echo -e "${GREEN}✅ a3-fix.css created${NC}"
fi

# 7. Change to OEBPS directory
cd "$OEBPS_DIR" || {
  echo -e "${RED}❌ Error: Cannot enter OEBPS directory${NC}"
  rm -rf "$TEMP_DIR"
  exit 1
}

# 8. Count XHTML files
XHTML_FILES=(cover.xhtml page*.xhtml)
XHTML_COUNT=${#XHTML_FILES[@]}

if [ "$XHTML_COUNT" -eq 0 ] || [ ! -f "${XHTML_FILES[0]}" ]; then
  echo -e "${RED}❌ Error: No XHTML files found in OEBPS${NC}"
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo -e "${GREEN}✅ Found $XHTML_COUNT XHTML files to process${NC}"
echo ""

# 9. Convert each XHTML to PDF
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔄 Converting XHTML to PDF...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

count=0
for file in cover.xhtml page*.xhtml; do
  if [ ! -f "$file" ]; then
    continue
  fi

  count=$((count + 1))
  echo -e "${GREEN}[$count/$XHTML_COUNT]${NC} Processing: $file"

  wkhtmltopdf --page-size A3 \
    --margin-top 0 \
    --margin-bottom 0 \
    --margin-left 0 \
    --margin-right 0 \
    --disable-smart-shrinking \
    --zoom 1.0 \
    --dpi 150 \
    --enable-local-file-access \
    --allow "$OEBPS_DIR" \
    --no-stop-slow-scripts \
    --user-style-sheet a3-fix.css \
    "$file" "${file%.xhtml}.pdf" 2>/dev/null

  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅${NC} ${file%.xhtml}.pdf generated"
  else
    echo -e "  ${RED}❌${NC} Failed to convert $file"
  fi
done

echo ""

# 10. Move all PDFs to the output directory
echo -e "${BLUE}📦 Moving PDFs to output directory...${NC}"

PDF_COUNT=$(ls *.pdf 2>/dev/null | wc -l)
if [ "$PDF_COUNT" -eq 0 ]; then
  echo -e "${RED}❌ No PDFs generated. Something went wrong.${NC}"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Create a subfolder with the EPUB name in the output directory
FINAL_OUTPUT_DIR="$OUTPUT_DIR/${EPUB_BASENAME}_pdfs"
mkdir -p "$FINAL_OUTPUT_DIR"

mv *.pdf "$FINAL_OUTPUT_DIR/" 2>/dev/null
echo -e "${GREEN}✅ $PDF_COUNT PDFs moved to: $FINAL_OUTPUT_DIR${NC}"

# 11. Clean up temporary directory
echo -e "${BLUE}🧹 Cleaning up temporary files...${NC}"
cd /tmp
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✅ Cleanup complete${NC}"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All done!${NC}"
echo -e "${GREEN}📁 PDFs are in: $FINAL_OUTPUT_DIR${NC}"
echo -e "${GREEN}📄 Total PDFs generated: $PDF_COUNT${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
