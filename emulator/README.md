# Driver app on local Firebase emulators

Gas supplier jobs on a physical phone, without production. Project
`demo-ctsgo-driver`; app ID `com.cts.ctsgo.driver.emulator` ("CTS Driver
EMULATOR", red EMULATOR banner). The production app and data are untouched.

`backend/` links (read-only use) to the passenger repo's `functions/`,
`firestore.rules`, `firestore.indexes.json` and `storage.rules`: the same
tree the release builds its rules from. Payments run in stub mode from the
git-ignored `functions/.env.local` and `functions/.secret.local` (fake values).

## Run

```bash
# 1. Emulators (127.0.0.1 only; refuses to start unless its checks pass)
./emulator/start_emulators.sh

# 2. Phone over USB
./emulator/adb_reverse.sh ZY22JXJ8DS

# 3. Data (Node 22)
node emulator/seed_supplier_jobs.js world

# 4. App
flutter run -d ZY22JXJ8DS --debug --flavor emulator \
  --dart-define-from-file=env.json \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Log in with `0200000001`; get the code with
`node emulator/seed_supplier_jobs.js sms-code`. Go online in the app (its GPS
becomes the anchor for the synthetic stations), then create a scenario:
`open`, `offer`, `assigned`, `at-station`, `out-for-delivery`, `delivered`;
`handover` performs the supplier portal's step; `status` lists orders and
the customer's code; `reset` starts over. Scheduled sweeps (offer expiry,
supplier deadline) do not run: there is no Pub/Sub emulator.

## Safety

The app refuses to start (red screen) when: the flag is on in a release
build, on a non-`demo-ctsgo-driver` project or a non-loopback host; the
emulator flavor runs without the flag; or the emulator hub does not list
Auth, Firestore, Functions and Storage on their ports. The prod flavor keeps
`ctstransportapp` and ignores all of this.

## Host requirements

- Java 21 (`/usr/lib/jvm/java-21-openjdk-amd64`), Node 22 with firebase-tools.
- File watching: `start_emulators.sh` polls (`CHOKIDAR_USEPOLLING=1`), so
  an exhausted inotify limit (ENOSPC) does not stop the emulators.
- Disk: about 2 GB free per flavor build.
