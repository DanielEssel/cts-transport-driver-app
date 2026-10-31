#!/usr/bin/env node
// Synthetic data for testing Gas supplier jobs in the driver app's emulator
// flavor. Writes only to the local emulators of project demo-ctsgo-driver.
//
// Orders are made the way production makes them: this runs the passenger
// repo's own callables in-process (quote -> create -> hold -> pay -> supplier
// response -> rider offer / driver steps), as functions/test does, against
// the running Firestore and Auth emulators. The Google Routes call in the
// quote is stubbed; payments are in stub mode and never leave this machine.
//
//   node seed_supplier_jobs.js world             base data + the test driver's login
//   node seed_supplier_jobs.js reset             wipe Firestore, then `world`
//   node seed_supplier_jobs.js open              an open CTSGo job near the driver
//   node seed_supplier_jobs.js offer             a linked-rider offer to the driver
//   node seed_supplier_jobs.js assigned          the driver's job, going to the station
//   node seed_supplier_jobs.js at-station        ... arrived at the station
//   node seed_supplier_jobs.js out-for-delivery  ... handed over (prints the customer's code)
//   node seed_supplier_jobs.js delivered         ... delivered (an earning to list)
//   node seed_supplier_jobs.js handover          the supplier hands over the driver's
//                                                atStation job (the portal's step)
//   node seed_supplier_jobs.js status            orders, statuses and codes
//   node seed_supplier_jobs.js sms-code          the login code the Auth emulator "sent"
//
// Option: --at LAT,LNG places the stations there; by default they go next to
// the driver's last location in the emulator (written when the app goes
// online), so the 10 km dispatch radius holds wherever the phone is.

"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { createRequire } = require("node:module");

const PROJECT_ID = "demo-ctsgo-driver";
const HOST = "127.0.0.1";
const PORTS = { firestore: 8080, auth: 9099, functions: 5001, hub: 4400 };

const DRIVER = "emu-driver";
const DRIVER_PHONE = "+233200000001"; // typed as 0200000001 in the app
const PAX = "emu-passenger";
const SUP_USER = "emu-supplier-user";
const SUPER = "emu-super-admin";
const DISPATCH = "emu-sup-dispatch"; // CTSGo drivers deliver (open jobs)
const RIDERS = "emu-sup-riders"; // linked riders first (offers)
const ST = "emu-st";
const PID = "exchangeEmpty_kg12_5_goGas";
const DEFAULT_AT = { latitude: 5.6037, longitude: -0.187 }; // Accra

function fail(msg) {
  console.error(`seed: ${msg}`);
  process.exit(1);
}

// ── Environment: the local emulators only, set before any module loads ──────

for (const k of ["GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_CLOUD_PROJECT", "FIREBASE_TOKEN", "FIREBASE_CONFIG"]) delete process.env[k];
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = `${HOST}:${PORTS.firestore}`;
process.env.FIREBASE_AUTH_EMULATOR_HOST = `${HOST}:${PORTS.auth}`;
process.env.FUNCTIONS_EMULATOR = "true";
process.env.PAYMENTS_MODE = "stub";
process.env.BRIDGE_API_BASE = `http://${HOST}:8099`;
process.env.BRIDGE_CALLBACK_BASE_URL = `http://${HOST}:${PORTS.functions}/${PROJECT_ID}/europe-west2`;
process.env.BRIDGE_CLIENT_KEY = "emulator-fake-client-key";
process.env.BRIDGE_SECRET_KEY = "emulator-fake-secret-key";
process.env.BRIDGE_SERVICE_ID = "1";
process.env.ROUTES_API_KEY = "emulator-fake-routes-key";

const FUNCTIONS = fs.realpathSync(path.join(__dirname, "backend", "functions"));
const fnRequire = createRequire(path.join(FUNCTIONS, "index.js"));

/** The hub must list Firestore and Auth (all this writes to) on their ports. */
async function requireEmulators() {
  let list;
  try {
    const res = await fetch(`http://${HOST}:${PORTS.hub}/emulators`, { signal: AbortSignal.timeout(3000) });
    list = await res.json();
  } catch (e) {
    fail(`the emulators are not running on ${HOST}:${PORTS.hub} (${e.message}). Start them with ./start_emulators.sh.`);
  }
  for (const name of ["firestore", "auth"]) {
    const info = list[name];
    if (!info || info.port !== PORTS[name] || info.host !== HOST) {
      fail(`the ${name} emulator is not on ${HOST}:${PORTS[name]} (${JSON.stringify(info)}).`);
    }
  }
}

let admin, db, fft, g, f, escrow, dq, GeoPoint, Timestamp;

function load() {
  admin = fnRequire("firebase-admin");
  if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT_ID });
  if (admin.app().options.projectId !== PROJECT_ID) fail("firebase-admin is not on the demo project.");
  db = admin.firestore();
  ({ GeoPoint, Timestamp } = admin.firestore);
  fft = fnRequire("firebase-functions-test")({ projectId: PROJECT_ID });
  g = fnRequire("./gas_supplier_orders");
  f = fnRequire("./gas_supplier_fulfilment");
  escrow = fnRequire("./escrow");
  dq = fnRequire("./delivery_quotes");
  dq._setRouteProviderForTests(async () => ({ distanceMeters: 4300, durationSeconds: 600 }));
}

/** One callable, as the given user (what the app or portal would send). */
async function call(fn, data, uid) {
  try {
    return await fft.wrap(fn)({ data, auth: { uid, token: {} } });
  } catch (e) {
    const reason = e.details?.reason ? ` [${e.details.reason}]` : "";
    throw new Error(`${e.code || "error"}: ${e.message}${reason}`);
  }
}

// ── Base data ───────────────────────────────────────────────────────────────

const offset = (p, dLat, dLng) => ({ latitude: p.latitude + dLat, longitude: p.longitude + dLng });

async function placeStations(at) {
  const station = offset(at, 0.009, 0); // about 1 km from the driver
  for (const id of [DISPATCH, RIDERS]) {
    await db.doc(`gas_suppliers/${id}/stations/${ST}`).set({ location: new GeoPoint(station.latitude, station.longitude) }, { merge: true });
  }
  return { station, customer: offset(at, 0, 0.018) }; // customer about 2 km away
}

async function world({ keepDriver = null } = {}) {
  await db.doc(f.FLAG_DOC).set({ enabled: true, riderAcceptMinutes: 10, supplierResponseMinutes: 60 });
  await db.doc("settings/platform").set({ platformFeePercent: 15, gas: { baseFare: 8, perKm: 2, minDeliveryFee: 12, roundTripFee: 30 } });
  const suppliers = [[DISPATCH, "EMU Dispatch Gas", "ctsgo_dispatch"], [RIDERS, "EMU Riders Gas", "supplier_riders_ctsgo_fallback"]];
  for (const [id, legalName, riderArrangement] of suppliers) {
    await db.doc(`gas_suppliers/${id}`).set({ legalName, tradingName: legalName, status: "approved", ordersEnabled: true,
      fulfillment: { exchangeEmpty: true, pickupAndReturn: true }, riderArrangement });
    await db.doc(`gas_suppliers/${id}/stations/${ST}`).set({ name: `${legalName} station`, supplierId: id, status: "verified",
      address: "EMU Station Road", location: new GeoPoint(DEFAULT_AT.latitude, DEFAULT_AT.longitude), serviceRadiusKm: 10,
      supportedSizes: ["kg12_5"], fulfillment: { exchangeEmpty: true, pickupAndReturn: true } });
    await db.doc(`gas_suppliers/${id}/stations/${ST}/products/${PID}`).set({ orderType: "exchangeEmpty", cylinderSize: "kg12_5",
      brand: "goGas", price: 150, handlingFee: 0, currency: "GHS", priceVersion: 1, availability: "available", verified: true });
  }
  // A member belongs to one supplier: one portal user per supplier.
  for (const [uid, supplierId] of [[SUP_USER, RIDERS], [`${SUP_USER}-dispatch`, DISPATCH]]) {
    await db.doc(`gas_supplier_members/${uid}`).set({ uid, supplierId, role: "owner", status: "active", version: 1,
      createdBy: SUPER, updatedBy: SUPER, createdAt: new Date(), updatedAt: new Date() });
  }
  await db.doc(`admins/${SUPER}`).set({ active: true, role: "super_admin" });
  const terms = { termsId: "v1", version: 1, rateBps: 1000, termsReference: "EMULATOR FIXTURE (not commercial)",
    settlementHoldHours: 0, currency: "GHS", commissionBase: "product_subtotal", handlingFeeCommissionable: false,
    deliveryFeeCommissionable: false, proposedBy: SUPER, approvedBy: "emu-approver" };
  await db.doc("gas_commission_terms/v1").set({ ...terms, status: "approved" });
  await db.doc("gas_commission_terms/current").set({ ...terms, active: true });
  await db.doc(`wallets/${PAX}`).set({ userId: PAX, balance: 5000, heldBalance: 0 });
  await db.doc(`gas_supplier_riders/${DRIVER}`).set({ driverId: DRIVER, supplierId: RIDERS, status: "active", version: 1,
    linkedBy: SUPER, linkedAt: new Date() });
  const now = new Date();
  await db.doc(`drivers/${DRIVER}`).set({
    role: "driver_delivery", serviceType: "delivery", vehicleType: "motorcycle", vehiclePlate: "EMU-0001", vehicleModel: "Emulator bike",
    displayName: "EMU Test Driver", phone: DRIVER_PHONE, signupStep: "approved",
    accountSetupComplete: true, vehicleSetupComplete: true, documentsUploaded: true, isApproved: true, isVerified: true,
    isOnline: false, isAvailable: false, currentTripId: null, rating: 4.8, totalTrips: 0, acceptanceRate: 1, cancellationRate: 0,
    memberSince: now, createdAt: now, updatedAt: now,
    ...(keepDriver || {}),
  });
  await ensureDriverLogin();
  console.log(`world: suppliers ${DISPATCH} (CTSGo dispatch) and ${RIDERS} (linked riders, ${DRIVER} linked), flag on in the emulator,`);
  console.log(`       driver ${DRIVER} (driver_delivery, approved, offline). Log in on the phone with 0200000001; code: \`sms-code\`.`);
}

async function ensureDriverLogin() {
  const auth = admin.auth();
  try {
    await auth.getUser(DRIVER);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    await auth.createUser({ uid: DRIVER, phoneNumber: DRIVER_PHONE, displayName: "EMU Test Driver" });
  }
}

async function reset() {
  const before = (await db.doc(`drivers/${DRIVER}`).get()).data() || {};
  const res = await fetch(`http://${HOST}:${PORTS.firestore}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: "DELETE" });
  if (!res.ok) fail(`could not clear the Firestore emulator (${res.status}).`);
  // Keep where the phone is and whether it is online, so the app and the data agree.
  const keep = {};
  for (const k of ["location", "currentLocation", "lastLocationUpdate", "isOnline", "isAvailable", "fcmToken"]) if (k in before) keep[k] = before[k];
  await world({ keepDriver: keep });
}

// ── Orders ──────────────────────────────────────────────────────────────────

async function driverDoc() {
  const snap = await db.doc(`drivers/${DRIVER}`).get();
  if (!snap.exists) fail("no test driver: run `world` first.");
  return snap.data();
}

async function anchor(argAt) {
  if (argAt) return { ...argAt, from: "--at" };
  const d = await driverDoc();
  const loc = d.location || d.currentLocation;
  return loc ? { latitude: loc.latitude, longitude: loc.longitude, from: "driver's location" }
    : { ...DEFAULT_AT, from: "default (Accra); go online in the app first to use the phone's location" };
}

/** The driver as the server needs them to take a job: online, free, located. */
async function readyDriver(at, { freshLocation = false } = {}) {
  const d = await driverDoc();
  if (d.currentTripId) fail(`${DRIVER} is already on job ${d.currentTripId}. Run \`reset\` first.`);
  const patch = {};
  if (d.isOnline !== true || d.isAvailable !== true) Object.assign(patch, { isOnline: true, isAvailable: true });
  if (!d.location) patch.location = new GeoPoint(at.latitude, at.longitude);
  const ts = d.lastLocationUpdate?.toMillis?.() ?? 0;
  if (freshLocation && Date.now() - ts > 5 * 60 * 1000) patch.lastLocationUpdate = Timestamp.now();
  if (Object.keys(patch).length) {
    await db.doc(`drivers/${DRIVER}`).update(patch);
    console.log(`driver: set ${Object.keys(patch).join(", ")} on the emulator's test driver`);
  }
}

/** quote -> order -> hold -> pay, as the passenger app does; pendingApproval. */
async function paidOrder(supplierId, places) {
  const q = await call(g.quoteGasSupplierOrder, { supplierId, stationId: ST, productId: PID, quantity: 1,
    location: places.customer, address: "EMU Customer House" }, PAX);
  const o = await call(g.createGasSupplierOrder, { quoteId: q.quoteId }, PAX);
  const { escrowId } = await call(escrow.holdBalance, { amount: o.total, serviceType: "gas", referenceType: "gas_supplier_order" }, PAX);
  await call(f.payGasSupplierOrder, { orderId: o.orderId, escrowId }, PAX);
  return o.orderId;
}

async function openJob(at) {
  const places = await placeStations(at);
  const orderId = await paidOrder(DISPATCH, places);
  await call(f.supplierRespondGasOrder, { orderId, decision: "accept" }, `${SUP_USER}-dispatch`);
  return orderId;
}

async function offerJob(at) {
  await readyDriver(at, { freshLocation: true });
  const places = await placeStations(at);
  const orderId = await paidOrder(RIDERS, places);
  await call(f.supplierRespondGasOrder, { orderId, decision: "accept", deliveryMode: "linked_rider" }, SUP_USER);
  const { offerSeq } = await call(f.supplierAssignGasRider, { orderId, riderId: DRIVER, replacesSeq: 0 }, SUP_USER);
  return { orderId, offerSeq };
}

async function driverJob(at, target) {
  await readyDriver(at);
  const orderId = await openJob(at);
  await call(f.acceptGasSupplierJob, { orderId }, DRIVER);
  if (target === "assigned") return orderId;
  await call(f.arriveGasSupplierStation, { orderId }, DRIVER);
  if (target === "at-station") return orderId;
  await call(f.supplierHandOverGasOrder, { orderId }, `${SUP_USER}-dispatch`);
  if (target === "out-for-delivery") return orderId;
  const { completionCode } = (await db.doc(`gas_supplier_orders/${orderId}`).get()).data();
  await call(f.completeGasSupplierOrder, { orderId, code: completionCode }, DRIVER);
  return orderId;
}

/** The supplier portal's hand-over, for the driver's job at the station. */
async function handover() {
  const snap = await db.collection("gas_supplier_orders").where("driverId", "==", DRIVER).where("status", "==", "atStation").get();
  if (snap.empty) fail(`${DRIVER} has no job at the station (tap "I'm at the station" in the app first).`);
  for (const doc of snap.docs) {
    const member = doc.data().supplierId === RIDERS ? SUP_USER : `${SUP_USER}-dispatch`;
    await call(f.supplierHandOverGasOrder, { orderId: doc.id }, member);
    console.log(`handover: ${doc.id} is out for delivery; the customer's code is ${(await doc.ref.get()).data().completionCode}`);
  }
}

async function status() {
  const snap = await db.collection("gas_supplier_orders").get();
  if (snap.empty) return console.log("status: no supplier orders.");
  const d = await driverDoc();
  console.log(`driver ${DRIVER}: online=${d.isOnline} available=${d.isAvailable} job=${d.currentTripId || "-"}`);
  for (const doc of snap.docs) {
    const o = doc.data();
    const offer = o.riderOffer?.driverId ? ` offer#${o.riderOffer.seq}->${o.riderOffer.driverId} until ${o.riderOffer.expiresAt?.toDate?.().toISOString()}` : "";
    const code = ["atStation", "outForDelivery"].includes(o.status) ? ` code=${o.completionCode}` : "";
    console.log(`  ${doc.id} ${o.status} ${o.deliveryMode || ""} supplier=${o.supplierId} driver=${o.driverId || "-"}${offer}${code}`);
  }
}

async function smsCode() {
  const res = await fetch(`http://${HOST}:${PORTS.auth}/emulator/v1/projects/${PROJECT_ID}/verificationCodes`);
  const codes = ((await res.json()).verificationCodes || []).filter((c) => c.phoneNumber === DRIVER_PHONE);
  if (!codes.length) return console.log(`sms-code: none yet for ${DRIVER_PHONE}; request one in the app.`);
  console.log(`sms-code: ${codes[codes.length - 1].code} (${DRIVER_PHONE})`);
}

// ── Main ────────────────────────────────────────────────────────────────────

function parseAt(args) {
  const i = args.indexOf("--at");
  if (i < 0) return null;
  const [lat, lng] = String(args[i + 1] || "").split(",").map(Number);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) fail("--at needs LAT,LNG");
  return { latitude: lat, longitude: lng };
}

async function main() {
  const [cmd, ...args] = process.argv.slice(2);
  const commands = ["world", "reset", "online", "open", "offer", "assigned", "at-station", "out-for-delivery", "delivered", "handover", "sweep", "status", "sms-code"];
  if (!commands.includes(cmd)) fail(`usage: node seed_supplier_jobs.js <${commands.join("|")}> [--at LAT,LNG]`);
  await requireEmulators();
  if (cmd === "sms-code") return smsCode();
  load();
  const at = parseAt(args);
  switch (cmd) {
    case "world": return world();
    case "reset": return reset();
    case "status": return status();
    // The every-minute schedule's body (no Pub/Sub emulator, so it never fires on its own).
    case "sweep": {
      const r = await f.runDeadlineSweeps();
      console.log(`sweep: ${r.errors.length ? `errors ${r.errors.join(", ")}` : "ran both deadline sweeps"} (see the order with \`status\`)`);
      return;
    }
    case "handover": return handover();
    // The app's Go Online needs a real FCM token, which a demo- project cannot get.
    case "online": {
      const a = await anchor(at);
      await readyDriver(a, { freshLocation: true });
      console.log(`online: ${DRIVER} online and available near ${a.latitude.toFixed(4)},${a.longitude.toFixed(4)} (${a.from})`);
      return;
    }
    case "open": {
      const a = await anchor(at);
      console.log(`open: job ${await openJob(a)} near ${a.latitude.toFixed(4)},${a.longitude.toFixed(4)} (${a.from})`);
      return;
    }
    case "offer": {
      const a = await anchor(at);
      const { orderId, offerSeq } = await offerJob(a);
      console.log(`offer: ${orderId} offered to ${DRIVER} (seq ${offerSeq}, 10 minutes) near ${a.latitude.toFixed(4)},${a.longitude.toFixed(4)} (${a.from})`);
      return;
    }
    default: {
      const a = await anchor(at);
      const orderId = await driverJob(a, cmd);
      const o = (await db.doc(`gas_supplier_orders/${orderId}`).get()).data();
      console.log(`${cmd}: ${orderId} is ${o.status}${o.status === "outForDelivery" ? `; the customer's code is ${o.completionCode}` : ""}`);
    }
  }
}

main()
  .then(() => { fft?.cleanup(); process.exit(0); })
  .catch((e) => { console.error(`seed: ${e.message}`); process.exit(1); });
