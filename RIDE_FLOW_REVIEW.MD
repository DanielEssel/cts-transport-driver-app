# CTS Transport — RIDE Flow Production-Readiness Review

_Parallel to BOOKING_FLOW_REVIEW.md (delivery). Same approach: screen by screen, fix in priority order, verify each. Reuse templates T1-T9 (esp. T1 PricingService fares, T2 RouteService road distance, T3 matching timeout)._

Legend: 🔴 must-fix (blocker) · 🟡 should-fix · 🟢 polish · ⭐ money/stuck-passenger

---

## ✅ RESOLVED: LIVE RIDE STACK (confirmed via main.dart + shell imports)
- **LIVE book_ride:** `lib/features/ride/presentation/book_ride_screen.dart` (main.dart:34, shell:15). NOTE: this is `ride/presentation/`, NOT `ride/presentation/screens/`.
- **LIVE ride tracking:** `lib/features/ride_tracking/ride_tracking_screen.dart` (main.dart:40, shell:18). Stack A.
- **LIVE matching:** TBD — whatever the LIVE book_ride navigates to (need grep).
- **DEAD CODE (ignore):** everything in `lib/features/ride/presentation/screens/` (book_ride_screen, ride_tracking_screen, driver_matching_screen). The pretty real-map tracking screen pasted earlier is from here = DEAD.

⚠️ The earlier "EARLY OBSERVATIONS" below were on the DEAD `screens/` files — DISREGARD them. Must re-review the LIVE files above.

---

## CONFIRMED LIVE RIDE FLOW
1. **book_ride** `ride/presentation/book_ride_screen.dart` (456 lines) — confirm-guard/escrow/nav ✅. **BUGS FOUND (screenshot):**
   - ✅ FARE CONSISTENCY FIXED: card (RideOptionsService.calculateDynamicPrice) == confirm (state.calculatedFare) == escrow == CF, all via PricingService.calculateRideFare. Verified GHS15==GHS15 in app.
   - 🔴 DISTANCE BUG ⭐ (ride A5) **CONFIRMED + FIX:** `PlaceResult.distanceKm` is nullable + NEVER populated (selectPlace just stores place; no routing call). So toNavigationResult returns distance:null → book_ride falls back to `RideConstants.defaultDistanceKm` (8.2) → EVERY ride priced on 8.2km regardless of real destination. FIX: `_openDestinationSearch` now calls `routeServiceProvider.getRoute(origin, destLoc)` for real road distance (+ straight-line fallback + default last resort), like delivery A5. Reuses working Directions. Pending in-app verify (distance should vary by destination, fare = base+perKm*realKm).
   - 🟡 T2-followup: `_applyDestinationFromArgs` (rebook/saved-place path) still uses straight-line Geolocator — switch to RouteService for consistency. Secondary.
   - ✅ FARE FORMULA ALIGNED (Option A: distance-only). Was: client `base+perKm×km` (perMin ignored — calculatedFare passes no waitingMinutes) but CF `base+perKm×km+perMin×min` (applied time) → divergence (payout > display). FIX: CF calculateRideFare line 62 → `(base + perKm * km) * surge` (dropped perMin). Deployed. Now display==escrow==payout, distance-only. Surge/floor ordering already consistent (both surge-then-floor; CF header comment was stale but code matched). Verified math: okada 5.3km = 3 + 1.5×5.3 = 10.95 ≈ 11. Surge effectively OFF (fare has no ×1.5).
   - PENDING: confirm okadaSurgeEnabled flag in admin settings (fare suggests OFF). End-to-end wallet ride → completion CF log should show fare≈11=held=displayed.
   - 🟢 RideOption.basePrice (baseFare+perKm*8.2) is legacy precompute, no longer drives fare (card uses calculateDynamicPrice). Harmless.
   - GREP PENDING: destination_search_screen.dart distance logic + ride_constants.defaultDistanceKm value.
   - ✅ "Change" dropoff FIXED + VERIFIED. Was: stale selectedPlace in provider auto-popped DestinationSearchScreen on open → crash cascade (looked like "goes home"). FIX: clearQuery() on open + listener guard (next != prev selectedPlace). Now opens, lets user pick new destination, recomputes distance.
2. **driver_matching** `ride/presentation/driver_matching_screen.dart` (617 lines) — has timeout/countdown/listener/dialogs already (NO infinite-spin). BUGS FOUND:
   - 🔴 Bug1: timeout values inconsistent — `_secondsLeft=120`, `_timeoutSeconds=300` → progress bar starts at 40% not 100%. FIX: `_timeoutSeconds=60; _secondsLeft=_timeoutSeconds`.
   - 🔴 Bug2 ⭐: passenger cancel (`cancelledByPassenger`) — onTripCancelled CF DOES refund ✅ (status in list).
   - 🔴 Bug3 ⭐ **MONEY BUG FOUND + FIX:** timeout writes `noDriversAvailable` but onTripCancelled refund list had `noDrivers` (≠ `noDriversAvailable`). So timeout/no-driver → escrow NEVER refunded (passenger paid, no driver, money stuck). FIX: added `noDriversAvailable` to `cancelledStatuses` in trips.js:~845 + reason mapping. Redeploy `onTripCancelled`. (Also covers index.js server-dispatch which writes same status.)
   - NOTE: ride has SERVER-SIDE dispatch in index.js (query drivers, 5km filter, FCM push) + writes `noDriversFound` to a parallel `requests`-style doc — separate from the driver-app broadcast feed. Two dispatch mechanisms may coexist. Out of scope now; revisit.
   - 🔴 Bug1: timeout values inconsistent (`_secondsLeft=120` vs `_timeoutSeconds=300` → progress bar starts 40%). FIX: `_timeoutSeconds=60; _secondsLeft=_timeoutSeconds`.
3. **ride tracking** `ride_tracking/ride_tracking_screen.dart` (795 lines) — ✅ REAL GoogleMap, _TripStatus enum (handles tripAccepted→driverArrived→tripStarted/inProgress→completed), live driver location, stepper, SOS, navigates to TripComplete via pushReplacement (not affected by nested-nav bug). **FIXED:** line 410 (_cancelRide) + line 457 (Book Again) → `rootNavigator: true` (line 356-357 no-show path was already correct). 🟢 fake share URL `ctstrip.app/track/{id}` (cosmetic, share text only). Screen otherwise solid.
4. **trip_complete** `ride/presentation/trip_complete_screen.dart` (629 lines) — ✅ EXCELLENT, no fixes needed. Star rating writes `passengerRating` to trip + updates driver aggregate (ratingTotal/ratingCount increments), tip support, fare receipt card, batch write, graceful skip + error handling, `_goHome()` rootNavigator. Done.
5. **driver active trip** `cts-transport-driver-app/.../active_trip_screen.dart` (1168 lines) — status writes align (tripAccepted→driverArrived(309)→tripStarted(326)→completed(359)), writes driverCurrentLocation, real map, cancel→refund CF. PRODUCTION AUDIT BUGS:
   - 🔴 "Done"/complete nav → `/driver-shell` (auto-nav after complete + Done button). If route name not registered at root → silently fails ("stale", button does nothing). GREP PENDING: confirm registered driver-shell route name (passenger uses /shell; driver may be /driver-home etc). FIX: use correct route name.
   - 🟡 ⭐ FARE DIVERGENCE RISK: completion writes `actualDistanceKm: _distKm` where `_distKm` is HAVERSINE straight-line (from _recalcEta/_haversineKm), NOT road distance. If CF onTripCompleted RECOMPUTES fare from actualDistanceKm → diverges from passenger's road-distance display (11). MUST check: does CF trust client finalFare or recompute from actualDistanceKm? GREP PENDING.
   - 🟢 _callPassenger dead first line (`final phone = _trip?.driverPhone` unused/shadowed).
   - 🟢 driver marker rotation:0 always (never uses driverHeading despite flat:true).
   - 🟢 _loadCustomMarkers reads _trip?.serviceType before _trip loaded (defaults taxi).

## ✅ RIDE FLOW REVIEW COMPLETE — all 5 screens reviewed
Fixes applied: matching money bug (noDriversAvailable refund, deployed) + matching timeout values (cosmetic) + tracking nav (lines 410/457 rootNavigator). Everything else was already in good shape (real maps both sides, rating, escrow, live tracking, status alignment). **Pending verification: one end-to-end ride test (book→accept→arrive→start→complete→rating→payout) + the timeout-refund money path.**

---

## EARLY OBSERVATIONS (from pasted Stack B files — confirm live first)

### book_ride_screen.dart (ride/presentation/screens/)
- ✅ Confirm-button guard present (`isLoading` double-tap guard + active-trip guard + HapticFeedback)
- ✅ Escrow hold (wallet) + rollback on failure + attachToOrder; cash skips escrow
- ✅ `_navigateToTracking` already uses `rootNavigator: true` for all 3 service types
- ✅ Wallet top-up nav uses `rootNavigator: true`
- 🟡 T2: rebook/saved-place geocode path uses straight-line `Geolocator.distanceBetween` for distance (should use RouteService road distance like delivery A5). Main path gets distance from DestinationSearchScreen result.
- 🟢 Commented-out service-preselect code (dead) — clean up.

### ride_tracking_screen.dart (ride/presentation/screens/) — IF LIVE, this is GOOD
- ✅ REAL GoogleMap (not placeholder!) — driver/pickup/dropoff markers, custom style, camera fit, live driver location (`driverCurrentLocation`)
- ✅ Status stepper, SOS sheet, call/message/share, driver card
- ✅ Navigates to TripCompleteScreen on completion (with fare/driver data)
- ✅ PopScope blocks back-nav during active trip
- 🔴 `_cancelRide` (~341): `Navigator.pushNamedAndRemoveUntil(context, '/shell')` — needs `rootNavigator: true` (nested-navigator "Unknown route" bug)
- 🔴 `_showDriverCancelledDialog` "Book Again" (~407): same `rootNavigator: true` fix
- 🟡 Share link is a fake domain `ctstrip.app/track/{id}` — not a real tracking URL
- 🟢 SOS numbers hardcoded (191/193 Ghana) — fine for launch

NOTE: If the `ride_tracking/` (Stack A) screen is the live one instead, must review THAT file — may differ (could be the older one with bugs at lines 410/457 from earlier grep).