# QR Solidale – demo online

Tre parti:

- `index.html`: la pagina che si apre inquadrando il QR. Pubblica, nessun accesso richiesto.
- `pannello.html`: il pannello dell'operatore (beneficiari, registro, cartellini). Protetto da email e password.
- `supabase.sql`: il database. Il donatore può solo vedere nome e stato di un codice e fare una donazione simulata; tutto il resto richiede l'accesso da operatore. Il registro con la catena di impronte è scritto dal database.

Tempo stimato: 20–30 minuti.

## 1. Database su Supabase (gratuito)

1. Vai su supabase.com e crea un account (puoi entrare con GitHub).
2. **New project**. Nome: `qrsolidale`. Scegli una password del database e conservala. Regione: **Central EU (Frankfurt)**. Piano gratuito.
3. Quando il progetto è pronto: menu a sinistra **SQL Editor** > **New query**. Incolla tutto il contenuto di `supabase.sql` e premi **Run**. Deve comparire "Success".
4. Blocca le registrazioni libere: **Authentication** > **Sign In / Providers** (o **Settings**) > disattiva **Allow new users to sign up**. Così solo gli operatori che crei tu possono entrare.
5. Crea il tuo utente operatore: **Authentication** > **Users** > **Add user** > **Create new user**. Inserisci email e password e spunta **Auto Confirm User**.
6. Copia i dati di collegamento: **Project Settings** > **API** (o **Data API** e **API Keys**):
   - **Project URL** (tipo `https://abcd1234.supabase.co`);
   - la chiave **anon public** o **publishable**. Non usare mai la chiave `service_role` o `secret`.
7. Apri `config.js` con un editor di testo e sostituisci i due `INCOLLA-QUI` con questi valori. Se vuoi, cambia anche il nome dell'associazione.

## 2. Sito su GitHub Pages (gratuito)

1. Su GitHub: **New repository**. Nome: `qrsolidale`. Visibilità: **Public** (necessaria per GitHub Pages gratuito). Crea.
2. Nel repository vuoto: **uploading an existing file**. Trascina tutti i file della cartella (con il `config.js` già compilato) e premi **Commit changes**.
3. **Settings** > **Pages** > Source: **Deploy from a branch** > Branch: **main**, cartella **/ (root)** > **Save**.
4. Dopo uno o due minuti il sito è online su:
   - pagina donatore: `https://TUO-UTENTE.github.io/qrsolidale/`
   - pannello: `https://TUO-UTENTE.github.io/qrsolidale/pannello.html`

## 3. Prova

1. Apri il pannello ed entra con l'utente operatore.
2. C'è già un beneficiario di esempio attivo. Creane uno nuovo e premi **Attiva**.
3. Vai su **Cartellini**, stampa o mostra il cartellino a schermo e inquadralo con un telefono qualsiasi: si apre la pagina di donazione.
4. Dona un importo: in pochi secondi compare nel pannello e nel registro.
5. Sospendi il codice e inquadra di nuovo: la pagina dice "Codice non attivo".
6. In **Registro** premi **Verifica catena**.

## Note

- La chiave pubblica in `config.js` è fatta per stare in una pagina web: la sicurezza è data dalle regole del database.
- I pagamenti sono simulati. Chiunque abbia il link di un codice attivo può registrare donazioni finte: va bene per una demo, non per un uso reale.
- Il progetto gratuito di Supabase va in pausa dopo una settimana senza utilizzo: prima della demo aprilo dal pannello di Supabase e, se serve, premi **Restore**.
- Più avanti lo stesso sito si può collegare al dominio qrsolidale.it da **Settings** > **Pages** > **Custom domain**.
