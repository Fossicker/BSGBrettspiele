// ═══════════════════════════════════════════════
//  🔥 FIREBASE CONFIG — NUR HIER EINTRAGEN!
//  Diese Datei wird von allen Seiten geladen.
// ═══════════════════════════════════════════════

const firebaseConfig = {
  apiKey: "AIzaSyAznDKo2ERi4bmqrkjXodD7Ro2CLEoxAT0",
  authDomain: "bsgbrettspiele-b1de9.firebaseapp.com",
  databaseURL: "https://bsgbrettspiele-b1de9-default-rtdb.europe-west1.firebasedatabase.app",
  projectId: "bsgbrettspiele-b1de9",
  storageBucket: "bsgbrettspiele-b1de9.firebasestorage.app",
  messagingSenderId: "1050013527008",
  appId: "1:1050013527008:web:9ce6498e526a47b4f55985",
  measurementId: "G-G2CBNYB07Q"
};

// ═══════════════════════════════════════════════
//  Nicht ändern ab hier:
// ═══════════════════════════════════════════════
firebase.initializeApp(firebaseConfig);
const db = firebase.database();
 
// ═══════════════════════════════════════════════
//  👥 NAMEN — werden aus Firebase geladen
//  Pfad: /teilnehmer (Array von Namen)
// ═══════════════════════════════════════════════
let DEFAULT_NAMES = [];
let _namesLoaded = false;
const _namesCallbacks = [];
 
// Namen aus Firebase laden
db.ref('teilnehmer').on('value', snap => {
  const data = snap.val();
  DEFAULT_NAMES = data ? Object.values(data) : [];
  _namesLoaded = true;
  // Alle wartenden Callbacks aufrufen
  while (_namesCallbacks.length) _namesCallbacks.shift()();
});
 
// Helper: Warten bis Namen geladen sind
function onNamesReady(callback) {
  if (_namesLoaded) callback();
  else _namesCallbacks.push(callback);
}