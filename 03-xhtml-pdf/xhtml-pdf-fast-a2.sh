#!/bin/bash

set -e

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}      XHTML → PDF Converter Fast Converter${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Get EPUB path
echo -e "${YELLOW}📂 Enter EPUB file path:${NC}"
read -r EPUB_PATH

if [ ! -f "$EPUB_PATH" ]; then
  echo -e "${RED}❌ File not found${NC}"
  exit 1
fi

EPUB_BASENAME=$(basename "$EPUB_PATH" .epub)
echo -e "${GREEN}✅ $EPUB_BASENAME${NC}"
echo ""

# Get output directory
echo -e "${YELLOW}📁 Enter output directory (or Enter for current):${NC}"
read -r OUTPUT_DIR
[ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="$PWD"
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}✅ $OUTPUT_DIR${NC}"
echo ""

# Select DPI
echo -e "${YELLOW}🖨️ Select DPI:${NC}"
echo "  1) 96"
echo "  2) 150 (recommended)"
echo "  3) 300"
echo "  4) Custom"
echo -e -n "${YELLOW}Option [1-4]: ${NC}"
read -r DPI_OPTION

case $DPI_OPTION in
  1) DPI="96" ;;
  2) DPI="150" ;;
  3) DPI="300" ;;
  4)
    echo -e "${YELLOW}Enter custom DPI value:${NC}"
    read -r CUSTOM_DPI
    if [[ "$CUSTOM_DPI" =~ ^[0-9]+$ ]] && [ "$CUSTOM_DPI" -gt 0 ]; then
      DPI="$CUSTOM_DPI"
    else
      echo -e "${RED}Invalid. Using 96.${NC}"
      DPI="96"
    fi
    ;;
  *) echo -e "${RED}Invalid. Using 96.${NC}"; DPI="96" ;;
esac

echo -e "${GREEN}✅ DPI: $DPI${NC}"
echo ""
echo -e "${YELLOW}⚠️  Convert to A2 with No Optimisations? (y/N): ${NC}"
read -r CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo -e "${RED}Aborted${NC}" && exit 0

# Extract
TEMP_DIR=$(mktemp -d)
echo -e "${BLUE}📦 Extracting...${NC}"
unzip -q "$EPUB_PATH" -d "$TEMP_DIR"

OEBPS_DIR=$(find "$TEMP_DIR" -type d -name "OEBPS" | head -1)
[ -z "$OEBPS_DIR" ] && echo -e "${RED}❌ OEBPS not found${NC}" && rm -rf "$TEMP_DIR" && exit 1

# Get page order
OPF_FILE=$(find "$OEBPS_DIR" -maxdepth 1 -name "*.opf" | head -1)
[ -z "$OPF_FILE" ] && echo -e "${RED}❌ OPF not found${NC}" && rm -rf "$TEMP_DIR" && exit 1

IDREFS=$(grep -o 'idref="[^"]*"' "$OPF_FILE" | sed 's/idref="\([^"]*\)"/\1/')
[ -z "$IDREFS" ] && IDREFS=$(grep -o "idref='[^']*'" "$OPF_FILE" | sed "s/idref='\([^']*\)'/\1/")

MANIFEST=$(awk '/<manifest>/{flag=1} flag && /<item/{match($0,/id="([^"]*)"/,id);match($0,/href="([^"]*)"/,href);if(id[1]&&href[1])print id[1]"|||"href[1]} /<\/manifest>/{flag=0}' "$OPF_FILE")

XHTML_FILES=""
for id in $IDREFS; do
  href=$(echo "$MANIFEST" | grep "^$id|||" | sed "s/^$id|||//")
  [ -n "$href" ] && [ -f "$OEBPS_DIR/$href" ] && XHTML_FILES="$XHTML_FILES $href"
done

[ -z "$XHTML_FILES" ] && XHTML_FILES=$(ls "$OEBPS_DIR"/*.xhtml 2>/dev/null | sort -V)

read -r -a PAGES <<< "$XHTML_FILES"
TOTAL=${#PAGES[@]}
[ $TOTAL -eq 0 ] && echo -e "${RED}❌ No XHTML files${NC}" && rm -rf "$TEMP_DIR" && exit 1

echo -e "${GREEN}✅ $TOTAL pages found${NC}"
echo ""

# Convert
cd "$OEBPS_DIR"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔄 Converting ($DPI DPI)...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

count=0
for file in "${PAGES[@]}"; do
  count=$((count + 1))
  output=$(printf "page-%03d.pdf" "$count")
  echo -e "${GREEN}[$count/$TOTAL]${NC} $file"

  wkhtmltopdf --page-size A2 \
    --margin-top 0 --margin-bottom 0 --margin-left 0 --margin-right 0 \
    --disable-smart-shrinking --zoom 1.0 --dpi "$DPI" \
    --enable-local-file-access --allow "$OEBPS_DIR" \
    --no-stop-slow-scripts \
    "$file" "$output" 2>/dev/null
done

echo ""

# Move
PDF_COUNT=$(ls *.pdf 2>/dev/null | wc -l)
FINAL_DIR="$OUTPUT_DIR/${EPUB_BASENAME}_A2_${DPI}dpi"
mkdir -p "$FINAL_DIR"
mv *.pdf "$FINAL_DIR/" 2>/dev/null

# Cleanup
cd /tmp
rm -rf "$TEMP_DIR"

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Done!${NC}"
echo -e "${GREEN}📁 $FINAL_DIR${NC}"
echo -e "${GREEN}📄 $PDF_COUNT PDFs @ ${DPI} DPI${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
