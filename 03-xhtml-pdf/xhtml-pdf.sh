#!/bin/sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# vars
CURRENT_EPUB=""
CURRENT_EPUB_NAME=""
CURRENT_OEBPS=""
TEMP_DIR=""
OPF_FILE=""
EPUB_LIST_FILE=""
CUSTOM_CSS=""
SELECTED_FILE=""

# CLI flags
CLI_MODE=""
CLI_INPUT=""
CLI_OUTPUT=""
CLI_SIZE=""
CLI_APPROACH=""
CLI_CSS=""
CLI_PAGE=""
CLI_YES=0
CLI_RUN=0


# Inner Funcs

_cleanup_temp() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        cd / 2>/dev/null
        rm -rf "$TEMP_DIR" 2>/dev/null
        TEMP_DIR=""
    fi
}

_cleanup_list() {
    if [ -n "$EPUB_LIST_FILE" ] && [ -f "$EPUB_LIST_FILE" ]; then
        rm -f "$EPUB_LIST_FILE" 2>/dev/null
        EPUB_LIST_FILE=""
    fi
}

_clean_vars() {
    _cleanup_temp
    _cleanup_list
    CURRENT_EPUB=""
    CURRENT_EPUB_NAME=""
    CURRENT_OEBPS=""
    OPF_FILE=""
    CUSTOM_CSS=""
    SELECTED_FILE=""
}

# Trap signals
trap _clean_vars EXIT INT TERM


# CSS TYPES (as heredocs)
_write_css_original() {
    local size="$1"
    local output="$2"
    cat > "$output" << EOF
@page {
  size: $size;
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
}

_write_css_force_dimensions() {
    local size="$1"
    local output="$2"
    cat > "$output" << EOF
@page {
  size: $size;
  margin: 0;
}
html, body {
  margin:0;
  padding:0;
  width:100%;
  height:100%;
  overflow:hidden;
}
.PageContainer {
  width:100% !important;
  height:100% !important;
  position:relative !important;
  margin:0 !important;
  padding:0 !important;
}
.PageContainer * {
  position:relative !important;
  margin:0 !important;
  padding:0 !important;
}
EOF
}

_write_css_force_margins() {
    local size="$1"
    local output="$2"
    cat > "$output" << EOF
@page {
  size: $size;
  margin: 0;
}
html, body {
  margin:0 !important;
  padding:0 !important;
  width:100% !important;
  height:100% !important;
}
.PageContainer {
  margin:0 !important;
  padding:0 !important;
  width:100% !important;
  height:100% !important;
}
.PageContainer div, .PageContainer p, .PageContainer span {
  margin:0 !important;
  padding:0 !important;
}
EOF
}


# menu, size - type - dpi - custom,s
_interactive_mode() {
    local xhtml_list="$1"
    local xhtml_count=$(echo "$xhtml_list" | wc -l | tr -d ' ')

    echo ""
    echo "${BLUE}📋 XHTML files in reading order:${NC}"

    count=0
    for file in $xhtml_list; do
        count=$((count + 1))
        if [ $count -le 20 ]; then
            echo "  ${GREEN}$count.${NC} $file"
        else
            if [ $count -eq 21 ]; then
                echo "  ${YELLOW}... ($((xhtml_count - 20)) more files)${NC}"
            fi
        fi
    done

    echo ""
    echo "${YELLOW}Select page number to test (1-$xhtml_count):${NC}"
    read -r page_num

    case $page_num in
        ''|*[!0-9]*)
            echo "${RED}❌ Invalid selection (not a number)${NC}" >&2
            return 1
            ;;
        *)
            if [ "$page_num" -lt 1 ] || [ "$page_num" -gt "$xhtml_count" ]; then
                echo "${RED}❌ Invalid selection${NC}" >&2
                return 1
            fi
            ;;
    esac

    SELECTED_FILE=""
    count=0
    for file in $xhtml_list; do
        count=$((count + 1))
        if [ "$count" -eq "$page_num" ]; then
            SELECTED_FILE="$file"
            break
        fi
    done

    if [ -z "$SELECTED_FILE" ]; then
        echo "${RED}❌ Error: Could not select file${NC}" >&2
        return 1
    fi

    echo "${GREEN}✅ Selected: $SELECTED_FILE${NC}"
    return 0
}


# custo css
_get_custom_css_interactive() {
    echo "${YELLOW}📄 Enter path to custom CSS file:${NC}"
    read -r CSS_PATH

    if [ -z "$CSS_PATH" ]; then
        echo "${RED}❌ Error: No CSS path provided${NC}"
        return 1
    fi

    if [ ! -f "$CSS_PATH" ]; then
        echo "${RED}❌ Error: CSS file not found: $CSS_PATH${NC}"
        return 1
    fi

    CUSTOM_CSS="$CSS_PATH"
    echo "${GREEN}✅ Custom CSS loaded: $CSS_PATH${NC}"
    return 0
}



# EPUB PATHS FILENAME funcs
get_epubs() {
    local input_path="$1"
    local tempfile="${TMPDIR:-/tmp}/epub-list-$$.tmp"

    rm -f "$tempfile" 2>/dev/null

    if [ -z "$input_path" ]; then
        echo "ERROR: No path provided" >&2
        return 1
    fi

    if [ -f "$input_path" ] && echo "$input_path" | grep -q '\.epub$'; then
        echo "$input_path" > "$tempfile"
    elif [ -d "$input_path" ]; then
        cd "$input_path" 2>/dev/null || {
            echo "ERROR: Cannot access directory: $input_path" >&2
            return 1
        }

        for f in *.epub; do
            if [ -f "$f" ]; then
                echo "$input_path/$f" >> "$tempfile"
            fi
        done

        cd - >/dev/null 2>&1

        if [ ! -s "$tempfile" ]; then
            echo "ERROR: No EPUB files found in directory" >&2
            rm -f "$tempfile" 2>/dev/null
            return 1
        fi
    else
        echo "ERROR: Path does not exist or is not valid: $input_path" >&2
        rm -f "$tempfile" 2>/dev/null
        return 1
    fi

    count=$(wc -l < "$tempfile" 2>/dev/null | tr -d ' ')
    echo "✅ Found $count EPUB file(s)" >&2

    if [ "$count" -gt 0 ] && [ "$count" -le 10 ]; then
        echo "📋 Files:" >&2
        while IFS= read -r file; do
            [ -n "$file" ] && echo "  • $(basename "$file")" >&2
        done < "$tempfile"
    elif [ "$count" -gt 10 ]; then
        echo "📋 First 10 files:" >&2
        head -10 "$tempfile" | while IFS= read -r file; do
            [ -n "$file" ] && echo "  • $(basename "$file")" >&2
        done
        echo "  ... and $((count - 10)) more" >&2
    fi

    echo "$tempfile"
    return 0
}

# EPUB extracion
extract_epub() {
    local epub_path="$1"

    if [ -z "$epub_path" ] || [ ! -f "$epub_path" ]; then
        echo "❌ Error: Invalid EPUB path" >&2
        return 1
    fi

    _cleanup_temp

    TEMP_DIR=$(mktemp -d -t epub-toolkit-XXXXXX 2>/dev/null || mktemp -d)
    echo "🔧 Extracting to: $TEMP_DIR" >&2

    unzip -q "$epub_path" -d "$TEMP_DIR" 2>/dev/null || {
        echo "❌ Error: Failed to extract EPUB" >&2
        _cleanup_temp
        return 1
    }

    CURRENT_OEBPS=$(find "$TEMP_DIR" -type d -name "OEBPS" 2>/dev/null | head -1)

    if [ -z "$CURRENT_OEBPS" ]; then
        CURRENT_OEBPS=$(find "$TEMP_DIR" -maxdepth 2 -type d -name "OEBPS" 2>/dev/null | head -1)
    fi

    if [ -z "$CURRENT_OEBPS" ]; then
        echo "❌ Error: OEBPS folder not found" >&2
        _cleanup_temp
        return 1
    fi

    OPF_FILE=$(find "$CURRENT_OEBPS" -maxdepth 1 -name "*.opf" 2>/dev/null | head -1)

    if [ -z "$OPF_FILE" ]; then
        OPF_FILE=$(find "$TEMP_DIR" -name "*.opf" 2>/dev/null | head -1)
    fi

    if [ -z "$OPF_FILE" ] || [ ! -f "$OPF_FILE" ]; then
        echo "❌ Error: OPF file not found" >&2
        _cleanup_temp
        return 1
    fi

    CURRENT_EPUB="$epub_path"
    CURRENT_EPUB_NAME=$(basename "$epub_path" .epub)

    echo "✅ EPUB extracted successfully" >&2
    echo "📁 OEBPS: $CURRENT_OEBPS" >&2
    echo "📄 OPF: $(basename "$OPF_FILE")" >&2
    return 0
}


# .opf FUNCS
get_xhtml_order_from_opf() {
    local opf_file="$1"
    local oebps_dir="$2"
    local temp_list="${TMPDIR:-/tmp}/xhtml-list-$$.tmp"

    rm -f "$temp_list" 2>/dev/null

    if [ -z "$opf_file" ] || [ ! -f "$opf_file" ]; then
        echo "❌ Error: OPF file not found" >&2
        return 1
    fi

    idrefs=$(grep -o 'idref="[^"]*"' "$opf_file" 2>/dev/null | sed 's/idref="\([^"]*\)"/\1/')

    if [ -z "$idrefs" ]; then
        idrefs=$(grep -o "idref='[^']*'" "$opf_file" 2>/dev/null | sed "s/idref='\([^']*\)'/\1/")
    fi

    if [ -z "$idrefs" ]; then
        echo "⚠️  No idrefs found. Using all XHTML files." >&2
        cd "$oebps_dir" 2>/dev/null || return 1
        for f in *.xhtml; do
            if [ -f "$f" ]; then
                echo "$f" >> "$temp_list"
            fi
        done
        cd - >/dev/null 2>&1

        if [ -s "$temp_list" ]; then
            cat "$temp_list"
            rm -f "$temp_list" 2>/dev/null
            return 0
        else
            rm -f "$temp_list" 2>/dev/null
            return 1
        fi
    fi

    manifest_map=$(awk '
        /<manifest>/ { in_manifest=1 }
        in_manifest && /<item/ {
            match($0, /id="([^"]*)"/, id)
            match($0, /href="([^"]*)"/, href)
            if (id[1] && href[1]) {
                print id[1] "|||" href[1]
            }
        }
        /<\/manifest>/ { in_manifest=0 }
    ' "$opf_file")

    for idref in $idrefs; do
        href=$(echo "$manifest_map" | grep "^$idref|||" | sed "s/^$idref|||//")
        if [ -n "$href" ]; then
            if echo "$href" | grep -q '\.xhtml$' || echo "$href" | grep -q '\.html$'; then
                if [ -f "$oebps_dir/$href" ]; then
                    echo "$href" >> "$temp_list"
                fi
            fi
        fi
    done

    if [ ! -s "$temp_list" ]; then
        echo "⚠️  Could not parse OPF. Using all XHTML files." >&2
        cd "$oebps_dir" 2>/dev/null || return 1
        for f in *.xhtml; do
            if [ -f "$f" ]; then
                echo "$f" >> "$temp_list"
            fi
        done
        cd - >/dev/null 2>&1
    fi

    if [ -s "$temp_list" ]; then
        cat "$temp_list"
        rm -f "$temp_list" 2>/dev/null
        return 0
    else
        rm -f "$temp_list" 2>/dev/null
        return 1
    fi
}




# CONVERTER
_convert_page() {
    local file="$1"
    local css_file="$2"
    local size="$3"
    local dpi="$4"
    local use_wrapper="$5"
    local output_name="$6"

    CMD="wkhtmltopdf --page-size $size"
    CMD="$CMD --margin-top 0 --margin-bottom 0 --margin-left 0 --margin-right 0"
    CMD="$CMD --disable-smart-shrinking --zoom 1.0 --enable-local-file-access"
    CMD="$CMD --no-stop-slow-scripts --dpi $dpi"

    if [ -n "$css_file" ] && [ -f "$CURRENT_OEBPS/$css_file" ]; then
        CMD="$CMD --user-style-sheet $CURRENT_OEBPS/$css_file"
    fi

    CMD="$CMD --allow $CURRENT_OEBPS"

    if [ "$use_wrapper" -eq 1 ]; then
        cat > "wrapper_$$.html" << 'EOF'
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=1106">
<style>@page{size: A3;margin:0}html,body{margin:0;padding:0;width:1106px;height:1502px;overflow:hidden}
</style></head><body>
EOF
        sed "s/A3/$size/g" "wrapper_$$.html" > "wrapper_$$.tmp"
        mv "wrapper_$$.tmp" "wrapper_$$.html"

        sed -n '/<body>/,/<\/body>/p' "$file" | sed '1d;$d' >> "wrapper_$$.html"
        echo '</body></html>' >> "wrapper_$$.html"

        eval "$CMD wrapper_$$.html \"$output_name\"" 2>/dev/null
        local result=$?
        rm -f "wrapper_$$.html" 2>/dev/null
        return $result
    else
        eval "$CMD \"$file\" \"$output_name\"" 2>/dev/null
        return $?
    fi
}





# ACTIONS
_action_test_approaches() {
    local epub_path="$1"
    local page_num="$2"
    local output_dir="$3"

    if [ -z "$epub_path" ] || [ ! -f "$epub_path" ]; then
        echo "${RED}❌ Error: Invalid EPUB file: $epub_path${NC}"
        return 1
    fi

    _clean_vars

    if ! extract_epub "$epub_path"; then
        return 1
    fi

    cd "$CURRENT_OEBPS" 2>/dev/null || return 1

    XHTML_LIST=$(get_xhtml_order_from_opf "$OPF_FILE" "$CURRENT_OEBPS")

    if [ -z "$XHTML_LIST" ]; then
        echo "${RED}❌ Error: No XHTML files found${NC}"
        _cleanup_temp
        return 1
    fi

    # Select page
    if [ -n "$page_num" ]; then
        # CLI mode - page already selected
        count=0
        SELECTED_FILE=""
        for file in $XHTML_LIST; do
            count=$((count + 1))
            if [ "$count" -eq "$page_num" ]; then
                SELECTED_FILE="$file"
                break
            fi
        done
        if [ -z "$SELECTED_FILE" ]; then
            echo "${RED}❌ Error: Page $page_num not found${NC}"
            _cleanup_temp
            return 1
        fi
        echo "${GREEN}✅ Selected: $SELECTED_FILE${NC}"
    else
        # Interactive mode
        if ! _interactive_mode "$XHTML_LIST"; then
            _cleanup_temp
            return 1
        fi
        echo "${GREEN}✅ Selected: $SELECTED_FILE${NC}"
        echo ""
    fi

    # Set output directory
    if [ -z "$output_dir" ]; then
        EPUB_DIR=$(dirname "$CURRENT_EPUB")
        PAGE_NAME=$(echo "$SELECTED_FILE" | sed 's/\.[^.]*$//')
        TEST_FOLDER_NAME="test_${PAGE_NAME}_${CURRENT_EPUB_NAME}"
        output_dir="${EPUB_DIR}/${TEST_FOLDER_NAME}"
    fi

    mkdir -p "$output_dir" 2>/dev/null
    echo "${BLUE}📁 Test output: $output_dir${NC}"
    echo ""

    # DPI values to test
    DPI_VALUES="96 150 300"

    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}🔄 Generating test PDFs (6 approaches × 3 sizes × 3 DPIs)...${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""

    for size in A4 A3 A2; do
        for dpi in $DPI_VALUES; do
            echo "${YELLOW}Testing size: $size - DPI: $dpi${NC}"

            # Approach 1: Original CSS
            css_file="approach-1-${size}.css"
            _write_css_original "$size" "$css_file"
            _convert_page "$SELECTED_FILE" "$css_file" "$size" "$dpi" 0 "$output_dir/${size}-${dpi}dpi-1-original.pdf"
            if [ $? -eq 0 ] && [ -f "$output_dir/${size}-${dpi}dpi-1-original.pdf" ] && [ -s "$output_dir/${size}-${dpi}dpi-1-original.pdf" ]; then
                echo "  ${GREEN}✓${NC} Approach 1: Original CSS"
            else
                echo "  ${RED}✗${NC} Approach 1: Original CSS"
            fi
            rm -f "$css_file" 2>/dev/null

            # Approach 2: High Resolution (usa original.css + DPI 300 fijo)
            # NOTA: Este approach siempre usa 300 DPI, independientemente del bucle
            if [ "$dpi" -eq 300 ]; then
                css_file="approach-2-${size}.css"
                _write_css_original "$size" "$css_file"
                _convert_page "$SELECTED_FILE" "$css_file" "$size" "300" 0 "$output_dir/${size}-300dpi-2-high-resolution.pdf"
                if [ $? -eq 0 ] && [ -f "$output_dir/${size}-300dpi-2-high-resolution.pdf" ] && [ -s "$output_dir/${size}-300dpi-2-high-resolution.pdf" ]; then
                    echo "  ${GREEN}✓${NC} Approach 2: High Resolution (300 DPI)"
                else
                    echo "  ${RED}✗${NC} Approach 2: High Resolution (300 DPI)"
                fi
                rm -f "$css_file" 2>/dev/null
            fi

            # Approach 3: No Optimisations (sin CSS)
            _convert_page "$SELECTED_FILE" "" "$size" "$dpi" 0 "$output_dir/${size}-${dpi}dpi-3-no-optimisations.pdf"
            if [ $? -eq 0 ] && [ -f "$output_dir/${size}-${dpi}dpi-3-no-optimisations.pdf" ] && [ -s "$output_dir/${size}-${dpi}dpi-3-no-optimisations.pdf" ]; then
                echo "  ${GREEN}✓${NC} Approach 3: No Optimisations"
            else
                echo "  ${RED}✗${NC} Approach 3: No Optimisations"
            fi

            # Approach 4: Force Dimensions
            css_file="approach-4-${size}.css"
            _write_css_force_dimensions "$size" "$css_file"
            _convert_page "$SELECTED_FILE" "$css_file" "$size" "$dpi" 0 "$output_dir/${size}-${dpi}dpi-4-force-dimensions.pdf"
            if [ $? -eq 0 ] && [ -f "$output_dir/${size}-${dpi}dpi-4-force-dimensions.pdf" ] && [ -s "$output_dir/${size}-${dpi}dpi-4-force-dimensions.pdf" ]; then
                echo "  ${GREEN}✓${NC} Approach 4: Force Dimensions"
            else
                echo "  ${RED}✗${NC} Approach 4: Force Dimensions"
            fi
            rm -f "$css_file" 2>/dev/null

            # Approach 5: Viewport (wrapper HTML)
            _convert_page "$SELECTED_FILE" "" "$size" "$dpi" 1 "$output_dir/${size}-${dpi}dpi-5-viewport.pdf"
            if [ $? -eq 0 ] && [ -f "$output_dir/${size}-${dpi}dpi-5-viewport.pdf" ] && [ -s "$output_dir/${size}-${dpi}dpi-5-viewport.pdf" ]; then
                echo "  ${GREEN}✓${NC} Approach 5: Viewport"
            else
                echo "  ${RED}✗${NC} Approach 5: Viewport"
            fi

            # Approach 6: Force Margins
            css_file="approach-6-${size}.css"
            _write_css_force_margins "$size" "$css_file"
            _convert_page "$SELECTED_FILE" "$css_file" "$size" "$dpi" 0 "$output_dir/${size}-${dpi}dpi-6-force-margins.pdf"
            if [ $? -eq 0 ] && [ -f "$output_dir/${size}-${dpi}dpi-6-force-margins.pdf" ] && [ -s "$output_dir/${size}-${dpi}dpi-6-force-margins.pdf" ]; then
                echo "  ${GREEN}✓${NC} Approach 6: Force Margins"
            else
                echo "  ${RED}✗${NC} Approach 6: Force Margins"
            fi
            rm -f "$css_file" 2>/dev/null

            echo ""
        done
    done

    echo "${GREEN}✅ All tests completed!${NC}"
    echo ""
    echo "${BLUE}📁 Test PDFs are in: $output_dir${NC}"
    echo ""
    echo "${YELLOW}📊 Summary:${NC}"
    ls -la "$output_dir"/*.pdf 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes)"}' | sed 's/.*\///'
    echo ""
    echo "${YELLOW}🔍 Review the PDFs and note the approach number (1-6), size (A4/A3/A2) and DPI${NC}"
    echo "${YELLOW}   that works best for this book.${NC}"

    _cleanup_temp
    return 0
}

_action_test_custom_css() {
    local epub_path="$1"
    local css_path="$2"
    local page_num="$3"
    local output_dir="$4"

    if [ -z "$epub_path" ] || [ ! -f "$epub_path" ]; then
        echo "${RED}❌ Error: Invalid EPUB file: $epub_path${NC}"
        return 1
    fi

    if [ -z "$css_path" ] || [ ! -f "$css_path" ]; then
        echo "${RED}❌ Error: Invalid CSS file: $css_path${NC}"
        return 1
    fi

    _clean_vars
    CUSTOM_CSS="$css_path"

    if ! extract_epub "$epub_path"; then
        return 1
    fi

    cd "$CURRENT_OEBPS" 2>/dev/null || return 1

    XHTML_LIST=$(get_xhtml_order_from_opf "$OPF_FILE" "$CURRENT_OEBPS")

    if [ -z "$XHTML_LIST" ]; then
        echo "${RED}❌ Error: No XHTML files found${NC}"
        _cleanup_temp
        return 1
    fi

    # Select page
    if [ -n "$page_num" ]; then
        count=0
        SELECTED_FILE=""
        for file in $XHTML_LIST; do
            count=$((count + 1))
            if [ "$count" -eq "$page_num" ]; then
                SELECTED_FILE="$file"
                break
            fi
        done
        if [ -z "$SELECTED_FILE" ]; then
            echo "${RED}❌ Error: Page $page_num not found${NC}"
            _cleanup_temp
            return 1
        fi
        echo "${GREEN}✅ Selected: $SELECTED_FILE${NC}"
    else
        if ! _interactive_mode "$XHTML_LIST"; then
            _cleanup_temp
            return 1
        fi
        echo "${GREEN}✅ Selected: $SELECTED_FILE${NC}"
        echo ""
    fi

    echo "${GREEN}✅ Custom CSS: $CUSTOM_CSS${NC}"

    # Set output directory
    if [ -z "$output_dir" ]; then
        EPUB_DIR=$(dirname "$CURRENT_EPUB")
        PAGE_NAME=$(echo "$SELECTED_FILE" | sed 's/\.[^.]*$//')
        TEST_FOLDER_NAME="custom_test_${PAGE_NAME}_${CURRENT_EPUB_NAME}"
        output_dir="${EPUB_DIR}/${TEST_FOLDER_NAME}"
    fi

    mkdir -p "$output_dir" 2>/dev/null
    echo "${BLUE}📁 Test output: $output_dir${NC}"
    echo ""

    # DPI values to test
    DPI_VALUES="96 150 300"

    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}🔄 Generating test PDFs with CUSTOM CSS (3 sizes × 3 DPIs)...${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""

    cp "$CUSTOM_CSS" "$CURRENT_OEBPS/custom.css"

    for size in A4 A3 A2; do
        for dpi in $DPI_VALUES; do
            echo "${YELLOW}Testing size: $size - DPI: $dpi${NC}"

            _convert_page "$SELECTED_FILE" "custom.css" "$size" "$dpi" 0 "$output_dir/${size}-${dpi}dpi-custom.pdf"

            if [ $? -eq 0 ] && [ -f "$output_dir/${size}-${dpi}dpi-custom.pdf" ] && [ -s "$output_dir/${size}-${dpi}dpi-custom.pdf" ]; then
                echo "  ${GREEN}✓${NC} $size - $dpi DPI - Custom CSS applied"
            else
                echo "  ${RED}✗${NC} $size - $dpi DPI - Failed to generate"
            fi
        done
        echo ""
    done

    rm -f "$CURRENT_OEBPS/custom.css" 2>/dev/null

    echo ""
    echo "${GREEN}✅ All tests completed!${NC}"
    echo ""
    echo "${BLUE}📁 Test PDFs are in: $output_dir${NC}"
    echo ""
    echo "${YELLOW}📊 Summary:${NC}"
    ls -la "$output_dir"/*.pdf 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes)"}' | sed 's/.*\///'
    echo ""
    echo "${YELLOW}🔍 Review the PDFs and select the size (A4/A3/A2) and DPI${NC}"
    echo "${YELLOW}   that works best with your custom CSS.${NC}"

    _cleanup_temp
    return 0
}


_action_convert() {
    local input_path="$1"
    local output_dir="$2"
    local size="$3"
    local approach="$4"
    local css_path="$5"
    local dpi="$6"
    local auto_yes="$7"

    if [ -z "$input_path" ]; then
        echo "${RED}❌ Error: No input path provided${NC}"
        return 1
    fi

    _clean_vars

    # Get list of EPUBs
    EPUB_LIST_FILE=$(get_epubs "$input_path")
    if [ $? -ne 0 ] || [ -z "$EPUB_LIST_FILE" ]; then
        echo "${RED}❌ Error: No EPUB files found${NC}"
        return 1
    fi

    TOTAL_EPUBS=$(wc -l < "$EPUB_LIST_FILE" 2>/dev/null | tr -d ' ')

    if [ "$TOTAL_EPUBS" -eq 0 ]; then
        echo "${RED}❌ No EPUB files found${NC}"
        _cleanup_list
        return 1
    fi

    # Set default output directory if not provided
    if [ -z "$output_dir" ]; then
        if [ -f "$input_path" ]; then
            output_dir=$(dirname "$input_path")
        else
            output_dir="$input_path"
        fi
        echo "${YELLOW}⚠️  Using default output: $output_dir${NC}"
    fi

    mkdir -p "$output_dir" 2>/dev/null

    if [ ! -w "$output_dir" ]; then
        echo "${RED}❌ Error: Cannot write to $output_dir${NC}"
        _cleanup_list
        return 1
    fi

    echo "${GREEN}✅ Output directory: $output_dir${NC}"
    echo ""

    # If custom CSS provided, use it
    USE_CUSTOM=0
    if [ -n "$css_path" ] && [ -f "$css_path" ]; then
        CUSTOM_CSS="$css_path"
        USE_CUSTOM=1
        echo "${GREEN}✅ Using custom CSS: $CUSTOM_CSS${NC}"
        approach=1  # Force approach 1 when using custom CSS
    fi

    # If DPI not provided, ask interactively
    if [ -z "$dpi" ]; then
        echo "${YELLOW}🖨️ Select DPI:${NC}"
        echo "  1) 96 (draft, small files)"
        echo "  2) 150 (recommended, good balance)"
        echo "  3) 300 (high quality, larger files)"
        printf "${YELLOW}Option [1-3]: ${NC}"
        read -r DPI_OPTION
        case $DPI_OPTION in
            1) dpi="96" ;;
            2) dpi="150" ;;
            3) dpi="300" ;;
            *) echo "${RED}❌ Invalid. Using 150.${NC}"; dpi="150" ;;
        esac
    fi

    # If size not provided, ask interactively
    if [ -z "$size" ]; then
        echo "${YELLOW}📐 Select PDF size:${NC}"
        echo "  1) A4"
        echo "  2) A3"
        echo "  3) A2"
        printf "${YELLOW}Option [1-3]: ${NC}"
        read -r SIZE_OPTION
        case $SIZE_OPTION in
            1) size="A4" ;;
            2) size="A3" ;;
            3) size="A2" ;;
            *) echo "${RED}❌ Invalid. Using A3.${NC}"; size="A3" ;;
        esac
    fi

    echo "${GREEN}✅ Size: $size${NC}"
    echo "${GREEN}✅ DPI: $dpi${NC}"

    # If approach not provided and not using custom CSS, ask interactively
    if [ -z "$approach" ] && [ "$USE_CUSTOM" -eq 0 ]; then
        echo "${YELLOW}🔧 Select conversion approach:${NC}"
        echo "  1) Original CSS"
        echo "  2) High Resolution (300 DPI fijo)"
        echo "  3) No Optimisations"
        echo "  4) Force Dimensions"
        echo "  5) Viewport (HTML wrapper, no CSS)"
        echo "  6) Force Margins"
        echo ""
        printf "${YELLOW}Option [1-6]: ${NC}"
        read -r APPROACH_OPTION
        if [ "$APPROACH_OPTION" -lt 1 ] || [ "$APPROACH_OPTION" -gt 6 ]; then
            echo "${RED}❌ Invalid. Using approach 1.${NC}"
            approach=1
        else
            approach="$APPROACH_OPTION"
        fi
    elif [ -z "$approach" ] && [ "$USE_CUSTOM" -eq 1 ]; then
        approach=1
    fi

    # Si el approach es 2 (High Resolution), forzar DPI a 300
    if [ "$approach" -eq 2 ]; then
        dpi="300"
        echo "${GREEN}✅ Approach 2: High Resolution - Forzando DPI a 300${NC}"
    fi

    if [ "$USE_CUSTOM" -eq 1 ]; then
        echo "${GREEN}✅ Using Custom CSS${NC}"
    else
        echo "${GREEN}✅ Approach: $approach${NC}"
    fi
    echo ""

    # Confirm
    if [ "$auto_yes" -ne 1 ]; then
        echo "${YELLOW}⚠️  This will convert $TOTAL_EPUBS EPUB(s) using:${NC}"
        echo "   Size: $size"
        echo "   DPI: $dpi"
        if [ "$USE_CUSTOM" -eq 1 ]; then
            echo "   Custom CSS: $CUSTOM_CSS"
        else
            echo "   Approach: $approach"
        fi
        printf "${YELLOW}   Proceed? (y/N): ${NC}"
        read -r CONFIRM

        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            echo "${RED}❌ Aborted.${NC}"
            _cleanup_list
            return 0
        fi
    fi

    echo ""

    # Process each EPUB
    CURRENT=0
    while IFS= read -r epub_file; do
        [ -z "$epub_file" ] && continue

        CURRENT=$((CURRENT + 1))

        echo ""
        echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo "${BLUE}📖 Processing [$CURRENT/$TOTAL_EPUBS]: $(basename "$epub_file")${NC}"
        echo "${BLUE}════════════════════════════════════════════════════════════${NC}"

        _clean_vars

        if ! extract_epub "$epub_file"; then
            echo "${RED}❌ Failed to extract: $(basename "$epub_file")${NC}"
            continue
        fi

        cd "$CURRENT_OEBPS" 2>/dev/null || continue

        XHTML_LIST=$(get_xhtml_order_from_opf "$OPF_FILE" "$CURRENT_OEBPS")

        if [ -z "$XHTML_LIST" ]; then
            echo "${RED}❌ No XHTML files found${NC}"
            _cleanup_temp
            continue
        fi

        PAGE_COUNT=$(echo "$XHTML_LIST" | wc -l | tr -d ' ')
        echo "${GREEN}✅ Found $PAGE_COUNT pages${NC}"

        # Generate CSS based on approach
        CSS_FILE=""
        USE_WRAPPER=0

        if [ "$USE_CUSTOM" -eq 1 ]; then
            cp "$CUSTOM_CSS" "$CURRENT_OEBPS/custom.css"
            CSS_FILE="custom.css"
        else
            case $approach in
                1)
                    CSS_FILE="approach-1-${size}.css"
                    _write_css_original "$size" "$CSS_FILE"
                    ;;
                2)
                    CSS_FILE="approach-2-${size}.css"
                    _write_css_original "$size" "$CSS_FILE"
                    dpi="300"
                    ;;
                3)
                    CSS_FILE=""
                    ;;
                4)
                    CSS_FILE="approach-4-${size}.css"
                    _write_css_force_dimensions "$size" "$CSS_FILE"
                    ;;
                5)
                    USE_WRAPPER=1
                    CSS_FILE=""
                    ;;
                6)
                    CSS_FILE="approach-6-${size}.css"
                    _write_css_force_margins "$size" "$CSS_FILE"
                    ;;
                *)
                    CSS_FILE=""
                    ;;
            esac
        fi

        # Convert each page
        PAGE_NUM=0
        FAILED=0

        for file in $XHTML_LIST; do
            [ -z "$file" ] && continue

            if [ ! -f "$file" ]; then
                continue
            fi

            PAGE_NUM=$((PAGE_NUM + 1))
            output_name=$(printf "page-%03d.pdf" "$PAGE_NUM")

            _convert_page "$file" "$CSS_FILE" "$size" "$dpi" "$USE_WRAPPER" "$output_name"

            if [ $? -eq 0 ] && [ -f "$output_name" ] && [ -s "$output_name" ]; then
                echo "  ${GREEN}✓${NC} Page $PAGE_NUM: $output_name"
            else
                echo "  ${RED}✗${NC} Failed: $file"
                FAILED=$((FAILED + 1))
            fi
        done

        PDF_COUNT=$(ls *.pdf 2>/dev/null | wc -l | tr -d ' ')

        if [ "$PDF_COUNT" -gt 0 ]; then
            FINAL_DIR="$output_dir/pdfs_${size}_${dpi}dpi"
            mkdir -p "$FINAL_DIR" 2>/dev/null
            mv *.pdf "$FINAL_DIR/" 2>/dev/null
            echo "${GREEN}✅ Moved $PDF_COUNT PDFs to: $FINAL_DIR${NC}"
        fi

        rm -f approach-*.css custom.css 2>/dev/null

        _cleanup_temp
    done < "$EPUB_LIST_FILE"

    _cleanup_list

    echo ""
    echo "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo "${GREEN}✅ All conversions complete!${NC}"
    echo "${GREEN}📁 PDFs are in: $output_dir${NC}"
    echo "${GREEN}════════════════════════════════════════════════════════════${NC}"

    return 0
}




_action_extract() {
    local input_path="$1"
    local output_dir="$2"

    if [ -z "$input_path" ]; then
        echo "${RED}❌ Error: No input path provided${NC}"
        return 1
    fi

    _clean_vars

    EPUB_LIST_FILE=$(get_epubs "$input_path")
    if [ $? -ne 0 ] || [ -z "$EPUB_LIST_FILE" ]; then
        echo "${RED}❌ Error: No EPUB files found${NC}"
        return 1
    fi

    TOTAL_EPUBS=$(wc -l < "$EPUB_LIST_FILE" 2>/dev/null | tr -d ' ')

    if [ "$TOTAL_EPUBS" -eq 0 ]; then
        echo "${RED}❌ No EPUB files found${NC}"
        _cleanup_list
        return 1
    fi

    if [ -z "$output_dir" ]; then
        if [ -f "$input_path" ]; then
            output_dir="$(dirname "$input_path")/extracted"
        else
            output_dir="$input_path/extracted"
        fi
        echo "${YELLOW}⚠️  Using default: $output_dir${NC}"
    fi

    mkdir -p "$output_dir" 2>/dev/null

    echo "${GREEN}✅ Extraction directory: $output_dir${NC}"
    echo ""

    echo "${YELLOW}⚠️  This will extract $TOTAL_EPUBS EPUB(s)${NC}"
    printf "${YELLOW}   Proceed? (y/N): ${NC}"
    read -r CONFIRM

    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "${RED}❌ Aborted.${NC}"
        _cleanup_list
        return 0
    fi

    echo ""

    CURRENT=0
    while IFS= read -r epub_file; do
        [ -z "$epub_file" ] && continue

        CURRENT=$((CURRENT + 1))

        echo ""
        echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo "${BLUE}📖 Extracting [$CURRENT/$TOTAL_EPUBS]: $(basename "$epub_file")${NC}"
        echo "${BLUE}════════════════════════════════════════════════════════════${NC}"

        EPUB_NAME=$(basename "$epub_file" .epub)
        TARGET_DIR="$output_dir/${EPUB_NAME}_extracted"

        mkdir -p "$TARGET_DIR" 2>/dev/null

        unzip -q "$epub_file" -d "$TARGET_DIR" 2>/dev/null || {
            echo "${RED}❌ Failed to extract: $epub_file${NC}"
            continue
        }

        echo "${GREEN}✅ Extracted to: $TARGET_DIR${NC}"

        echo "${YELLOW}📁 Structure:${NC}"
        ls -la "$TARGET_DIR" 2>/dev/null | head -10

        OEBPS=$(find "$TARGET_DIR" -type d -name "OEBPS" 2>/dev/null | head -1)
        if [ -n "$OEBPS" ]; then
            echo "${GREEN}✅ OEBPS found: $OEBPS${NC}"
            XHTML_COUNT=$(ls "$OEBPS"/*.xhtml 2>/dev/null | wc -l | tr -d ' ')
            echo "${GREEN}📄 XHTML files: $XHTML_COUNT${NC}"
        fi

    done < "$EPUB_LIST_FILE"

    _cleanup_list

    echo ""
    echo "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo "${GREEN}✅ All extractions complete!${NC}"
    echo "${GREEN}📁 Extracted to: $output_dir${NC}"
    echo "${GREEN}════════════════════════════════════════════════════════════${NC}"

    return 0
}




# MENUS
main_menu() {
    clear 2>/dev/null || printf "\033c"
    echo ""
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}      EPUB TOOLKIT - Complete Management Tool${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "${GREEN}1.${NC} Test Conversion Approaches (single page)"
    echo "${GREEN}2.${NC} Test with CUSTOM CSS (single page)"
    echo "${GREEN}3.${NC} Convert EPUB(s) to PDF"
    echo "${GREEN}4.${NC} Extract EPUB(s) Content"
    echo "${GREEN}5.${NC} Exit"
    echo ""
    printf "${YELLOW}Select option [1-5]: ${NC}"
}

menu_test_approaches() {
    echo ""
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}      TEST CONVERSION APPROACHES${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo "${YELLOW}📂 Enter path to EPUB file:${NC}"
    read -r EPUB_PATH

    if [ -z "$EPUB_PATH" ] || [ ! -f "$EPUB_PATH" ] || ! echo "$EPUB_PATH" | grep -q '\.epub$'; then
        echo "${RED}❌ Error: Invalid EPUB file${NC}"
        return 1
    fi

    _action_test_approaches "$EPUB_PATH" "" ""
}

menu_test_custom_css() {
    echo ""
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}      TEST WITH CUSTOM CSS${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo "${YELLOW}📂 Enter path to EPUB file:${NC}"
    read -r EPUB_PATH

    if [ -z "$EPUB_PATH" ] || [ ! -f "$EPUB_PATH" ] || ! echo "$EPUB_PATH" | grep -q '\.epub$'; then
        echo "${RED}❌ Error: Invalid EPUB file${NC}"
        return 1
    fi

    echo "${YELLOW}📄 Enter path to custom CSS file:${NC}"
    read -r CSS_PATH

    if [ -z "$CSS_PATH" ] || [ ! -f "$CSS_PATH" ]; then
        echo "${RED}❌ Error: Invalid CSS file${NC}"
        return 1
    fi

    _action_test_custom_css "$EPUB_PATH" "$CSS_PATH" "" ""
}

menu_convert() {
    echo ""
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}      CONVERT EPUB(S) TO PDF${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "${YELLOW}💡 Run option 1 first to test which approach works best!${NC}"
    echo ""
    echo "${YELLOW}📂 Enter path to EPUB file OR folder containing EPUBs:${NC}"
    read -r INPUT_PATH

    if [ -z "$INPUT_PATH" ]; then
        echo "${RED}❌ Error: No path provided${NC}"
        return 1
    fi

    echo "${YELLOW}📁 Enter output directory for PDFs (or Enter for default):${NC}"
    read -r OUTPUT_DIR

    if [ -z "$OUTPUT_DIR" ]; then
        if [ -f "$INPUT_PATH" ]; then
            OUTPUT_DIR=$(dirname "$INPUT_PATH")
        else
            OUTPUT_DIR="$INPUT_PATH"
        fi
        echo "${YELLOW}⚠️  Using: $OUTPUT_DIR${NC}"
    fi

    _action_convert "$INPUT_PATH" "$OUTPUT_DIR" "" "" "" "" 0
}

menu_extract() {
    echo ""
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}      EXTRACT EPUB(S) CONTENT${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo "${YELLOW}📂 Enter path to EPUB file OR folder containing EPUBs:${NC}"
    read -r INPUT_PATH

    if [ -z "$INPUT_PATH" ]; then
        echo "${RED}❌ Error: No path provided${NC}"
        return 1
    fi

    echo "${YELLOW}📁 Enter extraction directory (or Enter for default):${NC}"
    read -r EXTRACT_DIR

    _action_extract "$INPUT_PATH" "$EXTRACT_DIR"
}




# CLI
parse_cli() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -m|--mode)
                CLI_MODE="$2"
                shift 2
                ;;
            -i|--input)
                CLI_INPUT="$2"
                shift 2
                ;;
            -o|--output)
                CLI_OUTPUT="$2"
                shift 2
                ;;
            -s|--size)
                CLI_SIZE="$2"
                shift 2
                ;;
            -a|--approach)
                CLI_APPROACH="$2"
                shift 2
                ;;
            -c|--css)
                CLI_CSS="$2"
                shift 2
                ;;
            -p|--page)
                CLI_PAGE="$2"
                shift 2
                ;;
            -y|--yes)
                CLI_YES=1
                shift
                ;;
            -h|--help)
                echo "EPUB Toolkit - CLI Usage:"
                echo ""
                echo "  -m, --mode      <test|test-custom|convert|extract>"
                echo "  -i, --input     <path>        EPUB file or folder"
                echo "  -o, --output    <path>        Output directory"
                echo "  -s, --size      <A4|A3|A2>    Page size"
                echo "  -a, --approach  <1-6>         Conversion approach"
                echo "  -c, --css       <path>        Custom CSS file"
                echo "  -p, --page      <n>           Page number for test"
                echo "  -y, --yes                     Skip confirmations"
                echo "  -h, --help                    Show this help"
                echo ""
                echo "Approaches:"
                echo "  1) Original CSS"
                echo "  2) High Resolution (300 DPI fijo)"
                echo "  3) No Optimisations"
                echo "  4) Force Dimensions"
                echo "  5) Viewport (HTML wrapper, no CSS)"
                echo "  6) Force Margins"
                echo ""
                echo "Examples:"
                echo "  ./epub-toolkit.sh -m test -i book.epub -p 5"
                echo "  ./epub-toolkit.sh -m convert -i folder/ -o output/ -s A3 -a 1 -y"
                echo "  ./epub-toolkit.sh -m test-custom -i book.epub -c style.css -p 3"
                exit 0
                ;;
            *)
                echo "${RED}❌ Unknown option: $1${NC}"
                echo "Use -h or --help for usage"
                exit 1
                ;;
        esac
    done

    case "$CLI_MODE" in
        test|test-custom|convert|extract)
            CLI_RUN=1
            ;;
        "")
            CLI_RUN=0
            ;;
        *)
            echo "${RED}❌ Invalid mode: $CLI_MODE${NC}"
            echo "Valid modes: test, test-custom, convert, extract"
            exit 1
            ;;
    esac
}


run_cli() {
    case "$CLI_MODE" in
        test)
            if [ -z "$CLI_INPUT" ]; then
                echo "${RED}❌ Error: --input is required for test mode${NC}"
                exit 1
            fi
            if [ -z "$CLI_PAGE" ]; then
                echo "${RED}❌ Error: --page is required for test mode${NC}"
                exit 1
            fi
            _action_test_approaches "$CLI_INPUT" "$CLI_PAGE" "$CLI_OUTPUT"
            ;;
        test-custom)
            if [ -z "$CLI_INPUT" ]; then
                echo "${RED}❌ Error: --input is required for test-custom mode${NC}"
                exit 1
            fi
            if [ -z "$CLI_CSS" ]; then
                echo "${RED}❌ Error: --css is required for test-custom mode${NC}"
                exit 1
            fi
            if [ -z "$CLI_PAGE" ]; then
                echo "${RED}❌ Error: --page is required for test-custom mode${NC}"
                exit 1
            fi
            _action_test_custom_css "$CLI_INPUT" "$CLI_CSS" "$CLI_PAGE" "$CLI_OUTPUT"
            ;;
        convert)
            if [ -z "$CLI_INPUT" ]; then
                echo "${RED}❌ Error: --input is required for convert mode${NC}"
                exit 1
            fi
            if [ -z "$CLI_SIZE" ]; then
                echo "${RED}❌ Error: --size is required for convert mode${NC}"
                exit 1
            fi
            case "$CLI_SIZE" in
                A4|A3|A2) ;;
                *) echo "${RED}❌ Invalid size: $CLI_SIZE (must be A4, A3, or A2)${NC}"; exit 1 ;;
            esac
            if [ -n "$CLI_APPROACH" ]; then
                case "$CLI_APPROACH" in
                    1|2|3|4|5|6) ;;
                    *) echo "${RED}❌ Invalid approach: $CLI_APPROACH (must be 1-6)${NC}"; exit 1 ;;
                esac
            fi
            # DPI por defecto 150, si es approach 2 se fuerza 300 en _action_convert
            _action_convert "$CLI_INPUT" "$CLI_OUTPUT" "$CLI_SIZE" "$CLI_APPROACH" "$CLI_CSS" "150" "$CLI_YES"
            ;;
        extract)
            if [ -z "$CLI_INPUT" ]; then
                echo "${RED}❌ Error: --input is required for extract mode${NC}"
                exit 1
            fi
            _action_extract "$CLI_INPUT" "$CLI_OUTPUT"
            ;;
        *)
            echo "${RED}❌ Error: Unknown mode${NC}"
            exit 1
            ;;
    esac
}

main() {
    if [ $# -gt 0 ]; then
        parse_cli "$@"
        if [ "$CLI_RUN" -eq 1 ]; then
            run_cli
            exit $?
        fi
    fi

    while true; do
        main_menu
        read -r OPTION

        case $OPTION in
            1)
                menu_test_approaches
                echo ""
                printf "${YELLOW}Press Enter to continue...${NC}"
                read -r dummy
                ;;
            2)
                menu_test_custom_css
                echo ""
                printf "${YELLOW}Press Enter to continue...${NC}"
                read -r dummy
                ;;
            3)
                menu_convert
                echo ""
                printf "${YELLOW}Press Enter to continue...${NC}"
                read -r dummy
                ;;
            4)
                menu_extract
                echo ""
                printf "${YELLOW}Press Enter to continue...${NC}"
                read -r dummy
                ;;
            5)
                echo "${GREEN}👋 Goodbye!${NC}"
                _clean_vars
                exit 0
                ;;
            *)
                echo "${RED}❌ Invalid option. Please select 1-5.${NC}"
                echo ""
                printf "${YELLOW}Press Enter to continue...${NC}"
                read -r dummy
                ;;
        esac
    done
}

main "$@"
