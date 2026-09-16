# IPTV Manager

Απλή native macOS εφαρμογή (SwiftUI) για διαχείριση Xtream Codes playlists: Live TV, Ταινίες (VOD) και Σειρές, με ενσωματωμένο player.

## Απαιτήσεις

Χρειάζεται το **πλήρες Xcode** (από το App Store), όχι μόνο τα Command Line Tools: το SwiftUI macro plugin (που χρειάζεται π.χ. το `@State`) δεν περιλαμβάνεται στο ξεχωριστό πακέτο Command Line Tools, μόνο μέσα στο Xcode.app.

Μετά την εγκατάσταση του Xcode από το App Store:

```bash
sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -license accept
```

## Εκτέλεση

Ο ενσωματωμένος video player (AVKit) χρειάζεται πραγματικό macOS app bundle για να δουλέψει — απλό `swift run` κάνει crash μόλις ανοίξεις κανάλι. Χρησιμοποίησε το script που πακετάρει την εφαρμογή:

```bash
cd /Users/kantarto/projects/IPTVManager
./Scripts/setup-signing.sh   # μία φορά, βλ. παρακάτω
./Scripts/build-app.sh
```

Αυτό χτίζει την εφαρμογή, τη «πακετάρει» σε `dist/kantarto IPTV.app`, και την ανοίγει. Ξανατρέξε `./Scripts/build-app.sh` μετά από κάθε αλλαγή στον κώδικα.

### Γιατί το `setup-signing.sh`

Χωρίς σταθερή υπογραφή (code signing identity), κάθε rebuild παράγει μια «διαφορετική» εφαρμογή στα μάτια του macOS — αυτό προκαλεί επιπλέον προειδοποιήσεις/προτροπές συστήματος (π.χ. Gatekeeper) σε κάθε επανεκκίνηση. Το `Scripts/setup-signing.sh` φτιάχνει μία φορά ένα τοπικό πιστοποιητικό υπογραφής (`kantarto IPTV Local Signing`) στο Keychain σου· το `build-app.sh` το χρησιμοποιεί αυτόματα αν υπάρχει.

Την πρώτη φορά θα σου ζητήσει να προσθέσεις μια playlist: όνομα, server URL (π.χ. `http://host:port`), username, password — αυτά τα στοιχεία σου τα δίνει ο πάροχος του IPTV.

## Δομή

- `Sources/IPTVManager/Models` — μοντέλα δεδομένων (profile, κατηγορίες, κανάλια)
- `Sources/IPTVManager/Networking` — client για το Xtream Codes `player_api.php`
- `Sources/IPTVManager/Storage` — αποθήκευση playlists, μαζί με τον κωδικό, σε UserDefaults (τοπικό αρχείο, όχι Keychain — βλ. Σημειώσεις)
- `Sources/IPTVManager/Views` — UI

## Εικονίδιο εφαρμογής

Υπάρχει ένα απλό, αυτόματα δημιουργημένο εικονίδιο στο `AppIcon/AppIcon.icns` (το `./Scripts/build-app.sh` το βάζει στο app bundle). Για να το αλλάξεις με δικό σου:

1. Βάλε τη δική σου εικόνα (τετράγωνη, τουλάχιστον 1024x1024) ως `AppIcon/icon_1024.png`
2. Ξανατρέξε τις εντολές παραγωγής `.icns` (δες `Scripts/generate-icon.swift` για το πώς φτιάχτηκε το τρέχον, ή απλά πες μου και το κάνω εγώ)

## Σημειώσεις

- Ο κωδικός κάθε playlist αποθηκεύεται τοπικά μαζί με τα υπόλοιπα στοιχεία (UserDefaults), **όχι** στο macOS Keychain. Το κάναμε επίτηδες: το Keychain ζητούσε επιβεβαίωση με τον κωδικό του Mac σε κάθε άνοιγμα της εφαρμογής, κάτι κουραστικό ειδικά όσο κάνουμε συχνά αλλαγές. Είναι λογικό trade-off για μια προσωπική εφαρμογή σε δικό σου μηχάνημα, αλλά σημαίνει ότι ο κωδικός της IPTV playlist είναι σε απλό κείμενο μέσα στο `~/Library/Preferences`. Αν αργότερα θες πίσω το Keychain, πες το.
- **Μετά από αυτή την αλλαγή θα χρειαστεί να ξαναμπείς στην "Επεξεργασία" της playlist σου και να βάλεις ξανά τον κωδικό μία τελευταία φορά** (το όνομα/server/username έμειναν όπως ήταν) — μετά δεν θα ξαναζητηθεί τίποτα.
- Το βίντεο παίζει με το native `AVKit`. Αν κάποιο stream δεν παίζει (ασυνήθιστο codec), ίσως χρειαστεί εναλλακτικός player (π.χ. VLC) — πες το αν συμβεί συχνά και το προσαρμόζουμε.
- Δοκιμάστηκε `swift build` με τα Command Line Tools και απέτυχε μόνο λόγω έλλειψης του SwiftUI macro plugin (βλ. Απαιτήσεις) — ο υπόλοιπος κώδικας δεν είχε λάθη μέχρι εκείνο το σημείο. Μόλις μπει το πλήρες Xcode, τρέξε `swift build` ξανά και πες μου αν βγει άλλο σφάλμα.
