require('dotenv').config();
const { initializeApp } = require("firebase/app");
const { getFirestore, collection, query, orderBy, onSnapshot } = require("firebase/firestore");
const { getAuth, signInAnonymously } = require("firebase/auth");
const fs = require('fs');
const path = require('path');

// Configuration from .env
const firebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY,
  authDomain: process.env.FIREBASE_AUTH_DOMAIN,
  projectId: process.env.FIREBASE_PROJECT_ID,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.FIREBASE_APP_ID
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth(app);

const LOG_FILE = path.join(__dirname, 'firestore_logs.txt');

// Ensure log file exists
if (!fs.existsSync(LOG_FILE)) {
    fs.writeFileSync(LOG_FILE, '');
}

console.log("🔥 Connecting to Firestore...");

signInAnonymously(auth)
  .then(() => {
    console.log("✅ Signed in anonymously");
    startListening();
  })
  .catch((error) => {
    console.error("❌ Error signing in:", error);
  });

function startListening() {
    console.log(`Start listening for logs... (Saving to ${LOG_FILE})`);
    
    // Listen to 'items' collection, ordered by timestamp descending
    // We limit to recent items to avoid dumping the whole history on startup, 
    // but for "tailing" we might want to see new ones coming in.
    // Let's just listen to all and filter or just show new ones. 
    // Actually, onSnapshot sends the initial state. We can suppress that if we want, 
    // but seeing the current state is often useful.
    
    const q = query(collection(db, "logs"), orderBy("timestamp", "asc"));
    
    let isInitialLoad = true;

    const unsubscribe = onSnapshot(q, (snapshot) => {
        if (isInitialLoad) {
            isInitialLoad = false;
            // console.log(`Loaded ${snapshot.size} existing logs.`);
            return;
        }

        snapshot.docChanges().forEach((change) => {
            if (change.type === "added") {
                const data = change.doc.data();
                // Convert Firestore Timestamp to Date if needed, or it might be a string/number depending on how it was saved.
                // In Swift we saved `Date()`, which usually maps to a Timestamp in Firestore.
                
                let timestampStr = "Unknown Time";
                if (data.timestamp && data.timestamp.seconds) {
                    timestampStr = new Date(data.timestamp.seconds * 1000).toLocaleTimeString();
                } else if (data.timestamp) {
                     timestampStr = new Date(data.timestamp).toLocaleTimeString();
                }

                const logMessage = `[${timestampStr}] ${data.title}`;
                
                // Print to Console
                console.log(logMessage);
                
                // Append to File
                fs.appendFileSync(LOG_FILE, logMessage + '\n');
            }
        });
    }, (error) => {
        console.error("❌ Listener error:", error);
    });
}
