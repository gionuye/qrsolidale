// QR Solidale – funzioni comuni a pagina donatore e pannello
(function(){
  const cfg = window.QRS_CONFIG || {};
  const configured = cfg.SUPABASE_URL && !/INCOLLA/.test(cfg.SUPABASE_URL) && cfg.SUPABASE_KEY && !/INCOLLA/.test(cfg.SUPABASE_KEY);
  const client = (configured && window.supabase) ? window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_KEY) : null;

  const QRS = {
    cfg, client, configured,
    ASSOC: cfg.ASSOCIAZIONE || "Associazione",
    ALPH: "0123456789ABCDEFGHJKMNPQRSTVWXYZ",
    AMOUNTS: [{v:2,d:"un pasto caldo"},{v:5,d:"una settimana di autobus"},{v:10,d:"un aiuto per la spesa"}],
    STATE_LABEL: {da_attivare:"Da attivare",attivo:"Attivo",sospeso:"Sospeso",sostituito:"Sostituito",chiuso:"Chiuso"},
    fmtCode: c => c ? c.slice(0,4)+"-"+c.slice(4) : "",
    normCode: s => (s||"").toUpperCase().replace(/[^0-9A-Z]/g,"").replace(/O/g,"0").replace(/[IL]/g,"1"),
    eur: n => new Intl.NumberFormat("it-IT",{style:"currency",currency:"EUR"}).format(+n||0),
    esc: s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])),
    seal: (cls) => `<svg class="${cls||"seal"}" viewBox="0 0 40 40" aria-hidden="true"><circle cx="20" cy="20" r="18" fill="var(--accent)"/><path d="M20 29s-8-4.8-8-10.2A4.6 4.6 0 0 1 20 16a4.6 4.6 0 0 1 8 2.8C28 24.2 20 29 20 29z" fill="var(--accent-fg)"/></svg>`,
    toast(msg){
      let t = document.getElementById("toast");
      if(!t){ t = document.createElement("div"); t.id="toast"; t.className="toast"; t.setAttribute("role","status"); document.body.appendChild(t); }
      t.textContent = msg; t.hidden = false; clearTimeout(QRS._t); QRS._t = setTimeout(()=>t.hidden=true, 2800);
    },
    // Messaggio leggibile da un errore del database
    errMsg(e, fallback){
      const m = (e && (e.message || e.error_description)) || "";
      if(/non attivo/i.test(m)) return "Questo codice non accetta donazioni.";
      if(/non trovato/i.test(m)) return "Codice non trovato.";
      if(/Importo/i.test(m)) return "L'importo deve essere tra 1 e 500 €.";
      if(/riservato|permission|JWT/i.test(m)) return "Accesso scaduto: entra di nuovo.";
      if(/Invalid login/i.test(m)) return "Email o password non corretti.";
      return fallback || "Operazione non riuscita: riprova.";
    },
    async sha256(str){
      const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
      return [...new Uint8Array(buf)].map(b=>b.toString(16).padStart(2,"0")).join("");
    },
    donorUrl(code){ return new URL("./?c="+code, location.href).href; }
  };
  window.QRS = QRS;
})();
