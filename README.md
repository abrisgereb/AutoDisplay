# AutoDisplay – Android Auto fedélzeti gép Opel Astra H-ba (DIY)

Kutatási összefoglaló és építési terv. Állapot: **2026. november**.

Jelölések: ✅ = több független forrás egyezik · ⚠️ = egy forrás vagy következtetés, élesben ellenőrizni kell (CAN-sniffeléssel, méréssel) · *[becslés]* = nem konkrét hirdetésből származó ár.

A CAN-busz részletes leírása (ID-k, bájtok, szövegküldés a gyári kijelzőre): **[docs/can-uzenetek.md](docs/can-uzenetek.md)**

---

## Röviden

- **Megépíthető, nagyrészt használt alkatrészekből**, a meglévő RPi4-en felül kb. **25–55 ezer Ft-ból** (rádió marad), vagy **40–75 ezer Ft-ból** (Pi a rádió helyén).
- **Ne lecseréld, hanem egészítsd ki a gyári rendszert.** Az Astra H gyári kis kijelzője (TID/BID/GID/CID) nemcsak kijelző. Ez a **gateway**, ami az autó adatait (sebesség, fordulat, hűtővíz, hatótáv, világítás, gyújtás) átadja az MS-CAN buszra. A fedélzeti számítógépet (BC) is **a kijelző maga számolja**. Ha bent marad és be van kötve, minden gyári funkció megmarad, a Pi pedig hozzáadja az Android Autót. ⚠️ (erős következtetés, több jel támasztja alá)
- **A Pi a CAN-buszon keresztül épül be:**
  - a kormánygombokkal vezérelhető az Android Auto zene;
  - a gyári kijelzőn megjelenik a szóló szám, a hívó neve, a navigációs utasítás.
  - Ezt Astra H-n mások már megcsinálták: **EHU32** (ESP32), **MPi3** (Raspberry Pi + python-can). Van mire építeni.
- **Szoftver:**
  - Az **OpenAuto Pro halott**: 2024-ben megszűnt, az Android Auto 12.6 utáni verzióival nem működik.
  - Ma reális választás a **[LIVI](https://github.com/f-io/LIVI)**: aktív, vezetékes és vezeték nélküli AA, Pi4-en Debian Trixie-vel.
  - Másik lehetőség az **[OpenAuto Prodigy](https://github.com/mrmees/openauto-prodigy)**: csak vezeték nélküli, de van HFP pluginja.
- **Kihangosítás:**
  - Android Autóban a hívás hangja **mindig Bluetooth HFP-n megy**, akkor is, ha az AA USB-kábelen fut.
  - Ehhez **külön USB-s Bluetooth dongle** kell, mert a Pi4 beépített BT-je híváshangnál problémás.
  - Kell még egy USB hangkártya és egy autós mikrofon.
- **Samsung S20 FE** = a telefon, ami az Android Autót futtatja (vezeték nélküli AA-t is tud).
- **Kindle:** autóba nem való. Üzemi hőmérséklete 0–35 °C, az e-ink lassú, és a lítium akku nem bírja a nyári autót.
- **Ha csak gyorsan működő AA kell:** egy használt, Astra H-hoz gyártott kínai Android fejegység CAN-dobozzal **40–60 ezer Ft**. Ez nagyjából annyi, mint a DIY, kevesebb munkával, de gyengébb integrációval. Lásd a [8. fejezetet](#8-vásárlás-vagy-építés).

---

## 1. Első lépés: mi van pontosan a kocsiban?

A terv részletei ettől függnek, ezt nézd meg elsőként.

### Kijelző

| Típus | Hogyan ismered fel | Mit tud |
|---|---|---|
| **TID** | egysoros, monokróm, alatta 2 kis gomb | óra, dátum, külső hőmérséklet, rádió szöveg. **Nincs fedélzeti számítógép (BC)** ✅ |
| **BID** | szöveges, monokróm | + BC, Check-Control figyelmeztetések |
| **GID** | grafikus, monokróm (1 vagy 3 soros) | + menük, BC1/BC2, stopper, klíma (ECC) kijelzés, telefon (UHP) menük, CD70 nyilas navigáció ✅ |
| **CID** | színes (~6,5") | mint a GID + térképes navigáció (CD70/DVD90) ✅ |

### Rádió és AUX bemenet

| Rádió | AUX |
|---|---|
| CD30 (alap) | nincs |
| CD30MP3 | csak bizonyos hardverváltozatokban, és **OP-COM/Tech2-vel aktiválni kell** ✅ |
| CDC40 Opera | a 12 tűs csatlakozón (ha nem foglalja DAB modul) |
| CD70 Navi | csak 2007/08-as Navi szoftverrel + kódolással, néha SMD ellenállás pótlásával ⚠️ |
| CD40USB | USB + AUX |

A 2008-as modellévtől (kb. 2007/08-tól) gyári AUX aljzat is lehet a kézifék mellett. ⚠️

### Gyári kihangosító

Gyári kihangosító (UHP vagy Bluetooth UHP4) GID/CID kijelzővel volt. Ha van, a tetőkonzolban mikrofon is van.

**Írd meg nekem a kijelző és a rádió típusát, és hogy van-e AUX és gyári kihangosító.** Ezek alapján tudom pontosítani a tervet.

---

## 2. Mit tud a gyári kijelző, és hogyan fedjük le mindet

Az alapelv: **a gyári kijelző marad és működik**, így minden, amit ma tud, megmarad. A Pi ezt kiegészíti, és amit lehet, a nagy képernyőn is megmutat.

| Funkció | Ki csinálja ma | A tervben |
|---|---|---|
| Óra, dátum | a kijelző (a rádió RDS-sel szinkronizálja) | marad a gyári kijelzőn, és a Pi képernyőjén is |
| Külső hőmérséklet | a kijelző | marad, és a Pi dashboardon is (0x683) |
| BC: hatótáv, pillanatnyi és átlagfogyasztás, átlagsebesség, megtett út, stopper, BC1/BC2 | **a kijelző számolja** (BID/GID/CID) | marad: kormány bal görgő vagy rádió BC gomb. A Pi dashboardon: hatótáv a CAN-ról (0x4EE). A fogyasztást a Pi maga számolja a befecskendezés-számlálóból (0x4ED) és a megtett útból (0x188) ⚠️ |
| Check-Control figyelmeztetések (izzó, ablakmosó, hűtőfolyadék, TPMS, kulcselem) | a kijelző | marad a gyári kijelzőn. Az MS-CAN-es formátuma nem ismert ⚠️ |
| Rádió/CD szöveg | rádió → kijelző (0x6C1) | **+ a Pi kiírja az AA zeneszámot, a hívó nevét, a navigációs utasítást** (szabad ID a 0x6C0–0x6CF tartományból) |
| Beállítások menü: idő/dátum, RDS óra, nyelv, mértékegység, kontraszt, nappal/éjszaka, hangbeállítások | a rádió *Settings* gombja nyitja | A változat: marad. B változat (rádió nélkül): a Pi emulálja a rádió gombjait (0x201) ⚠️ kísérleti |
| Klíma (ECC) kijelzés (GID/CID) | klímapanel → kijelző | marad |
| Telefon menük (UHP) | UHP → kijelző | az Android Auto veszi át |
| Figyelmeztető hangok, index kattogás | **a CIM saját hangszórója, nem a rádió** | marad mindkét változatban. A parkolóradar hangjának forrása nem ellenőrzött ⚠️ |

**Új funkciók:**
- Android Auto: navigáció, zene, hívás, Google Assistant.
- A kormánygombok vezérlik az AA-t (következő, előző, play/pause; a B változatban hangerő is).
- Automatikus éjszakai mód és képernyő-fényerő a világítás jelből (0x450).
- Tolatás jel (0x4E8), ha később tolatókamera kell.

---

## 3. Ajánlott architektúra

```
                         ┌───────────────────────────────────┐
   Samsung S20 FE ───────┤ Raspberry Pi 4 (RPi OS Lite, Trixie)│
   (Android Auto)  5 GHz │  • LIVI – Android Auto fejegység    │── HDMI/DSI ──► 7" érintőkijelző
                   Wi-Fi │  • CAN démon (Python, python-can)   │
   hívás: BT HFP ────────┤  • PipeWire + visszhangszűrés       │
                         │  USB BT dongle │ USB hangkártya     │
                         └──────┬─────────┴──────┬────────┬───┘
                                │ CAN HAT        │ hang ki│ mikrofon be
                                │ 95,238 kbit/s  │        └── autós mikrofon (tetőkárpit / A-oszlop)
                                ▼                ▼
          OBD 3/11 (MS-CAN) ◄───┘        A: gyári rádió AUX ──► hangszórók
                  │                      B: erősítő ───────────► hangszórók
   ┌──────────────┴──────────────────────────────────┐
   │ MS-CAN: rádió · gyári kijelző (gateway) · klíma  │
   │  ← kormánygombok (0x206), világítás, gyújtás,    │
   │    sebesség, hatótáv…                            │
   │  → szöveg a gyári kijelzőre (0x6C0–0x6CF)        │
   └──────────────────────────────────────────────────┘
```

### A változat: „a rádió marad” (ajánlott kezdés)

- Gyári rádió és gyári kijelző bent marad, **semmi gyári funkció nem vész el**, és bármikor visszaállítható.
- **Hang:** a Pi hangja a rádió **AUX bemenetére** megy. A hangerőt a rádió gombja és a kormánygomb állítja, ahogy eddig.
- **Feltétel:** AUX-os rádió (lásd 1. fejezet). Ha nincs, vagy használt CD30MP3 kell AUX-szal (10–25 ezer Ft) aktiválással, vagy rögtön a B változat.
- **Korlát:**
  - Az AA hangja (zene, navigációs bemondás, hívás) csak akkor hallatszik, ha a rádió AUX forráson áll.
  - A gyakorlatban mindent az AA-n hallgatsz (rádiót is, streaming appal).
  - Kísérleti lehetőség, hogy hívásnál a Pi CAN-en „megnyomja” a rádió forrásváltó gombját ⚠️.
- **Képernyő:** tartóval a műszerfalon. A legkevésbé szép rész, de nem kell hozzá bontani.

### B változat: „Pi a rádió helyén” (szebb végállapot)

- A gyári rádió kijön. Helyére **Astra H 2DIN keret** kerül, benne a 7"-os kijelző, mögötte a Pi.
- Kell egy **4 csatornás erősítő** és egy Quadlock→ISO adapter a hangszórókhoz.
- **A gyári kijelző a helyén marad, bekötve**: óra, külső hőmérséklet, BC és Check-Control továbbra is megy rajta.
- A Pi emulálja a rádió „élek” üzenetét (0x691). Enélkül a kijelző nem fogad külső szöveget ✅.
- **Mi vész el, és mivel pótolható:**
  - FM rádió: AA streaming appal, vagy opcionálisan RTL-SDR stick.
  - RDS óraszinkron.
  - A rádió *Settings* gombja: a Pi CAN-en emulálja ⚠️. TID-en az óra a kijelző saját gombjaival is állítható. Végső esetben OP-COM.
- Hangerő: a kormány hangerő-görgője (0x206) a Pi hangerejét állítja.
- Előbb érdemes CAN-sniffeléssel igazolni, hogy a beállítások menü emulálható. Enélkül GID/CID-en évente kétszer (óraátállításkor) OP-COM kellene.

> **Fontos:** a gyári kijelzőt ne húzd ki és ne vedd ki. Ha kell a helye (pl. a 7"-os képernyő a kijelző helyére kerülne), költöztesd el, akár a kesztyűtartóba, de **maradjon bekötve**, mert gateway-ként és BC-számolóként kell.

### Haladó opció CID-tulajdonosoknak

A CID-nek van analóg RGB videobemenete (a CD70/DVD90 térképhez). Léteznek kereskedelmi interfészek, amelyek külső videót adnak rá (pl. pepas.cz VCU). Elvben a Pi képe is rávihető (DPI/VGA → RGB), így az AA a gyári színes kijelzőn futna. Ez kísérleti ⚠️.

---

## 4. Alkatrészlista (használt piacon, HUF)

Források: Jófogás, Hardverapró, eBay.de, AliExpress, magyar boltok. A *[becslés]* nem konkrét hirdetésből származik.

### Közös (A és B)

| Alkatrész | Mire | Használt | Új | Megjegyzés |
|---|---|---|---|---|
| Raspberry Pi 4 | fejegység | **megvan** | – | |
| microSD 32 GB, *High Endurance* | rendszer | – | 3–5 e | csak olvasható overlay-jel használd |
| 7" kijelző – hivatalos **Touch Display 2** (DSI) | AA képernyő | 12–20 e *[becslés]* | ~24–27 e | szoftveres fényerő (0–31), 720×1280, el kell forgatni |
| *vagy* 7" HDMI kapacitív 1024×600 | AA képernyő | 8–15 e *[becslés]* | 12–20 e *[becslés]* | a háttérvilágítás általában nem állítható szoftverből |
| **Waveshare RS485 CAN HAT** (MCP2515, 12 MHz) | MS-CAN | 4–6 e *[becslés]* | ~5 e + posta | vagy *2-CH CAN HAT+* (két busz: MS + HS) |
| *vagy* CANable 2.0 klón | MS-CAN, USB-n | – | 7–15 e | csak **candleLight firmware-rel** (gs_usb), az slcan nem tudja a 95,238k-t |
| OBD-II elosztó / pigtail kábel | CAN csatlakozás | – | 1–5 e *[becslés]* | |
| USB Bluetooth dongle (**CSR8510** vagy Realtek) | hívás (HFP), BT | 1–2 e | 2–4 e *[becslés]* | a Pi4 belső BT-je hívásnál problémás |
| USB hangkártya mikrofon-bemenettel (CM108/CM119) | hang ki, mikrofon be | ~1 e | 1–3 e *[becslés]* | mikrofon és hangszóró **ugyanazon** a kártyán (visszhangszűrés miatt) |
| Autós kihangosító mikrofon (3,5 mm electret) | kihangosítás | 1–3 e | 2–5 e *[becslés]* | |
| 12→5,1 V autós buck konverter, **min. 4–5 A** | táp | – | 1–4 e | |
| Relé vagy MOSFET, optocsatoló, biztosíték | gyújtásérzékelés, késleltetett leállás | – | ~2 e *[becslés]* | *vagy* CarPiHAT (táp + leállítás + CAN egyben, 15–25 e *[becslés]*) |
| Alumínium passzív hűtőház Pi4-hez | hűtés a műszerfal mögött | 1–2 e | 2–4 e *[becslés]* | |
| Földhurok-leválasztó (ground loop isolator) | zúgás ellen | – | 1–2 e *[becslés]* | csak ha zúg |

### Csak az A változathoz (rádió marad)

| Alkatrész | Használt | Új | Megjegyzés |
|---|---|---|---|
| CD30MP3 AUX-szal (ha a mostaniban nincs AUX) | 10–25 e *[becslés]* | eBay.de: kb. 6–27 e | „entheiratet” (szűz, kódolatlan) példányt keress, különben kódolni kell |
| AUX aktiválás | OP-COM klón kábel 5–10 e *[becslés]*, vagy szerviz | – | |
| AUX kábel a rádió csatlakozójához | – | 1–3 e *[becslés]* | |
| Kijelzőtartó | – | 2–5 e *[becslés]* | ne légzsák-zónában, ne a szélvédő látómezőjében |

### Csak a B változathoz (Pi a rádió helyén)

| Alkatrész | Használt | Új | Megjegyzés |
|---|---|---|---|
| Astra H 2DIN keret | 3–6 e *[becslés]* | 7–14 e | pl. Connects2 CTKVX35 / CT23VX22, InCarTec 50-841 |
| Quadlock → ISO adapter | – | 2–4 e *[becslés]* | |
| 4 csatornás autós erősítő | 10–25 e *[becslés]* | | vagy TPA3116 erősítőpanelek |
| RTL-SDR stick (FM rádióhoz, opcionális) | – | 5–10 e *[becslés]* | |

### Összesen (a Pi4-en felül)

- **A változat:** kb. **25–55 ezer Ft** (az AUX helyzetétől függően)
- **B változat:** kb. **40–75 ezer Ft**

---

## 5. Szoftver

### Operációs rendszer

**Raspberry Pi OS Lite 64-bit (Debian Trixie)**:
- A raspi-config-ban kapcsold be a csak olvasható overlay fájlrendszert. Ez az SD kártyát védi a hirtelen áramelvételtől.
- A beállításoknak elég egy kis írható partíció.
- Gyorsítsd a bootot: kapcsold ki a cloud-init-et és a wait-online-t, és lásd a Raspberry Pi RP-010196 boot-optimalizálási whitepaperét.

### Android Auto fejegység

| Projekt | Állapot (2026. nov.) | AA | Hívás (HFP) | Megjegyzés |
|---|---|---|---|---|
| **[LIVI](https://github.com/f-io/LIVI)** – **első választás** | aktív, Rust + Slint, ~1,2k ⭐, GPL-3.0 | vezetékes + vezeték nélküli | saját HFP kezelés. Pi4 + Samsung + CSR donglével javították a híváshangot (issue #385) ⚠️ | **telemetria API** (`livi-core telemetry set …`, HTTP POST `:4000/telemetry`), ide megy a CAN adat. A dashboard még fejlesztés alatt áll |
| [OpenAuto Prodigy](https://github.com/mrmees/openauto-prodigy) – tartalék | aktív, egy fejlesztő, Qt6 | csak vezeték nélküli | HFP plugin | pluginok, HTML/JS dashboard widgetek, külső adat API |
| [Crankshaft](https://github.com/opencardev/crankshaft) 1.1.x | alpha, újraírás alatt | vezetékes | „folyamatban” | most még nem ajánlott |
| OpenAuto Pro (BlueWave) | **megszűnt** | – | – | ne vegyél, ne építs rá |
| Android a Pi-n (LineageOS) + Headunit Reloaded / Open Headunit | működhet | igen | **sima Android nem tud kihangosító lenni (HFP sink)** | a hívás miatt nem ajánlott |

### Saját CAN démon (Python + python-can, SocketCAN)

Ez köti össze az autót és az AA-t. Referenciakód Astra H-ra: [EHU32](https://github.com/PNKP237/EHU32) (ESP32/C++), [MPi3](https://github.com/JJToB/MPi3) (Pi + python-can).

1. **Kormánygombok** (0x206) → AA billentyűk: következő/előző szám, play/pause; B változatban hangerő is.
2. **Világítás** (0x450) → éjszakai mód és háttérfény. **Tolatás** (0x4E8).
3. **Telemetria** → LIVI dashboard: sebesség, fordulat, hűtővíz, külső hőmérséklet, hatótáv, akkufeszültség, saját fogyasztásszámítás.
4. **Szöveg a gyári kijelzőre** (ISO-TP, 0x6C0–0x6CF): szóló szám, hívó neve, következő navigációs lépés.
5. **B változatban** a rádió emulálása: „élek” üzenet 0x691, és kísérletileg a *Settings* gomb (0x201).

### Hang

- PipeWire, `module-echo-cancel` (WebRTC visszhangszűrés).
- A mikrofon és a kimenet **ugyanazon a USB hangkártyán** legyen, különben a visszhangszűrés rosszul működik.

---

## 6. Bekötés

### CAN

- **MS-CAN, 95,238 kbit/s**, az OBD aljzat **3-as és 11-es tűjén** ✅, föld a 4/5-ös tűn.
  - A szokásos GM/Opel kiosztás szerint 3 = CAN-H és 11 = CAN-L, de ezt mérd ki ⚠️: járó buszon a CAN-H átlagosan kicsit 2,5 V fölött, a CAN-L kicsit alatta van.
  - Alternatív pont a gyári kijelző csatlakozója: 19 = CAN-L, 20 = CAN-H.
- Az MCP2515 a 95,238 kbit/s-ot **pontosan** tudja bármelyik szokásos kristállyal (8/12/16 MHz), mert 95 238 = 2 MHz / 21:
  ```
  sudo ip link set can0 up type can bitrate 95238 listen-only on
  candump -l can0
  ```
- **Először csak hallgass (listen-only).**
  - Adni csak az MS-CAN-re szabad, csak ismert üzeneteket, ritkítva.
  - A HS-CAN-re (motor, ABS) soha ne adj.
  - Hibás CAN-adás furcsaságokat okozhat: egy kínai dekóderrel Astra H-ban ki-be kapcsolgatott a klíma.
- A HAT 120 Ω-os lezáró ellenállását, ha lehet, kapcsold ki, mert az autó busza már le van zárva ⚠️.

### Táp

- Az Astra H rádiócsatlakozóján (Quadlock) **nincs gyújtásra kapcsolt (ACC) vezeték** ✅. A rádió állandó +12 V-ot kap, és CAN-en ébred.
- A **12 V-os aljzat állandó tápos**. Mögötte van egy vékony, gyújtásra kapcsolt (lámpa) vezeték, de ezt **csak relé vezérlésére** használd ✅. Másik lehetőség egy *add-a-fuse* egy gyújtásra kapcsolt biztosítékhelyen.
- Elv:
  ```
  állandó +12 V ─ biztosíték (5 A) ─ öntartó relé/MOSFET ─ buck 5,1 V ─ Pi
  gyújtás jel ─ optocsatoló ─ GPIO
  ```
  1. Gyújtás le után a Pi 1–2 percet vár, hogy egy rövid megállásnál ne álljon le.
  2. Utána leáll.
  3. A `gpio-poweroff` elengedi a relét.
- **Kikapcsolt áramfelvétel < 1 mA legyen**, különben lemeríti az akkut. A Pi4 nem tud alvó módba menni, kb. 3 W-ot fogyaszt üresjáratban.
- Kész megoldás: CarPiHAT (táp, biztonságos leállítás, optós bemenetek világításra/tolatásra, CAN port egyben). DIY recept: [Crankshaft wiki](https://github.com/opencardev/crankshaft/wiki/Boot,-reboot-and-shutdown-the-Pi-with-ignition-key).

### Hang

- **A változat:** USB hangkártya kimenete → rádió AUX. Ha zúg, földhurok-leválasztó kell.
- **B változat:** USB hangkártya → erősítő → hangszórók (Quadlock→ISO adapter). Az erősítő *remote* bemenetét a Pi vagy a gyújtás-relé kapcsolja.

### Mikrofon

- Autós electret mikrofon a tetőkárpitra, a visszapillantó tükör mellé, vagy az A-oszlopra. Ne a hangszórók közelébe.
- A USB hangkártya mikrofon-bemenete adja a tápfeszültséget (bias).
- Ha volt gyári UHP, a tetőkonzolban lévő mikrofon talán újrahasznosítható ⚠️.

### Wi-Fi (vezeték nélküli AA)

- A Pi saját hozzáférési pontot csinál **5 GHz-en**: országkód HU, 36–48-as csatorna.
- A 2,4 GHz-et a Google kivezeti, és zavarja a Bluetooth-t.
- A telefon Bluetooth-on egyeztet, utána Wi-Fi-n csatlakozik.
- Tartalék: USB-kábeles AA, ami egyben tölt is.

---

## 7. A meglévő eszközeid szerepe

| Eszköz | Szerep | Megjegyzés |
|---|---|---|
| **Raspberry Pi 4** | a fejegység | passzív hűtőházzal. A műszerfal mögött nyáron 60–70 °C is lehet |
| **Samsung S20 FE** | az Android Autót futtató telefon | Android 13, vezeték nélküli AA-t tud. Az AA minimum 2026 novembertől Android 11, így még évekig rendben van. Tipp: kapcsold ki a Samsung Wi-Fi energiatakarékosságát, ha szakad a kapcsolat. Fejegységnek is használható lenne egy másik telefonnal, de akkor nem a telefonod, és ugyanaz a hívás-probléma jön elő, mint a 5. fejezetben |
| **Régi Kindle** | **autóba nem ajánlott** | Amazon specifikáció: 0–35 °C üzemi hőmérséklet, a parkoló autó ezt bőven túllépi, és a lítium akku megduzzadhat. Az e-ink lassú, hidegben nagyon lassú. A CAN adatoknak jobb helye a gyári kijelző vagy az AA dashboard. A műhelyben jó lesz a kapcsolási rajzok olvasására |

---

## 8. Vásárlás vagy építés?

| | **Kész kínai Astra H fejegység** | **DIY A: rádió marad** | **DIY B: Pi a rádió helyén** |
|---|---|---|---|
| Ár | használtan 40–62 e, új magyar boltban 67–85 e | 25–55 e | 40–75 e |
| Munka | beépítés: 1 délután | sok hétvége | még több |
| Android Auto | ZLink/TLink app, vezetékes/vezeték nélküli. A vezeték nélküli néha akadozik | LIVI, vezeték nélküli vagy USB | ugyanaz |
| Kihangosítás | beépített BT, a mikrofon minősége nem tesztelt | USB BT + saját mikrofon, **ezt kell a legtöbbet hangolni** | ugyanaz |
| Kormánygombok | a CAN-dobozzal | CAN démonnal | CAN démonnal |
| Gyári kijelző | óra/hőmérséklet marad. **Szöveget nem ír rá** | **minden marad + AA szöveg rajta** | minden marad + AA szöveg (rádió-emulációval) |
| Beállítások menü (GID/CID) | **elvész**, kivéve Connects2 CTSVX002.2 / ACV 42-VX-102 interfésszel (+23–35 e) | marad | emulációval ⚠️ |
| FM rádió | van | van (a gyári rádió) | nincs (streaming / RTL-SDR) |
| Ismert gondok | hamis specifikáció (2 GB helyett 1 GB RAM), a gyári kijelző hibaüzeneteket mutat vagy elsötétül, klíma ki-be kapcsolgat Raise dekóderrel, GID kódolás kellhet | a Google elzárhatja a DIY fejegységeket (lásd 9. fejezet) | ugyanaz |

**Ha kínait veszel:**
- Raise **G-RZ-OP55** (Astra H 06–14) vagy **G-RZ-OP64** (Astra 04–10) CAN-dobozzal szereltet keress.
- A RAM-ot alkalmazással ellenőrizd (pl. *Device Info HW*). Minimum 2 GB valós memória kell.
- TID-es autónál a legkisebb a veszteség.
- Magyar boltok: multimcardroid.hu, multimelodia.hu, brmultimedia.hu, topnavi.hu.

**Hordozható AA képernyő** (12–25 e, FM transzmitteren vagy AUX-on szól): olcsó, de semmi integráció. Nincs kormánygomb, nincs gyári kijelző, és gyenge a hangja.

**Javaslat:**
- Ha a cél a gyorsan működő AA, vegyél használt kínai fejegységet.
- Ha a cél a teljes integráció és maga a projekt (gyári kijelzőn az AA, minden gyári funkció megmarad), akkor **DIY: előbb az A változat, később a B**.

---

## 9. Kockázatok

1. **A Google elzárhatja a DIY fejegységeket.**
   - Minden nyílt forrású fejegység valódi hardverből kinyert tanúsítványt használ.
   - Ha ezeket visszavonják vagy protokollt váltanak, egyszerre állhat le minden ilyen projekt. Az OpenAuto Pro így halt meg az AA 12.6-tal.
2. **Hívásminőség.** A Bluetooth híváshang és a visszhangszűrés minden Linuxos megoldás legéretlenebb része. Ezért az asztali próba a hívással kezdődjön.
3. **CAN-adás.** Rossz üzenet zavart okozhat. Listen-only-val kezdj, csak MS-CAN-re adj, ritkítva.
4. **Akku lemerítése.** A nyugalmi áram < 1 mA legyen, és a leállítást teszteld.
5. **Hő és SD kártya.** Kell az overlay fájlrendszer és a hűtés. A nyári műszerfal mögött a Pi visszaveszi a teljesítményt.
6. **Kis csapatos projektek.** A LIVI és a Prodigy nagyrészt egyszemélyes. Az S20 FE már nem kap nagy Android-frissítést, az AA minimum verziója pedig nő.
7. **Műszaki vizsga és biztonság.** A képernyő ne legyen a légzsák útjában, ne takarja a szélvédőt, és legyen biztosan rögzítve. A rádiócsere nem bejegyzendő átalakítás. ⚠️

---

## 10. Következő lépések

1. **Felmérés:** milyen kijelző és rádió van, van-e AUX és gyári kihangosító. Fotó is jó.
2. **Asztali próba, az autó nélkül:**
   1. Pi4 + RPi OS Lite (Trixie) + LIVI + bármilyen HDMI kijelző.
   2. S20 FE vezeték nélküli AA-val.
   3. USB BT dongle + hangkártya + mikrofon, majd **próbahívás**.
   4. Ha a hívás nem jó, ezen a ponton derül ki, nem beépítés után.
3. **CAN felmérés:**
   1. CAN HAT + OBD kábel, listen-only módban, `candump -l can0`.
   2. Felvétel gyújtás rá, gombnyomások, motor jár, menet és tolatás közben.
   3. Az eredményt vesd össze a [docs/can-uzenetek.md](docs/can-uzenetek.md) táblázatával.
4. **CAN démon megírása:** kormánygomb → AA, szöveg → gyári kijelző, telemetria → dashboard. Ebben tudok segíteni, ha megvan a CAN log.
5. **Beépítés az A változattal**, utána, ha megérte, a B változat.

---

## Források

**Astra H CAN és kijelző**
- EHU32 – Bluetooth zene AUX-ra + szöveg TID/BID/GID/CID-re, Astra H/Corsa D/Vectra C/Zafira B: https://github.com/PNKP237/EHU32
- MPi3 – Raspberry Pi + MCP2515, Astra H kormánygombok, szöveg GID/CID-re: https://github.com/JJToB/MPi3
- Astra H CAN üzenet-adatbázis: https://github.com/JJToB/Car-CAN-Message-DB/tree/master/Opel/Astra/H
- Astra H CAN jelek: https://github.com/Koretion/Astra-H-Launcher/blob/main/docs/CAN_SIGNALS.md
- TID rádió nélkül: https://github.com/Flex2002/Opel_CAN_TID · Kijelző rádió nélkül + BT: https://github.com/iequa/CAN_OVC
- Kormánygomb-adapter, ACC/világítás/tolatás CAN-ből: https://github.com/ElKaPa/opel-can-swc-adapter
- Kormánygomb → Android médiagomb: https://github.com/cayirtepeomer/astra-h-canbus-shield
- Zafira B DBC (azonos platform): https://github.com/xymetox/OpelZafiraB_CanBus_dbc
- További Astra H CAN projektek: https://github.com/Gegerd/Astra-H · https://github.com/megadrifter/Opel-Astra-H
- Arduino példa, szövegküldés 0x6C1-re: https://gist.github.com/PL125/c842ea7083ebaf3f0d8736bcaa559906
- Gateway felépítés: https://www.vauxhallownersnetwork.co.uk/threads/canbus-information-for-project.434211/
- TID kezelési leírás: https://www.opelbook.ru/en/astra/H/main/manual/trehfunkcionalnyy-informacionnyy-displey-tid
- BC Astra H-n: https://tech2.guru/Vauxhall/technical/board-computer/
- Óra rádió nélkül: https://www.astra-h-forum.de/t/uhrzeit-ohne-original-radio-einstellen.8343/
- Rádiócsere, ACC hiánya: http://www.big-bubbles.fluff.org/blogs/bubbles/blog/2014/02/24/astra-head-unit-replacement/
- CID videointerfész: https://www.pepas.cz/projekty/opel-vcu-cz/

**Szoftver**
- LIVI: https://github.com/f-io/LIVI · hívás issue: https://github.com/f-io/LIVI/issues/385
- OpenAuto Prodigy: https://github.com/mrmees/openauto-prodigy
- Crankshaft: https://github.com/opencardev/crankshaft · aasdk: https://github.com/opencardev/aasdk
- OpenAuto Pro vége: https://github.com/mrmees/openauto-pro-community
- Open Headunit: https://github.com/andreknieriem/open-headunit
- Waveshare RS485 CAN HAT: https://www.waveshare.com/wiki/RS485_CAN_HAT
- Touch Display 2: https://www.raspberrypi.com/documentation/accessories/touch-display-2.html
- CarPiHAT: https://thepihut.com/products/carpihat-car-interface-hat-for-raspberry-pi
- Wired AA miért használ Bluetooth-t: https://www.slashgear.com/2264597/why-wired-android-auto-uses-phone-bluetooth/
- Pi4 BT hangútvonal: https://www.sefod.eu/posts/raspberry_bluetooth_audio_routing/

**Vásárlás**
- Raise G-RZ-OP55: https://manuals.plus/ae/1005009383135050 · G-RZ-OP64: https://manuals.plus/ae/1005006814934456
- Connects2 CTSVX002.2: https://connects2.com/Product/ProductItem/CTSVX002.2
- Klíma gond Raise dekóderrel: https://xdaforums.com/t/ac-problems-with-new-android-head-unit-in-opel-astra-h.4750349/
- Hamis specifikációjú fejegységek: https://www.team-bhp.com/news/android-head-unit-faking-its-hardware-specifications
- Példa Jófogás hirdetés: https://auto.jofogas.hu/budapest/Opel_Meriva_Zafira_Astra_Android_Radio_Multimedia_Navigacio_Fejegyseg_153487123.htm
