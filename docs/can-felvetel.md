# CAN-felvétel: pontosan mi kell, és hogyan csináld

**Cél:** rögzíteni az Astra H **MS-CAN** buszának forgalmát, miközben sorban megnyomod a gombokat, beindítod a motort, tolatsz és vezetsz. Ebből a logból írom meg a Pi CAN démonját.

**A Pi végig csak hallgat (listen-only),** semmit nem küld a buszra, így az autó működését nem befolyásolja.

Jelölések:
- ✅ több forrás egyezik
- ⚠️ ellenőrizd a saját autódon / lapodon

---

## 1. Ami kell

| Tétel | Mire | Ár (HUF) | Megjegyzés |
|---|---|---|---|
| Raspberry Pi 4 | felvevő gép | **megvan** | |
| microSD kártya, 16–32 GB | rendszer | 3–5 e | ha nincs szabad |
| **Waveshare RS485 CAN HAT** | CAN interfész (MCP2515 + SN65HVD230) | ~5 e + posta | a Pi tüskesorára ül, a CAN-t csavaros sorkapocsra vezeti ki |
| **OBD-II dugó nyitott végű kábellel** („OBD2 16 pin male pigtail”) | csatlakozás az autóhoz | 1–3 e | csak a 3-as, 11-es és 4/5-ös ér kell belőle |
| Táp a Pi-nek: **autós USB-C töltő** (5 V, min. 3 A) a 12 V-os aljzatba | áram | 2–4 e, vagy megvan | közös földet ad az autóval. Powerbank is jó, akkor a földet külön kösd be (3. fejezet) |
| Multiméter | lábak ellenőrzése | 3–5 e, vagy megvan | |
| Samsung S20 FE + SSH app (Termux, JuiceSSH vagy Termius) | a Pi vezérlése a telefonról | **megvan**, ingyenes | a Pi a telefon hotspotjára csatlakozik |

**Új alkatrész összesen:** kb. 6–13 ezer Ft.

**Alternatíva Pi helyett:** **CANable 2.0** USB-CAN adapter **candleLight firmware-rel** (7–15 e), bármilyen Linuxos laptoppal. Az slcan firmware nem jó, mert nem tudja a 95,238 kbit/s-ot.

### 1.1 Ha az olcsó kék MCP2515 modulod van (HW-184)

Ez a kék lap MCP2515 vezérlővel és **TJA1050** CAN-meghajtóval használható, de **nem köthető közvetlenül a Pi-re**.

**Miért nem:**
- A TJA1050-nek **5 V** kell, és a lap egyetlen VCC lábról táplálja az MCP2515-öt is.
- 5 V-on az MCP2515 az **SO** (MISO) és **INT** lábon 5 V-os jelet ad.
- A Pi GPIO-lábai csak 3,3 V-ot bírnak, ettől tönkremehetnek.
- 3,3 V-on táplálva pedig a TJA1050 a specifikáción kívül működik.

**1. megoldás, forrasztás nélkül: szintillesztő (ajánlott).**

- Kell hozzá **kétirányú szintillesztő**: két 4 csatornás BSS138-as panel, vagy egy 8 csatornás. Néhány száz forint.
- A modul 5 V-ot kap, a Pi felé minden jelvezeték a szintillesztőn megy át.

| Pi láb (fizikai) | Szintillesztő | HW-184 láb |
|---|---|---|
| 2 (5 V) | HV | VCC |
| 1 (3,3 V) | LV | – |
| 6 (GND) | GND | GND |
| 23 (GPIO11, SCLK) | LV1 ↔ HV1 | SCK |
| 19 (GPIO10, MOSI) | LV2 ↔ HV2 | SI |
| 21 (GPIO9, MISO) | LV3 ↔ HV3 | SO |
| 24 (GPIO8, CE0) | LV4 ↔ HV4 | CS |
| 22 (GPIO25) | LV5 ↔ HV5 | INT |

A `config.txt` sora ehhez a modulhoz:

```
dtoverlay=mcp2515-can0,oscillator=8000000,interrupt=25,spimaxfrequency=1000000
```

- A HW-184 kristálya általában **8 MHz** (a fém tokon `8.000` felirat). Ha nálad más, az `oscillator` értékét ahhoz igazítsd.
- Ha a `dmesg` hibát mutat, vagy üzenetek vesznek el, vedd le a `spimaxfrequency`-t `500000`-re. A BSS138-as szintillesztők nem gyorsak, de a 95 kbit/s-os buszhoz ennyi bőven elég.

**2. megoldás, SMD forrasztással: meghajtócsere.**
- Cseréld le a TJA1050-et (U1, 8 lábú) **SN65HVD230**-ra. Lábkiosztásra kompatibilis ⚠️, és 3,3 V-ról megy.
- Utána az egész modul 3,3 V-ról járhat (VCC a Pi 1-es lábára), szintillesztő nélkül.

**Netes mod, nem ajánlott:** ha a TJA1050 tápját átvágással leválasztod 5 V-ra, az MCP2515 pedig 3,3 V-ot kap, a TJA1050 5 V-os kimenete megy az MCP2515 bemenetére. Ez a specifikáción kívül van.

**A HW-184 jumperei:**
- **J1 = 120 Ω-os lezáró ellenállás.** Az autóhoz **vedd le a jumpert**, mert a busz már le van zárva.
- **J3:** ugyanaz a H és L, mint a csavaros sorkapocson.

**Földelés:** a 4-es vagy 5-ös OBD lábat a modul GND tüskéjére (J4) kösd, ugyanoda, ahová a Pi földje megy.

---

## 2. A Pi előkészítése otthon

### 2.1 Rendszer

1. **Raspberry Pi Imager** → *Raspberry Pi OS Lite (64-bit)*.
2. Az írás előtti beállításoknál (*Edit settings*) add meg:
   - hostname: `autodisplay`;
   - felhasználónév és jelszó;
   - Wi-Fi: **a telefonod hotspotjának** neve és jelszava;
   - SSH bekapcsolva.
3. Kapcsold be a telefon hotspotját, indítsd el a Pi-t.
4. A hotspot eszközlistájában látod az IP-címét. Telefonról: `ssh felhasznalo@<IP>`.

### 2.2 A CAN HAT bekapcsolása

1. **Nézd meg a kristályt a HAT-en:** a fém tokon `12.000` vagy `8.000` felirat van. A 2019 augusztusa utáni lapok 12 MHz-esek ✅.
2. Írd a `/boot/firmware/config.txt` végére:
   ```
   dtparam=spi=on
   dtoverlay=mcp2515-can0,oscillator=12000000,interrupt=25,spimaxfrequency=2000000
   ```
   8 MHz-es kristálynál a második sor: `dtoverlay=mcp2515-can0,oscillator=8000000,interrupt=25,spimaxfrequency=1000000` ✅ ([Waveshare wiki](https://www.waveshare.com/wiki/RS485_CAN_HAT)).

### 2.3 Programok

```
sudo apt update
sudo apt install -y can-utils tmux
sudo reboot
```

### 2.4 Ellenőrzés

```
dmesg | grep -i mcp251      # ezt kell látnod: "mcp251x spi0.0 can0: MCP2515 successfully initialized."
ip link show can0           # léteznie kell a can0-nak
```

### 2.5 Asztali próba, autó nélkül (belső visszacsatolás)

Ez azt ellenőrzi, hogy a Pi és a HAT jól beszélget. A HAT ekkor nincs bekötve sehova.

```
sudo ip link set can0 up type can bitrate 95238 loopback on
candump can0 &
cansend can0 123#DEADBEEF
#  ezt kell kiírnia:  can0  123   [4]  DE AD BE EF
kill %1
sudo ip link set can0 down
```

### 2.6 A bitráta ellenőrzése

```
sudo ip link set can0 up type can bitrate 95238 listen-only on
ip -details link show can0
#  keresd benne: "LISTEN-ONLY" és "bitrate 95238"
sudo ip link set can0 down
```

A 95 238 bit/s = 2 MHz / 21. Az MCP2515 ezt pontosan tudja 8, 12 és 16 MHz-es kristállyal is.

### 2.7 A felvevő szkript

Másold át a repóból a [`tools/can-felvetel.sh`](../tools/can-felvetel.sh) fájlt a Pi-re, például a laptopodról:

```
scp tools/can-felvetel.sh felhasznalo@<IP>:~/
ssh felhasznalo@<IP> chmod +x can-felvetel.sh
```

---

## 3. Bekötés az autóban

### 3.1 Hol van az OBD aljzat

Astra H-n a **középkonzolon, a kézifék alatt, egy takarófedél mögött** ✅ ([opelbook](https://www.opelbook.ru/en/astra/H/power/ignition/sistema-bortovoy-samodiagnostiki-obd), [klavkarr](https://www.klavkarr.com/location-plug-connector-obd/Opel-astra)). Ugyanott van, ahol a gyári AUX aljzat is.

### 3.2 Melyik láb mire megy

| OBD láb | Jel | HAT sorkapocs |
|---|---|---|
| **3** | MS-CAN H | **H** |
| **11** | MS-CAN L | **L** |
| **4 vagy 5** | föld | GND, ha a HAT-en van ilyen kivezetés ⚠️ |
| ~~16~~ | +12 V | **NE kösd be!** |
| ~~6, 14, 1~~ | HS-CAN, SW-CAN | **ne nyúlj hozzájuk** |

**A földről:**
- Ha a Pi-t az autós USB-töltő táplálja, a közös föld a töltőn keresztül megvan. A 4/5-ös láb bekötése ekkor is ajánlott, de nem kötelező.
- Powerbanknál viszont kell a földvezeték: a HAT GND kivezetésére, ha van, vagy a Pi egyik GND tüskéjére.

**A kábelről:**
- A H és L ért sodord össze.
- A kábel legyen rövid, 1 m alatt.

### 3.3 Mérés a bekötés előtt (multiméter)

1. **Gyújtás le, kulcs ki, várj 5 percet,** amíg a busz elalszik.
2. **Ellenállás a 3-as és a 11-es láb között.** Kb. **60 Ω** a jó érték: a busz két végén lévő 120 Ω-os lezáró párhuzamosan. Ez igazolja, hogy jó lábon vagy.
3. **Gyújtás rá, feszültség a földhöz (4/5-ös láb) képest:**
   - 3-as láb: kicsit **2,5 V fölött** (kb. 2,6–3 V) = CAN-H;
   - 11-es láb: kicsit **2,5 V alatt** (kb. 2–2,4 V) = CAN-L.
   - Ha fordítva van, cseréld meg a H-t és az L-t.

### 3.4 A HAT lezáró ellenállása ⚠️

- Kikapcsolt, kihúzott HAT-en mérd meg az ellenállást a H és L sorkapocs között. Ha kb. 120 Ω, akkor a lapon lezáró ellenállás van.
- Rövid felvételhez rövid kábellel így is működni szokott.
- Ha a felvétel alatt az autó bármi furcsát csinál (hibaüzenet a GID-en, villogó műszerfal), **azonnal húzd ki az OBD dugót**.
- A végleges beépítéshez a lezáró ellenállást el kell távolítani.

---

## 4. A felvétel

1. A Pi legyen bekötve és bekapcsolva, a telefon hotspotja menjen, és SSH-zz be.
2. Indítsd **tmux**-ban, hogy egy SSH-szakadás ne állítsa le:
   ```
   tmux new -s can
   ./can-felvetel.sh
   ```
   Ha szakad a kapcsolat: `ssh …`, majd `tmux attach -t can`.
3. A szkript lépésenként végigvezet. Minden lépés előtt Entert nyomsz, ebből tudom utólag, melyik üzenet melyik mozdulathoz tartozik. A lépések:
   1. kulcs a zárban, majd gyújtás, majd rádió be;
   2. **rádió gombjai egyenként**: beírod a gomb nevét, aztán megnyomod;
   3. **kormánygombok egyenként**, ugyanígy;
   4. GID lapozás (BC1, BC2, Timer), AUX forrás, klíma, világítás, irányjelzők, ajtó;
   5. motorindítás, hátramenet;
   6. **rövid menet** – menet közben a telefont csak utas kezelje!;
   7. motor le, gyújtás le, 2 perc várakozás.
4. **Ha élőben is látni akarod, mi változik:** egy második tmux ablakban (`Ctrl+B`, majd `C`) futtasd ezt:
   ```
   cansniffer -c can0
   ```
   Ez a változó bájtokat kiemeli, így gombnyomásnál látszik, melyik azonosító ugrik.
5. A felvétel bármikor leállítható **Ctrl+C**-vel. A fájlok akkor is megmaradnak.

---

## 5. A log elküldése

A szkript egy `felvetel-ÉÉÉÉHHNN-ÓÓPPMM/` mappát hoz létre a Pi-n:

| Fájl | Tartalom |
|---|---|
| `can.log.gz` | a nyers forgalom, tömörítve (candump formátum, időbélyeggel) |
| `jelolok.txt` | mikor kezdődött melyik lépés, és melyik gombot nyomtad |
| `interfesz.txt` | az interfész beállításai és hibaszámlálói (a felvétel elején és végén) |

1. Másold le a mappát, például laptopra:
   ```
   scp -r felhasznalo@<IP>:~/felvetel-* .
   ```
2. Töltsd fel ide a chatbe mindhárom fájlt.

A szkript a végén kiírja az üzenetek számát és a leggyakoribb azonosítókat. Ha ott látod a `450`, `4E8`, `206` és `6C1` azonosítókat, akkor jó a felvétel.

---

## 6. Hibaelhárítás

| Tünet | Ok és teendő |
|---|---|
| Nincs `can0` | Elírás a `config.txt`-ben, vagy rossz a kristály értéke. Nézd meg: `dmesg \| grep -i mcp251`. Próbáld `spimaxfrequency=1000000`-rel, vagy még kisebbel (400000). |
| A loopback próbán nem jön vissza semmi | A HAT nem ül rendesen a tüskesoron, vagy rossz az `interrupt=25`. |
| A `can0` fent van, de a felvétel 0 üzenet | A busz alszik (adj gyújtást). Vagy fel van cserélve a H és az L, vagy nincs közös föld, vagy rossz a bitráta (`ip -details link show can0`). |
| Sok hiba, `ERROR-PASSIVE` vagy `BUS-OFF` az `interfesz.txt`-ben | Rossz bitráta, laza érintkezés, túl hosszú vagy nem sodrott kábel, vagy a HAT lezáró ellenállása (3.4). |
| A szkript azt írja: „nincs listen-only módban” | `-n` kapcsolóval futtattad egy kézzel felhúzott interfészen. Futtasd `-n` nélkül, akkor a szkript maga állítja be. |
