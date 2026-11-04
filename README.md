# Numra Telefoni për iPhone

Projekt SwiftUI për iOS 16+, përfshirë iPhone 16. Kërkimi dhe importimi
përdorin SQLite-n lokale të pajisjes; nuk ka shërbim në internet ose API
për të dhënat. Importohet e njëjta `allphone_perditesuar.db` e përgatitur
për Android. Baza nuk përfshihet në projekt ose në ndërtimin cloud.

**Gjendja e dorëzimit:** është krijuar kodi, projekti Xcode dhe konfigurimi
për ndërtim në GitHub Actions. Nuk është ndërtuar ose nënshkruar ende një
IPA dhe nuk është provuar në iPhone. Windows-i i këtij sesioni nuk ka
Xcode/SDK iOS. Kontrollet lokale janë vetëm strukturore; testet Swift dhe
kompilimi ekzekutohen nga workflow në macOS.

## Ndërtimi nga Windows, pa pasur një Mac

1. Krijo një repository në llogarinë tënde GitHub.
2. Ngarko përmbajtjen e kësaj dosjeje në rrënjën e repository-t. Në rrënjë
   duhet të jenë `.github`, `NumraTelefoni`, `NumraTelefoni.xcodeproj` dhe
   `tests`. Mos ngarko DB-në, Excel-in, Apple ID ose fjalëkalime.
3. Në GitHub hap **Actions → Build iPhone IPA → Run workflow**.
4. Ndërtimi kryhet në runner-in macOS të GitHub. Kontrollo kufijtë e
   përdorimit të Actions në llogarinë tënde përpara nisjes.
5. Nëse mbaron me sukses, shkarko artifact-in
   **NumraTelefoni-iPhone-unsigned** dhe nxirr
   `NumraTelefoni-unsigned.ipa` nga ZIP-ja.

IPA-ja është PA NËNSHKRIM. Nuk instalohet duke e hapur nga Files.
Workflow nuk ka nevojë për certifikata ose fjalëkalime Apple.

## Instalimi personal nga Windows

Një rrugë është Sideloadly, mjet i palës së tretë që nënshkruan IPA-në me
llogarinë tënde Apple dhe e instalon në telefon. Shkarkoje vetëm nga
https://sideloadly.io dhe ndiq dokumentacionin e tij për kërkesat aktuale
të Windows/iTunes/iCloud. Hyrjen në llogari e kryen vetë në kompjuter;
mos e dërgo Apple ID-në ose fjalëkalimin në chat apo GitHub.

Lidh iPhone-in me USB, beso kompjuterin, zgjidh pajisjen dhe IPA-në në
Sideloadly dhe përfundo procesin e nënshkrimit/instalimit. Kur iOS e kërkon,
aktivizo **Settings → Privacy & Security → Developer Mode** dhe ndiq
hapat e konfirmimit të pajisjes. Nëse kërkohet besimi i profilit, ndiq
udhëzimin përkatës te **Settings → General → VPN & Device Management**.

Sipas FAQ-së zyrtare të Sideloadly, nënshkrimi me Apple ID falas zgjat 7
ditë dhe aplikacioni duhet rifreskuar. Rinënshkruaj mbi të njëjtin aplikacion,
me të njëjtën llogari/identifikues. Mos e çinstalo nëse dëshiron të ruash
bazën e importuar; pas çinstalimit duhet riimportim. Kjo mënyrë kërkon
internet për nënshkrim/rifreskim; kërkimi brenda aplikacionit punon offline.

Alternativa është një ndërtim dhe shpërndarje e nënshkruar përmes procesit
Apple Developer/TestFlight; ajo kërkon konfigurim shtesë të llogarisë dhe
certifikatave dhe nuk është përgatitur në këtë paketë.

## Transferimi dhe importimi i bazës

Pas instalimit mund të përdorësh **Apple Devices** në Windows për të shtuar
`allphone_perditesuar.db` në skedarët e aplikacionit. Projekti aktivizon
file sharing. Në iPhone, te Files / On My iPhone, zgjidh dosjen e Numra
Telefoni. Nga aplikacioni prek **Importo** dhe zgjidh DB-në.

Nëse skedari është në iCloud Drive, shkarkoje plotësisht në pajisje
përpara importimit në mënyrë që vetë importimi të mos presë internetin.
Mbaje aplikacionin hapur gjatë importimit të rreth 1.12 GB. Pas transferimit
të skedarit në telefon, lër të paktën rreth 1.2 GB të tjera të lira për kopjen
private; një përditësim mban edhe bazën e mëparshme derisa kopja e re të
kontrollohet. Në fund provo kërkim me emër dhe telefon me modalitetin avion.

## Ndërtimi me Mac, nëse është i disponueshëm më vonë

Hap `NumraTelefoni.xcodeproj`, zgjidh team-in tënd te Signing & Capabilities,
ndrysho bundle identifier-in nëse kërkohet dhe ekzekuto në iPhone-in tënd.
Projekti përdor Swift 5, SwiftUI dhe bibliotekën e sistemit `libsqlite3`,
pa varësi të tjera ose paketa nga interneti.

## Testet

Workflow përpara ndërtimit kompilion dhe ekzekuton `tests/main.swift` me
query builder-in dhe shtresën SQLite reale. Testet përdorin vetëm të dhëna
sintetike dhe mbulojnë 32 raste: emër/mbiemër, atësi, prefikse telefoni,
ë/ç, wildcard/literal `%` e `_`, input të gabuar dhe kufirin 501 për
shfaqjen e 500 rezultateve. Kontrollojnë edhe përdorimin e indekseve.

Në Mac testet mund të nisen veçmas:

```sh
mkdir -p build
swiftc NumraTelefoni/SearchQuery.swift NumraTelefoni/Database.swift tests/main.swift -lsqlite3 -o build/search-tests
./build/search-tests
```

Duhet provuar në pajisje: instalimi me nënshkrim, importimi real i DB-së,
rinisja, zëvendësimi i bazës, skedari i gabuar, hapësira e pamjaftueshme,
ndërprerja e procesit gjatë kopjimit dhe kërkimi offline. Importimi i
ndërprerë përsëritet; skedari i pjesshëm mbishkruhet herën tjetër.

Validimi i importimit kontrollon skemën, një lexim dhe indekset, pa skanuar
të gjithë integritetin e një DB-je 1 GB. Baza e përditësuar e dorëzuar veçmas
ka kaluar SQLite `quick_check` gjatë bashkimit.

## Ruajtja

Kopjimi bëhet me blloqe 1 MB, jo duke ngarkuar të gjithë DB-në në RAM.
Baza private është te Application Support dhe dosja përjashtohet nga backup.
Skedari burimor i transferuar në Documents/Files menaxhohet veçmas nga iOS;
mund ta heqësh atë pas importimit të suksesshëm duke ruajtur kopjen në PC.
Nuk ka thirrje rrjeti nga kodi i aplikacionit. Nuk kërkohet hyrje te Contacts.
Fushat shtesë të DB-së ruhen, por ekrani tregon vetëm emër, mbiemër, atësi,
telefon. Çinstalimi fshin të dhënat private të aplikacionit.

## Burimet për ndërtimin dhe instalimin

- [Kërkesat e Xcode](https://developer.apple.com/xcode/system-requirements)
- [Nënshkrimi për pajisje](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html)
- [GitHub: nisja manuale e workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [Sideloadly dhe kufiri 7 ditë](https://sideloadly.io/faq)
- [Apple: Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [Apple: skedarët nga Windows](https://support.apple.com/en-ie/120402)
