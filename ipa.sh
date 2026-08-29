#!/usr/bin/env bash

# ANSI TrueColor macros (Pastel Palette)
C_HEAD_MAIN="\033[38;2;174;198;207m"
C_HEAD_COMP="\033[38;2;253;253;150m"
C_HEAD_ASN="\033[38;2;255;179;186m"
C_HEAD_LOC="\033[38;2;186;255;201m"
C_SEP="\033[38;2;90;90;90m"
C_KEY="\033[38;2;110;110;110m"
C_VAL="\033[38;2;190;190;190m"
C_TRUE="\033[38;2;119;221;119m"
C_FALSE="\033[38;2;244;194;194m"
C_RST="\033[0m"

# Parse arguments
TARGET_IP=""
MODE="DEFAULT"

for arg in "$@"; do
    case $arg in
        -h|--help) MODE="HELP" ;;
        -f|--full) MODE="FULL" ;;
        -s|--short) MODE="SHORT" ;;
        *) TARGET_IP="$arg" ;;
    esac
done

print_help() {
    echo -e "\n${C_HEAD_MAIN}╭─┬─┬─╮\n${C_HEAD_MAIN}├─┼─┼─╯    ${C_VAL}ipapi CLI\n${C_HEAD_MAIN}├─┼─╯      ${C_SEP}v1.0.0 (Bash)\n${C_HEAD_MAIN}╰─╯\n${C_RST}"
    echo -e "${C_HEAD_COMP}USAGE:${C_RST}\n  ${C_VAL}./ipa.sh [IP] [OPTIONS]\n${C_RST}"
    echo -e "${C_HEAD_ASN}OPTIONS:${C_RST}"
    printf "  ${C_KEY}%-18s${C_RST}${C_VAL}%s${C_RST}\n" "-h, --help" "Show this beautiful help message"
    printf "  ${C_KEY}%-18s${C_RST}${C_VAL}%s${C_RST}\n" "-f, --full" "Display full, verbose IP data (location, all flags, etc.)"
    printf "  ${C_KEY}%-18s${C_RST}${C_VAL}%s${C_RST}\n\n" "-s, --short" "Output a single-line summary (ideal for bash scripts)"
    echo -e "${C_SEP}If no IP is provided, the program queries your current IP.\n${C_RST}"
}

if [ "$MODE" == "HELP" ]; then
    print_help
    exit 0
fi

if ! command -v jq &> /dev/null; then
    echo -e "${C_FALSE}Error: 'jq' is not installed. Please install it to use the bash version.${C_RST}"
    exit 1
fi

print_row() {
    if [ "$2" != "-" ] || [ "$MODE" == "FULL" ]; then
        printf "${C_KEY}%-14s${C_RST}${C_VAL}%s${C_RST}\n" "$1" "$2"
    fi
}

print_colored_row() {
    printf "${C_KEY}%-14s${C_RST}%b%s${C_RST}\n" "$1" "$3" "$2"
}

print_flag() {
    if [ "$2" == "true" ]; then
        printf "${C_KEY}%-14s${C_RST}${C_TRUE}✓${C_RST}\n" "$1"
    else
        printf "${C_KEY}%-14s${C_RST}${C_FALSE}✗${C_RST}\n" "$1"
    fi
}

get_score_color() {
    local val="$1"
    if [[ "$val" == *"(Very Low)"* ]]; then echo "$C_TRUE";
    elif [[ "$val" == *"(Low)"* ]]; then echo "\033[38;2;170;220;190m";
    elif [[ "$val" == *"(Elevated)"* ]]; then echo "\033[38;2;253;253;150m";
    elif [[ "$val" == *"(Medium)"* ]]; then echo "\033[38;2;255;200;150m";
    elif [[ "$val" == *"(High)"* ]]; then echo "\033[38;2;244;194;194m";
    elif [[ "$val" == *"(Very High)"* ]]; then echo "\033[38;2;255;105;97m";
    elif [[ "$val" == *"(Severe)"* ]] || [[ "$val" == *"(Critical)"* ]]; then echo "\033[38;2;255;105;97m";
    else echo "$C_VAL"; fi
}

print_score_row() {
    if [ "$2" != "-" ]; then
        local color=$(get_score_color "$2")
        printf "${C_KEY}%-14s${C_RST}%b%s${C_RST}\n" "$1" "$color" "$2"
    fi
}

update_quota() {
    local tmp_dir=${TMPDIR:-/tmp}
    local file_path="${tmp_dir}/ipa_counter.json"
    local today=$(date +"%Y-%m-%d")
    local count=0

    if [ -f "$file_path" ]; then
        local file_date=$(jq -r '.date // ""' "$file_path" 2>/dev/null)
        if [ "$file_date" == "$today" ]; then
            count=$(jq -r '.count // 0' "$file_path" 2>/dev/null)
        fi
    fi
    count=$((count + 1))
    
    echo "{\"date\":\"$today\",\"count\":$count}" > "$file_path"
    echo "$count"
}

JSON=$(curl -s -H "Referer: https://ipapi.is/" "https://api.ipapi.is/?q=$TARGET_IP")

ERR=$(echo "$JSON" | jq -r '.error // empty')
if [ -n "$ERR" ]; then
    echo -e "${C_TRUE}Error fetching IP info.${C_RST}"
    echo -e "${C_VAL}$ERR${C_RST}"
    exit 1
fi

eval "$(echo "$JSON" | jq -r '
  @sh "IP=\(.ip // "Unknown")",
  @sh "RIR=\(.rir // "-")",
  @sh "IS_BOGON=\(.is_bogon // false)",
  @sh "IS_DC=\(.is_datacenter // false)",
  @sh "IS_MOB=\(.is_mobile // false)",
  @sh "IS_TOR=\(.is_tor // false)",
  @sh "IS_SAT=\(.is_satellite // false)",
  @sh "IS_PROXY=\(.is_proxy // false)",
  @sh "IS_CRAWL=\(.is_crawler // false)",
  @sh "IS_VPN=\(.is_vpn // false)",
  @sh "IS_ABUSER=\(.is_abuser // false)",
  @sh "COMP_NAME=\(.company.name // .company_name // "-")",
  @sh "COMP_DOM=\(.company.domain // "-")",
  @sh "COMP_TYPE=\(.company.type // "-")",
  @sh "COMP_NET=\(.company.network // "-")",
  @sh "COMP_SCORE=\(.company.abuser_score // "-")",
  @sh "ASN_NUM=\(.asn.asn // .asn_num // "-")",
  @sh "ASN_ORG=\(.asn.org // .asn_org // "-")",
  @sh "ASN_ROUTE=\(.asn.route // "-")",
  @sh "ASN_TYPE=\(.asn.type // "-")",
  @sh "ASN_SCORE=\(.asn.abuser_score // "-")",
  @sh "LOC_CC=\(.location.country_code // .cc // "-")",
  @sh "LOC_COUNTRY=\(.location.country // "-")",
  @sh "LOC_STATE=\(.location.state // "-")",
  @sh "LOC_CITY=\(.location.city // "-")",
  @sh "LOC_ZIP=\(.location.zip // "-")",
  @sh "LOC_TZ=\(.location.timezone // "-")",
  @sh "LOC_LAT=\(.location.latitude // .lat // "-")",
  @sh "LOC_LON=\(.location.longitude // .lon // "-")",
  @sh "LOC_ACC=\(.location.accuracy // "-")"
')"

IP_COLOR=$([ "$IS_ABUSER" == "true" ] && echo "\033[38;2;255;105;97m" || echo "$C_TRUE")

if [ "$MODE" == "SHORT" ]; then
    PIPE="${C_SEP} | ${C_RST}"
    COMP_STR="${COMP_NAME}"
    [ "$COMP_TYPE" != "-" ] && COMP_STR="${COMP_STR} (${COMP_TYPE})"
    
    C_C_SCORE=$(get_score_color "$COMP_SCORE")
    C_A_SCORE=$(get_score_color "$ASN_SCORE")
    
    echo -e "${IP_COLOR}${IP}${C_RST}${PIPE}${C_VAL}${LOC_CC}${C_RST}${PIPE}${C_VAL}${COMP_STR}${C_RST}${PIPE}${C_C_SCORE}${COMP_SCORE}${C_RST}${PIPE}${C_A_SCORE}${ASN_SCORE}${C_RST}"
    update_quota > /dev/null
    exit 0
fi

# --- MAIN SECTION ---
echo -e "\n${C_HEAD_MAIN}MAIN${C_RST}\n${C_SEP}----${C_RST}"
print_colored_row "ip" "$IP" "$IP_COLOR"

if [ "$MODE" == "FULL" ] && [ "$RIR" != "-" ]; then print_row "rir" "$RIR"; fi

if [ "$MODE" == "FULL" ]; then
    print_flag "bogon" "$IS_BOGON"
    print_flag "datacenter" "$IS_DC"
    print_flag "mobile" "$IS_MOB"
    print_flag "tor" "$IS_TOR"
    print_flag "satellite" "$IS_SAT"
    print_flag "proxy" "$IS_PROXY"
    print_flag "crawler" "$IS_CRAWL"
    print_flag "vpn" "$IS_VPN"
fi
print_flag "abuser (IP)" "$IS_ABUSER"
echo ""

# --- COMPANY & NETWORK SECTION ---
if [ "$COMP_NAME" != "-" ]; then
    echo -e "${C_HEAD_COMP}NETWORK${C_RST}\n${C_SEP}-----------------${C_RST}"
    print_row "name" "$COMP_NAME"
    [ "$COMP_DOM" != "-" ] && print_row "domain" "$COMP_DOM"
    [ "$COMP_TYPE" != "-" ] && print_row "type" "$COMP_TYPE"
    [ "$COMP_NET" != "-" ] && print_row "network" "$COMP_NET"
    [ "$COMP_SCORE" != "-" ] && print_score_row "abuser_score" "$COMP_SCORE"
    echo ""
fi

# --- ASN SECTION ---
echo -e "${C_HEAD_ASN}ASN${C_RST}\n${C_SEP}---${C_RST}"
print_row "asn" "$ASN_NUM"
print_row "org" "$ASN_ORG"
[ "$ASN_ROUTE" != "-" ] && print_row "route" "$ASN_ROUTE"
[ "$ASN_TYPE" != "-" ] && print_row "type" "$ASN_TYPE"
[ "$ASN_SCORE" != "-" ] && print_score_row "abuser_score" "$ASN_SCORE"
echo ""

# --- LOCATION SECTION ---
echo -e "${C_HEAD_LOC}LOCATION${C_RST}\n${C_SEP}--------${C_RST}"
print_row "country" "$LOC_COUNTRY"

if [ "$MODE" == "FULL" ]; then
    [ "$LOC_STATE" != "-" ] && print_row "state" "$LOC_STATE"
    [ "$LOC_CITY" != "-" ] && print_row "city" "$LOC_CITY"
    [ "$LOC_ZIP" != "-" ] && print_row "zip" "$LOC_ZIP"
fi

[ "$LOC_TZ" != "-" ] && print_row "timezone" "$LOC_TZ"

if [ "$MODE" == "FULL" ]; then
    LATLON="- / -"
    if [ "$LOC_LAT" != "-" ] && [ "$LOC_LON" != "-" ]; then
        LATLON="${LOC_LAT} / ${LOC_LON}"
    fi
    print_row "lat/lon" "$LATLON"
    [ "$LOC_ACC" != "-" ] && print_row "accuracy" "$LOC_ACC"
fi
echo ""

# --- QUOTA SECTION ---
QUOTA=$(update_quota)
echo -e "${C_SEP}API Quota: ${C_RST}${C_VAL}${QUOTA} / 1000${C_RST}${C_SEP} requests today${C_RST}\n"
