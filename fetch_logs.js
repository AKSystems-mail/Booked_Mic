// fetch_logs.js
/**
 * Quick script to export recent `client_logs` from Firestore.
 *
 * Prerequisites:
 *   • Node ≥ 12
 *   • npm package `firebase-admin` (install with `npm i firebase-admin`)
 *   • The environment already has a credential (ADC) **or** a service‑account JSON file
 *        referenced by GOOGLE_APPLICATION_CREDENTIALS.
 *   • Project ID is explicitly set below (bookedmic-1cf9d).
 *
 * Usage:
 *   node fetch_logs.js > client_logs.json
 *
 * Adjust the default `minutes` and `limit` by editing the call to `fetch()`
 * at the bottom of the file.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'bookedmic-1cf9d', // explicitly set project ID for ADC environments
  });
}
const db = admin.firestore();

async function fetch({ minutes = 60, limit = 200 } = {}) {
  const cutoff = new Date(Date.now() - minutes * 60 * 1000);
  const snap = await db
    .collection('client_logs')
    .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(cutoff))
    .orderBy('timestamp', 'desc')
    .limit(limit)
    .get();

  const out = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  console.log(JSON.stringify(out, null, 2));
}

fetch().catch((e) => {
  console.error('❌ fetch_logs error:', e);
  process.exit(1);
});
