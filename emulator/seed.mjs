// Seeds a fresh local Firebase emulator with the two things HoneyOS expects to
// find already in its backend:
//   1. a "disk" document in the FileSystem collection (the app lists these as
//      "Local Disk C" under View Files; with none, This PC is empty), and
//   2. DEPOLTIMEJ.jpg in Storage, the default profile picture the register
//      screen downloads when no photo is chosen.
//
// Usage (emulators already running):  node emulator/seed.mjs
// Override where the emulators listen with FIRESTORE_EMULATOR_HOST and
// STORAGE_EMULATOR_HOST (host:port), the same variables the Firebase tools use.
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const PROJECT = 'honeyos';
const BUCKET = 'honeyos.appspot.com';
const firestore = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const storage = process.env.STORAGE_EMULATOR_HOST || '127.0.0.1:9199';
const docs = `http://${firestore}/v1/projects/${PROJECT}/databases/(default)/documents/FileSystem`;

async function seedDisk() {
  const existing = await (await fetch(docs)).json();
  const hasDisk = (existing.documents || []).some((d) => d.fields?.type?.stringValue === 'disk');
  if (hasDisk) {
    console.log('FileSystem already has a disk, leaving it alone');
    return;
  }
  const res = await fetch(docs, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        name: { stringValue: 'C' },
        path: { stringValue: '/FileSystem' },
        type: { stringValue: 'disk' },
      },
    }),
  });
  if (!res.ok) throw new Error(`Firestore seed failed: ${res.status} ${await res.text()}`);
  console.log('Created disk C in FileSystem');
}

async function seedDefaultAvatar() {
  const png = await readFile(fileURLToPath(new URL('../assets/userSample.png', import.meta.url)));
  const res = await fetch(`http://${storage}/v0/b/${BUCKET}/o?name=DEPOLTIMEJ.jpg`, {
    method: 'POST',
    headers: { 'Content-Type': 'image/png' },
    body: png,
  });
  if (!res.ok) throw new Error(`Storage seed failed: ${res.status} ${await res.text()}`);
  console.log('Uploaded DEPOLTIMEJ.jpg (default profile picture)');
}

await seedDisk();
await seedDefaultAvatar();
