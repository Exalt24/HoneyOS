// Checks the Firestore security rules by sending real REST requests, with no mocks.
// It signs up two throwaway users, tries things each of them should and should not
// be able to do, and deletes everything it created.
//
// Against the local emulators (start them first, see the README):
//   node firebase/rules_check.mjs --emulator
// Against a hosted project (uses the web API key from config/firebase.json):
//   node firebase/rules_check.mjs --config config/firebase.json
//
// Emulator ports default to 9099 (Auth) and 8080 (Firestore); override with
// AUTH_EMULATOR_HOST and FIRESTORE_EMULATOR_HOST (host:port).
import { readFileSync } from 'node:fs';

const args = process.argv.slice(2);
const useEmulator = args.includes('--emulator');
const configPath = args.includes('--config') ? args[args.indexOf('--config') + 1] : 'config/firebase.json';

let authBase, fsBase, apiKey, projectId;
if (useEmulator) {
  const auth = process.env.AUTH_EMULATOR_HOST || '127.0.0.1:9099';
  const fs = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  projectId = 'demo-honeyos';
  apiKey = 'demo-api-key';
  authBase = `http://${auth}/identitytoolkit.googleapis.com/v1`;
  fsBase = `http://${fs}/v1/projects/${projectId}/databases/(default)/documents`;
} else {
  const cfg = JSON.parse(readFileSync(configPath, 'utf8'));
  projectId = cfg.FIREBASE_PROJECT_ID;
  apiKey = cfg.FIREBASE_API_KEY;
  authBase = 'https://identitytoolkit.googleapis.com/v1';
  fsBase = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
}

// A key restricted to your site's referrer needs one on these server-side calls: REFERER=http://localhost:8000/ node firebase/rules_check.mjs ...
const extra = process.env.REFERER ? { Referer: process.env.REFERER } : {};
const run = Date.now().toString(36);
let passed = 0;
let failed = 0;

function str(v) { return { stringValue: v }; }
function fields(obj) { return { fields: Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, str(v)])) }; }

async function signUp(name) {
  const res = await fetch(`${authBase}/accounts:signUp?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...extra },
    body: JSON.stringify({ email: `rulescheck-${name}-${run}@honeyos.invalid`, password: 'check123', returnSecureToken: true }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`signUp failed: ${JSON.stringify(body).slice(0, 200)}`);
  return { uid: body.localId, token: body.idToken };
}

async function call(token, method, path, body) {
  const res = await fetch(`${fsBase}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...extra, ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try { json = await res.json(); } catch { /* empty body */ }
  return { status: res.status, json };
}

async function query(token, where) {
  const filters = where.map(([field, value]) => ({
    fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: str(value) },
  }));
  const structuredQuery = {
    from: [{ collectionId: 'FileSystem' }],
    where: filters.length === 1 ? filters[0] : { compositeFilter: { op: 'AND', filters } },
  };
  const url = fsBase.replace(/\/documents$/, '/documents:runQuery');
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...extra, ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ structuredQuery }),
  });
  const json = await res.json();
  const denied = Array.isArray(json) ? json.some((r) => r.error) : !!json.error;
  const docs = Array.isArray(json) ? json.filter((r) => r.document) : [];
  return { status: res.status, denied: denied || res.status === 403, docs };
}

function check(label, ok) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}`);
  ok ? passed++ : failed++;
}

const created = [];
const a = await signUp('a');
const b = await signUp('b');

try {
  // users: public read, owner-only create
  check('anyone can read the users list (the picker needs it)', (await call(null, 'GET', '/users')).status === 200);
  const profile = fields({ name: 'checker', profile_picture: 'aGk=' });
  check('a signed-in user can create their own profile', (await call(a.token, 'PATCH', `/users/${a.uid}`, profile)).status === 200);
  check('a user cannot create a profile for someone else', (await call(a.token, 'PATCH', `/users/${b.uid}`, profile)).status === 403);
  check('nobody signed out can create a profile', (await call(null, 'PATCH', `/users/${'x' + run}`, profile)).status === 403);
  check('a profile cannot carry a password field', (await call(b.token, 'PATCH', `/users/${b.uid}`, fields({ name: 'x', profile_picture: 'aGk=', password: 'nope' }))).status === 403);
  check('a profile cannot be edited afterwards', (await call(a.token, 'PATCH', `/users/${a.uid}`, fields({ name: 'renamed', profile_picture: 'aGk=' }))).status === 403);
  check('a user cannot delete someone else\'s profile', (await call(b.token, 'DELETE', `/users/${a.uid}`)).status === 403);

  // FileSystem: private to the signed-in owner
  const folder = fields({ name: `check-${run}`, path: '/FileSystem/C', type: 'folder', userId: a.uid });
  const made = await call(a.token, 'POST', '/FileSystem', folder);
  check('an owner can create a folder', made.status === 200);
  const folderId = made.json?.name?.split('/').pop();
  if (folderId) created.push([a.token, folderId]);

  check('someone else cannot create a folder in my name', (await call(b.token, 'POST', '/FileSystem', folder)).status === 403);
  check('a signed-out visitor cannot create anything', (await call(null, 'POST', '/FileSystem', folder)).status === 403);
  check('an item cannot carry extra fields', (await call(a.token, 'POST', '/FileSystem', fields({ name: 'x', path: '/FileSystem/C', type: 'folder', userId: a.uid, admin: 'yes' }))).status === 403);
  check('a client cannot create a second disk', (await call(a.token, 'POST', '/FileSystem', fields({ name: 'D', path: '/FileSystem', type: 'disk' }))).status === 403);

  const mine = await query(a.token, [['userId', a.uid]]);
  check('an owner can list their own items', !mine.denied && mine.docs.length >= 1);
  const theirs = await query(b.token, [['userId', a.uid]]);
  check('another user cannot list my items', theirs.denied);
  const everyone = await query(b.token, [['path', '/FileSystem/C']]);
  check('an unscoped listing is refused', everyone.denied);
  const signedOut = await query(null, [['type', 'disk']]);
  check('a signed-out visitor cannot even list the disk', signedOut.denied);
  const disks = await query(b.token, [['type', 'disk']]);
  check('a signed-in user can list the disk', !disks.denied);

  if (folderId) {
    check('another user cannot read my folder directly', (await call(b.token, 'GET', `/FileSystem/${folderId}`)).status === 403);
    check('another user cannot rename my folder', (await call(b.token, 'PATCH', `/FileSystem/${folderId}?updateMask.fieldPaths=name`, fields({ name: 'stolen' }))).status === 403);
    check('another user cannot delete my folder', (await call(b.token, 'DELETE', `/FileSystem/${folderId}`)).status === 403);
    check('an owner can rename their folder', (await call(a.token, 'PATCH', `/FileSystem/${folderId}?updateMask.fieldPaths=name`, fields({ name: `renamed-${run}` }))).status === 200);
    check('an owner cannot hand a folder to someone else', (await call(a.token, 'PATCH', `/FileSystem/${folderId}?updateMask.fieldPaths=userId`, fields({ userId: b.uid }))).status === 403);
  }
  check('everything outside users and FileSystem is closed', (await call(a.token, 'GET', '/secrets')).status === 403);
} finally {
  for (const [token, id] of created) await call(token, 'DELETE', `/FileSystem/${id}`);
  const removed = await call(a.token, 'DELETE', `/users/${a.uid}`);
  check('a user can delete their own profile', removed.status === 200);
  for (const u of [a, b]) {
    await fetch(`${authBase}/accounts:delete?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...extra },
      body: JSON.stringify({ idToken: u.token }),
    });
  }
}

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
