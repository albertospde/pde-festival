# PDE Festival

Sezione del PDE Hub per le richieste di Messaggerie su festival e fiere.
Un solo `index.html` (come BookUp e Ricerca Copertine), pubblicato su GitHub Pages
come `albertospde.github.io/pde-festival/` e aperto dal Hub in una scheda interna.

## Processo
1. **Ricevi** — si trascina la mail di Messaggerie (.msg / .eml, anche con allegati Excel/CSV):
   l'app estrae evento, luogo, date, scadenza ordine, consegna, cliente e titoli (EAN + copie).
   Si controllano i dati e si crea la pratica (numero `FF-AAAA-NNN`).
2. **Ordina** — l'ordine parte su Messaggerie con lo stesso motore di BookUp → Ordini di rifornimento
   (`rpn-sync`: instradamento automatico per editore sulle utenze PDE / PDE Service, `rifornimento-order`,
   numero ordine interno da `rifornimento-order-id`). Gli ordini finiscono anche nello storico di BookUp
   (`rifornimento_ordini_inviati`, origine `festival`).
3. **Comunica** — l'app compone la mail di risposta a Messaggerie con i numeri d'ordine
   (bozza .eml che Outlook apre pronta da inviare) e la pratica viene segnata come comunicata.
4. **Recupera** — "Verifica evasione" legge evaso/inevaso dal portale ordini Messaggerie
   (`verifica-ordini-righe` / `verifica-ordini-dettaglio`); per gli inevasi si segna lo stato della
   ristampa e si invia l'ordine di recupero sulle quantità aperte, poi si aggiorna Messaggerie.

Requisiti per chi usa l'app: accesso RPN amministratore (per inviare ordini) e account Messaggerie
Libri collegato (per titoli ed evasione), entrambi da BookUp → Accessi.

## Database (Supabase "presenze")
`supabase/migrations/20261007_festival_fiere.sql`: tabelle `ff_pratiche`, `ff_righe`, `ff_ordini`,
`ff_eventi`, `ff_contatori`. Applicata il 2026-10-07.

## Logo
`py scripts/crea_logo.py` rigenera i file in `logo/` (stesso pavone e caratteri di Giro Manager).
