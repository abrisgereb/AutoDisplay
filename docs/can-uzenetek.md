# Opel Astra H – CAN-busz referencia

A fedélzeti gép CAN démonjához gyűjtött adatok nyílt forrású projektekből és fórumokból (2026. november).

Jelölések:
- ✅ = legalább 2 független forrás egyezik
- ⚠️ = egy forrás vagy következtetés

**Minden ⚠️-es tételt saját CAN loggal ellenőrizz, mielőtt adsz a buszra.**

Fő források:
- [EHU32](https://github.com/PNKP237/EHU32) (forráskód és wiki)
- [MPi3](https://github.com/JJToB/MPi3)
- [JJToB Car-CAN-Message-DB](https://github.com/JJToB/Car-CAN-Message-DB/tree/master/Opel/Astra/H)
- [Koretion CAN_SIGNALS](https://github.com/Koretion/Astra-H-Launcher/blob/main/docs/CAN_SIGNALS.md)
- [ElKaPa opel-can-swc-adapter](https://github.com/ElKaPa/opel-can-swc-adapter)
- [Gegerd/Astra-H](https://github.com/Gegerd/Astra-H)
- [Flex2002/Opel_CAN_TID](https://github.com/Flex2002/Opel_CAN_TID)
- [iequa/CAN_OVC](https://github.com/iequa/CAN_OVC)
- [Zafira B DBC](https://github.com/xymetox/OpelZafiraB_CanBus_dbc)

---

## 1. Buszok

| Busz | Sebesség | OBD-II tű | Kik vannak rajta |
|---|---|---|---|
| **HS-CAN** | 500 kbit/s | 6 / 14 | motorvezérlő, váltó, ABS/ESP, CIM ✅ |
| **SW-CAN** (egyvezetékes, LS-CAN) | 33,333 kbit/s | 1 | CIM, műszerfal (IPC), UEC, REC, légzsák (SDM), PDC, TPMS, kijelző… ✅ |
| **MS-CAN** | **95,238 kbit/s** | **3 / 11** | rádió, kijelző (TID/BID/GID/CID), klímapanel (ECC), UHP, Navi ✅ |

**Gateway-ek** ⚠️ (egy forrás + erős közvetett bizonyíték):
- A **CIM** köti össze a HS-CAN-t és az SW-CAN-t.
- **A kijelző** (TID/BID/GID/CID) köti össze az SW-CAN-t és az **MS-CAN**-t.
- Az MS-CAN-en látható járműadat-üzenetek (0x180, 0x188, 0x450, 0x4E8, 0x4EC–0x4EE, 0x68x) szinte mind `0x46` bájttal kezdődnek. Ez a kijelző csomópontszáma (diagnosztikai ID-i 0x246/0x546).
- **Következmény:** ha a kijelzőt kihúzod, az MS-CAN-ről eltűnnek a járműadatok. A kijelző tehát maradjon bekötve, vagy a Pi olvassa közvetlenül az SW-CAN-t és a HS-CAN-t.

---

## 2. Csatlakozási pontok

| Hol | Lábak | Megjegyzés |
|---|---|---|
| **OBD-II aljzat** | 3, 11 = MS-CAN · 6, 14 = HS-CAN · 1 = SW-CAN · 4, 5 = föld | a legegyszerűbb, roncsolásmentes. A H/L irányt mérd ki ⚠️ |
| **Kijelző csatlakozó** (BID/GID/CID) | 1, 2 = föld · 3, 5 = +12 V · **19 = MS-CAN L · 20 = MS-CAN H** ✅ | egy fórumlista szerint az SW-CAN a 17–28 közötti lábakon van, ez nem ellenőrzött ⚠️ |
| Rádió Quadlock | MS-CAN rajta van | megbízható lábszámot nem találtam ⚠️ |

---

## 3. Bitráta beállítása

- 95 238 bit/s = 2 MHz / 21. Az MCP2515 bármelyik szokásos kristállyal pontosan tudja:

  | Kristály | BRP | Időkvantum (NTQ) |
  |---|---|---|
  | 8 MHz | 1 | 21 |
  | 12 MHz (Waveshare RS485 CAN HAT, 2019 aug. után) | 2 | 21 |
  | 16 MHz (PiCAN2, Waveshare 2-CH CAN HAT+) | 3 | 21 |

- Kézi regiszterbeállítás 8 MHz-es MCP2515-höz (pl. Arduino): `CNF1=0x01, CNF2=0xBB, CNF3=0x07`.
- Linux / SocketCAN:
  ```
  sudo ip link set can0 up type can bitrate 95238 listen-only on   # először csak hallgatunk
  candump -l can0                                                   # log fájlba
  ```
- USB-CAN: CANable vagy candleLight csak **candleLight firmware-rel** (gs_usb driver) jó. Az slcan firmware csak fix bitrátákat ismer (S0–S8), így a 95,238k-t nem tudja.

---

## 4. Gombok

### 0x201 – rádió előlap gombjai ✅

Formátum: `[00 = elengedés / 01 = lenyomás] [gomb ID] [tartás-számláló]`

Tekerőgomb forgatása: `08 6A 01` (jobbra) / `08 6A FF` (balra).

| Gomb ID | Gomb |
|---|---|
| 01 | BC |
| 6F | OK |
| 6C | jobbra |
| 6D / D6 | balra |
| E0 | FM/CD (forrás) |
| FF | Settings |
| 30–39 | számgombok 0–9 |

### 0x206 – kormánygombok ✅

Ugyanaz a felépítés. Az első bájt `08` görgetésnél.

| Gomb ID | Gomb |
|---|---|
| 81 / 82 | bal felső / bal alsó |
| 83 | bal görgő forgatás |
| 84 | bal görgő nyomás |
| 91 | következő |
| 92 | előző |
| 93 | hangerő görgő |

Nem tisztázott, hogy a 0x206-ot a kijelző gateway-eli (SW-CAN 0x175-ből), vagy a CIM küldi ⚠️.

### 0x208 – klímapanel gombja

`0x16` = forgatás, `0x17` = nyomás.

---

## 5. Szöveg a gyári kijelzőre (0x6C1 és társai)

### Protokoll

- **ISO-TP** jellegű, több frame-es átvitel a kijelző felé.
- A kijelző a **küldő ID − 0x400** címen ad flow controlt: a 0x6C1-re 0x2C1-en válaszol ✅.
- Fejléc: `C0|40 00 <hossz-3> <típus>`

  | Típus | Jelentés |
  |---|---|
  | 03 | audio |
  | 01 | FM menü |
  | 05 | CD menü |
  | 07 | telefon |
  | 09 | navigáció |
  | 0A | klíma |

- Ezután mezők jönnek: `[mező ID] [karakterek száma] [UTF-16BE szöveg]`.

  | Mező ID | Sor |
  |---|---|
  | 0x10 | középső sor (1 soros kijelzőn az egyetlen) |
  | 0x11 | felső sor |
  | 0x12 | alsó sor |

- Formázás ESC-kódokkal, pl. `ESC[fS_gm`.

### Küldők

| ID | Küldő |
|---|---|
| 0x6C1 | rádió |
| 0x6C7 | UHP (gyári kihangosító) |
| 0x6C8 | klímapanel |

A kijelző a 0x6C0–0x6CF tartomány nem használt ID-it is elfogadja. Ezzel elkerülhető, hogy a Pi a rádióval versenyezzen ugyanazon az ID-n ✅.

### Buktatók (EHU32 wiki)

- Ha az utolsó frame teljesen tele van, a kijelző eldobja az üzenetet. Szükség esetén tölts ki szóközzel.
- Ismeretlen karakternél a sor többi része levágódik.
- A rádió átvitelét blokkolni lehet `2C1 32…` üzenettel, vagy `30 00 7F` flow controllal. Így lehet felülírni a rádió szövegét.

### Rádió nélkül („rádió él” emuláció) ✅

- Ha nincs rádió, a kijelző nem fogad külső szöveget, amíg nem kapja meg rendszeresen (1–2,5 másodpercenként) ezt:
  ```
  0x691  41 00 60 02 82 00 00 2E
  ```
- A CAN_OVC projekt `…02 03…` változatot küld ⚠️.
- Forrás: Flex2002/Opel_CAN_TID, iequa/CAN_OVC, [MPi3 issue #1](https://github.com/JJToB/MPi3/issues/1).

---

## 6. Mérésiblokk-lekérdezés (diagnosztika)

| Kérés → Válasz | Kitől | Blokkok |
|---|---|---|
| 0x246 → 0x546 | kijelző | 0B hűtővíz (b5 − 40) · 0E sebesség (b2..3 / 128) · 13 feszültség (b6 / 10) ✅ |
| 0x248 → 0x548 | klímapanel | 07 feszültség · 10 külső és hűtővíz-hőmérséklet (/10) · 11 fordulat és sebesség ✅ |

---

## 7. Járműállapot az MS-CAN-en

A `b0`, `b1`… a bájt sorszámát jelöli, 0-tól számolva.

| ID | Tartalom | Formátum | Megb. |
|---|---|---|---|
| 0x450 | kulcs állapot + világítás | `46 07 <kulcs> <fényerő>`. Kulcs: 00 nincs, 04/05 bent, 06 gyújtás (a források nem egyeznek, hogy 05 vagy 06 a gyújtás). Fényerő: 00 = nappal, egyébként tompítási szint | ✅ / ⚠️ |
| 0x4E8 | fordulat, sebesség, tolatás | fordulat b2..3 / 4 · sebesség b4..5 / 128 · b6 & 0x04 = hátramenet | ✅ (bájtsorrend ⚠️) |
| 0x4EC | hűtővíz | b2 − 40 °C | ⚠️ |
| 0x4ED | befecskendezés-számláló (fogyasztásszámításhoz) | nyers számláló | ⚠️ |
| 0x4EE | hatótáv | b2..3 × 0,5 km + alacsony-hatótáv jelző | ⚠️ |
| 0x188 | gyújtás + kerékút-számláló | b1: 0A / 00 | ✅ |
| 0x180 | dátum, idő | | ⚠️ |
| 0x682 / 0x683 | külső hőmérséklet (szenzor / kijelzett) | / 2 − 40 °C | ⚠️ |
| 0x68C | üzemanyagszint | 94 − x / 2 liter (szenzorfüggő) | ⚠️ |
| 0x684 / 0x685 | guminyomás (TPMS) | | ⚠️ |
| 0x501 | CD30MP3 elalszik | b3 = 0x18 | ⚠️ |
| 0x697 | ébresztés | | ⚠️ |
| 0x2B0 | GID menü / figyelmeztető ablak | csak jelölt | ⚠️ |

**Ajtók:** az MS-CAN-en nem találtam. Az SW-CAN-en a 0x230 b2-ben vannak: 0x40 vezető, 0x10 utas, 0x04 csomagtartó.

---

## 8. Hasznos üzenetek más buszokon

| Busz | ID | Tartalom |
|---|---|---|
| SW-CAN | 0x445 | külső hőmérséklet |
| SW-CAN | 0x440 | idő |
| SW-CAN | 0x235 | fényerő |
| SW-CAN | 0x375 | üzemanyag |
| SW-CAN | 0x500 | feszültség |
| SW-CAN | 0x260 | irányjelzők |
| SW-CAN | 0x280 | CIM hangjelző (gong) |
| SW-CAN | 0x130 | befecskendezés |
| SW-CAN | 0x110 | kerékút |
| HS-CAN | 0x110 | fordulat |
| HS-CAN | 0x410 | sebesség |
| HS-CAN | 0x381 | világítás |
| HS-CAN | 0x510 | hűtővíz |

**A HS-CAN-re soha ne adj.**

---

## 9. Ellenőrizendő a saját autón (CAN loggal vagy méréssel)

1. Megy-e a kijelző gateway funkciója (a 0x46-os üzenetek) rádió nélkül, és leáll-e, ha a kijelzőt kihúzod.
2. Mi a 0x450 b2 kulcsállapot-kódolása, és hogyan kódolja a gyújtást a 0x188 és a 0x4ED.
3. Rádió nélkül működik-e a kijelző beállítások menüje és óraállítása 0x691 emulációval és injektált 0x201 *Settings* (FF) gombnyomásokkal.
4. Melyik lábon van a CAN a rádió Quadlock csatlakozóján (rádió címke, TIS2000, mérés).
5. Ki küldi a 0x206-ot: a kijelző (SW 0x175-ből) vagy a CIM.
6. Mi a 0x68C üzemanyag-képlete, és milyen a 0x4E8 sebesség-bájtsorrendje.
7. Honnan szól a parkolóradar (PDC) hangja.
8. Milyen formátumú a 0x2B0 figyelmeztető ablak.
9. Vannak-e ajtó üzenetek az MS-CAN-en.
10. CID esetén elfogadja-e az RGB bemenet a Pi képét a natív időzítéssel.

### Felvétel

A pontos eszközlista, a bekötés és a lépésenként végigvezető szkript: **[docs/can-felvetel.md](can-felvetel.md)** és [`tools/can-felvetel.sh`](../tools/can-felvetel.sh).
