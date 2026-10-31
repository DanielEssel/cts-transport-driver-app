// Preloaded (NODE_OPTIONS --require, set by start_emulators.sh) into the
// functions emulator runtime only.
//
// The emulator wraps firebase-admin in a proxy that returns `admin.firestore`
// as fn.bind(admin), which drops its statics: `admin.firestore.FieldValue` and
// `.Timestamp` become undefined and every function using them throws. Giving
// the returned function a named `prototype` makes the proxy hand it back
// unbound (its "constructor" case), statics intact. The function is an arrow
// function, so it never needed binding. Production loads no such proxy.
"use strict";

if (process.env.FUNCTIONS_EMULATOR === "true" && process.env.CTS_FUNCTIONS_DIR) {
  const admin = require(require.resolve("firebase-admin", { paths: [process.env.CTS_FUNCTIONS_DIR] }));
  let owner = admin;
  while (owner && !Object.getOwnPropertyDescriptor(owner, "firestore")) owner = Object.getPrototypeOf(owner);
  const desc = owner && Object.getOwnPropertyDescriptor(owner, "firestore");
  if (desc && desc.get && desc.configurable) {
    Object.defineProperty(owner, "firestore", {
      ...desc,
      get() {
        const fn = desc.get.call(this);
        if (typeof fn === "function" && !fn.prototype) fn.prototype = { constructor: function firestore() {} };
        return fn;
      },
    });
  } else {
    console.warn("admin_firestore_statics: firebase-admin's firestore getter not found; FieldValue may be undefined.");
  }
}
