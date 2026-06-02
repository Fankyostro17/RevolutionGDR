# Revolution GDR - Il Tavolo Virtuale

**Revolution GDR** è un'applicazione multipiattaforma (Android, iOS, Web) sviluppata in **Flutter** per la gestione di sessioni di gioco di ruolo (GDR). Offre un'esperienza immersiva per Master e Giocatori, combinando gestione campagne, chat in tempo reale, lancio dadi avanzato e controllo audio ambientale.

## Caratteristiche Principali

### Gestione Campagne
- **Creazione Avanzata**: I Master possono creare campagne definendo titolo, descrizione, range di livelli (es. 1-5), numero massimo giocatori e data della prossima sessione.
- **Stato Dinamico**: Le campagne possono essere attive, in pausa o concluse (`ENDED`).
- **Accesso Sicuro**: I giocatori possono unirsi alle campagne tramite un **codice univoco** generato automaticamente.
- **Persistenza Dati**: Backend in **Python (Flask)** con database **MySQL** per la gestione sicura di utenti e avventure.

### Sistema Dadi & Chat Integrata
- **Parser Intelligente**: Supporta espressioni complesse come `/rd 2d8+4-1d6`.
- **Multi-Dado**: Gestisce lanci multipli (es. `10d4`) con visualizzazione dettagliata di ogni singolo dado.
- **Roll Nascosti**: I Master possono effettuare lanci privati visibili solo a loro.
- **Chat Unificata**: Chat testuale e risultati dei dadi convivono nello stesso flusso, con timestamp e autori.

### Multiplayer in Tempo Reale
- **WebSocket Integration**: Utilizzo di `socket.io` per la sincronizzazione istantanea tra Master e Giocatori.
- **Host System**: Il Master avvia l'host; i giocatori vedono uno stato di "Attesa" con timeout automatico di 5 secondi se la connessione non viene stabilita.
- **Sincronizzazione Stato**: Cambiamenti di stato (Host on/off), nuovi messaggi e lanci dadi vengono propagati immediatamente a tutti i client connessi.

### Controllo Audio Ambientale
- **Musica di Sottofondo**: Playlist integrata per atmosfere immersive (Taverna, Foresta, Battaglia).
- **Effetti Sonori (SFX)**: Pulsanti rapidi per effetti come pioggia, fuoco o combattimento.
- **Controllo Master**: Solo il Master può avviare/fermare tracce e modificare il volume globale.

### Gestione File & Mappe
- **Upload Risorse**: I Master possono caricare mappe, documenti PDF e immagini di riferimento.
- **Sidebar Collassabile**: Interfaccia laterale organizzata in tab (Chat/Dadi, File, Audio) per massimizzare lo spazio della mappa.

---

## Tecnologie Utilizzate

### Frontend (Mobile/Web)
- **Framework**: Flutter (Dart)
- **State Management**: `setState` + `ValueNotifier` (pronto per migrazione a Provider/Bloc)
- **Networking**: `http` per REST API, `socket_io_client` per WebSocket
- **Audio**: `audioplayers`
- **Utility**: `file_picker`, `intl`, `shared_preferences`

### Backend (Server)
- **Linguaggio**: Python 3.10+
- **Framework Web**: Flask
- **Real-time**: Flask-SocketIO
- **Database**: MySQL (con `mysql-connector-python`)
- **Sicurezza**: JWT (PyJWT) per autenticazione, bcrypt per hashing password

---

## Struttura del Progetto

    revolution_gdr/
    ├── lib/
    │   ├── main.dart                  # Entry point dell'app
    │   ├── models/
    │   │   ├── adventure.dart         # Modello dati campagna
    │   │   └── user.dart              # Modello dati utente
    │   ├── screens/
    │   │   ├── portal_screen.dart     # Schermata iniziale
    │   │   ├── login_screen.dart      # Login utente
    │   │   ├── register_screen.dart   # Registrazione utente
    │   │   ├── main_dashboard_screen.dart # Dashboard principale (Master/Player)
    │   │   ├── create_campaign_screen.dart # Form creazione campagna
    │   │   ├── campaign_detail_screen.dart # Dettaglio e modifica campagna
    │   │   ├── join_campaign_screen.dart   # Unisciti con codice
    │   │   └── game_session_screen.dart    # Sessione di gioco live
    │   ├── services/
    │   │   ├── auth_service.dart      # Gestione auth e JWT
    │   │   ├── adventure_service.dart # Chiamate API REST
    │   │   └── game_socket_service.dart # Client WebSocket
    │   └── widgets/
    │       └── adventure_card.dart    # Card riassuntiva campagna
    ├── backend/
    │   ├── app.py                     # Server Flask + SocketIO
    │   ├── config.py                  # Configurazioni env
    │   ├── database.py                # Pool connessioni MySQL
    │   ├── models/                    # Modelli DB Python
    │   ├── routes/                    # Endpoint API (Auth, Adventures)
    │   └── utils/                     # Helper JWT
    └── pubspec.yaml                   # Dipendenze Flutter

## Installazione e Setup

### Prerequisiti
- Flutter SDK (3.x+)
- Python 3.10+
- MySQL Server (XAMPP o installazione nativa)

### 1. Configurazione Backend

1. Naviga nella cartella `backend/`:
```bash
   cd backend
```

2. Crea un ambiente virtuale e installa le dipendenze:
```bash
   python -m venv .venv
    source .venv/bin/activate  # Su Windows: .venv\Scripts\activate
    pip install -r requirements.txt
```

3. Configura il database:
- Avvia MySQL.
- Esegui lo script schema.sql per creare tabelle e utenti.
- Aggiorna config.py o .env con le tue credenziali DB.

4. Avvia il server:
```bash
    python app.py
```
Il server sarà attivo su http://0.0.0.0:8000.

### 2. Configurazione Frontend (Flutter)

1. Nella root del progetto, installa le dipendenze:
```bash
    flutter pub get
```

2. Configura l'URL del backend in lib/services/auth_service.dart e lib/services/game_socket_service.dart:
- Emulatore Android: http://10.0.2.2:8000
- iOS Simulator/Web: http://localhost:8000
- Dispositivo fisico: http://<TUO_IP_PC>:8000

3. Avvia l'app:
```bash
    flutter run
```

### Note di Sviluppo
- **Hot Reload**: Durante lo sviluppo Flutter, usa r per hot reload e R per hot restart dopo modifiche strutturali.
- **Debug WebSocket**: Controlla la console del terminale Python per vedere i log di connessione/disconnessione dei client.
- **Database**: Assicurati che il servizio MySQL sia sempre attivo prima di avviare il backend Python.

### Contributi
Le contribuzioni sono benvenute! Per proporre migliorie:
1. Forka il repository
2. Crea un branch per la tua feature (git checkout -b feature/NuovaFunzione)
3. Commita le modifiche (git commit -m 'Aggiunta NuovaFunzione')
4. Pusha il branch (git push origin feature/NuovaFunzione)
5. Apri una Pull Request

### Licenza
Questo progetto è sviluppato a scopo educativo e personale. Vedi il file ```LICENSE``` per maggiori dettagli.

### Autore
Sviluppato da Thomas Fanciullacci come progetto tecnico per l'Esame di Stato ITIS Carlo Zuccante.
- Email: [thomas.fanciullacci@gmail.com]
- GitHub: [@Fankyostro17]