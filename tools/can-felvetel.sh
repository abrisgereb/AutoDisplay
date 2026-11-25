#!/usr/bin/env bash
# CAN-felvétel az Opel Astra H MS-CAN buszáról (95,238 kbit/s), csak hallgatás módban.
# A Pi ebben a módban semmit nem küld a buszra.
#
# Használat:  ./can-felvetel.sh [-n] [interfész]
#   -n          ne állítsa be az interfészt (ha már kézzel felhúztad)
#   interfész   alapértelmezés: can0
#
# Kimenet egy felvetel-ÉÉÉÉHHNN-ÓÓPPMM/ mappában:
#   can.log.gz     a nyers CAN-forgalom (candump -L formátum, abszolút időbélyeggel)
#   jelolok.txt    minden lépés kezdete, ugyanazzal az időbélyeggel
#   interfesz.txt  az interfész beállításai és hibaszámlálói (elején és végén)
#
# Leírás: docs/can-felvetel.md

set -euo pipefail

SETUP=1
if [[ "${1:-}" == "-n" ]]; then
  SETUP=0
  shift
fi
IF="${1:-can0}"
BITRATE=95238
OUT="felvetel-$(date +%Y%m%d-%H%M%S)"

die() { echo "HIBA: $*" >&2; exit 1; }

command -v candump >/dev/null || die "hiányzik a can-utils (sudo apt install can-utils)"
ip link show "$IF" >/dev/null 2>&1 \
  || die "nincs '$IF' interfész. Nézd meg a config.txt-t és a 'dmesg | grep -i mcp251' kimenetét."

if (( SETUP )); then
  echo "== $IF beállítása: $BITRATE bit/s, csak hallgatás (listen-only) =="
  sudo ip link set "$IF" down
  sudo ip link set "$IF" up type can bitrate "$BITRATE" listen-only on
fi

mkdir -p "$OUT"
ip -details -statistics link show "$IF" > "$OUT/interfesz.txt"
if ! grep -q "LISTEN-ONLY" "$OUT/interfesz.txt"; then
  echo "FIGYELEM: az interfész nincs listen-only módban, a Pi így nyugtázhatja a forgalmat."
fi

# Soronkénti pufferelés, hogy leállításkor se vesszen el semmi.
stdbuf -oL candump -L "$IF" > "$OUT/can.log" &
DUMP_PID=$!

finish() {
  kill "$DUMP_PID" 2>/dev/null || true
  wait "$DUMP_PID" 2>/dev/null || true
  {
    echo
    echo "== a felvétel végén =="
    ip -details -statistics link show "$IF" 2>/dev/null || true
  } >> "$OUT/interfesz.txt"

  local n
  n=$(wc -l < "$OUT/can.log")
  echo
  echo "== Felvétel vége: $n CAN-üzenet =="
  if (( n > 0 )); then
    echo "Leggyakoribb azonosítók (darab, ID):"
    awk '{ split($3, a, "#"); print a[1] }' "$OUT/can.log" | sort | uniq -c | sort -rn | head -15
  else
    echo "Egy üzenet sem jött. Lásd a hibaelhárítást: docs/can-felvetel.md"
  fi
  gzip -f "$OUT/can.log"
  echo "Fájlok: $OUT/"
}
trap finish EXIT
trap 'exit 130' INT

mark() { printf '%s %s\n' "$(date +%s.%N)" "$*" >> "$OUT/jelolok.txt"; }

step() {
  printf '\n>>> %s\n' "$1"
  read -r -p "    Nyomj Entert, aztán csináld meg. " _
  mark "$1"
}

buttons() {  # $1 = rövid csoportnév a jelölőkhöz, $2 = leírás
  printf '\n>>> %s\n' "$2"
  echo "    Írd be a gomb nevét, Enter, aztán nyomd meg a gombot egyszer, és várj 2 mp-et."
  echo "    Üres Enter = tovább."
  local name
  while true; do
    read -r -p "    Gomb neve: " name
    [[ -z "$name" ]] && break
    mark "$1: $name"
  done
}

echo
echo "Felvétel fut: $OUT/can.log   (Ctrl+C = leállítás bármikor, a fájlok megmaradnak)"

step "Alapállapot: kulcs a zárban, gyújtás NINCS ráadva. Várj 10 mp-et."
step "Gyújtás rá (a motor NE járjon). Várj 15 mp-et."
step "Ha a rádió nem kapcsolt be magától, kapcsold be. Várj 5 mp-et."
buttons "radio" "Rádió gombjai egyenként (BC, Settings, OK, nyilak, FM/CD, számgombok, hangerő, tekerőgomb...)"
buttons "kormany" "Kormánygombok egyenként (bal görgő fel/le/nyomás, hangerő-görgő, következő/előző...)"
step "GID: lapozz végig a BC1, BC2 és Timer oldalakon a kormány bal görgőjével."
step "Rádió: válaszd ki az AUX forrást, és hagyd rajta 10 mp-ig."
step "Klíma: hőmérséklet fel és le, ventilátor fel és le."
step "Világítás: helyzetjelző, tompított, a műszerfal-világítás tekerőjét tekerd végig, végül világítás ki."
step "Irányjelző balra 5 mp, jobbra 5 mp, vészvillogó 5 mp."
step "Vezetőoldali ajtó nyit, csuk."
step "Motor indítása, alapjárat 30 mp."
step "Álló helyzetben: hátramenet be 5 mp-re, majd ki."
step "Rövid menet (2-5 perc). Menet közben a telefont csak utas kezelje! Ha egyedül vagy, ezt az Entert indulás előtt nyomd meg."
step "Megálltál: motor le, gyújtás le, kulcs ki. Várj 2 percet, amíg a busz elalszik."

echo
read -r -p "Kész. Nyomj Entert a felvétel lezárásához. " _
