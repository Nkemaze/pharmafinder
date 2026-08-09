# PharmaFinder — Pharmacy Inventory & Admin Console

PharmaFinder is a web app for pharmacies to manage inventory (drugs, stock,
pricing, sales, expiry, store status and profile) and for the platform
administrator to provision and manage pharmacy accounts.

## Stack

- Flutter (web-first) + Material 3
- Firebase Authentication
- Cloud Firestore
- flutter_map / OpenStreetMap
- Cloudinary (drug image uploads)

## Functionality

**Pharmacies**
- Login with email + password (admin-created credentials)
- Dashboard with live inventory statistics, open/closed status, charts and alerts
- Manage drugs (add / edit / delete / restock / sell, categories, packet pricing, expiry, images)
- Record sales with automatic stock deduction
- Store status (open/closed derived from operating hours)
- Pharmacy profile (name, license, address, location on map, store hours, emergency contact)

**Administrator (new)**
- Admin portal is **hidden** — there is no button or link on the login page. It is reached only via a secret URL route (see "Accessing the admin portal" below)
- Overview dashboard: total / active / pending-setup / suspended / deleted pharmacies
- Manage pharmacies: create accounts, search + filter, suspend / activate, soft-delete / restore, reset password (sends a reset email)
- When a pharmacy is created with email + temporary password, the pharmacy is **required** to update its profile and choose a new password before entering the dashboard (enforced by the `mustUpdateProfile` flag).

## Accessing the admin portal

The portal is intentionally not linked anywhere in the app. Open it by navigating directly to the secret route:

```
https://pharma-finder-6d99d.web.app/#/admin-console
```

- Only people who know this path can reach the admin login.
- The path is defined in `lib/config/admin_config.dart` (`adminRoutePath`). To change it, edit that constant, rebuild and redeploy (see Development).
- The `#/` form is Flutter web's default (hash) routing; the path after `#` is your secret.

## One-time administrator setup

The admin portal bootstraps the **first** administrator account.

1. **Deploy Firestore rules** (required — they protect the admin role and keep pharmacies scoped to their own data):

   ```bash
   firebase login
   firebase deploy --only firestore:rules
   ```

2. Navigate to the secret route above (e.g. `https://pharma-finder-6d99d.web.app/#/admin-console`).
3. Because no admin exists yet, the form switches to **Create Administrator Account**.
4. Enter your email, password, and the setup code:
   - `PharmaAdmin#2026`
   - The code is defined in `lib/config/admin_config.dart`. **Change it after first setup**, and remove/update the matching `hasBootstrapKey()` check in `firestore.rules`, then redeploy.

## Creating pharmacy accounts (admin)

1. Admin portal → **Pharmacies** → **Add Pharmacy**.
2. Enter pharmacy name, email, and a temporary password (use **Generate**).
3. Send the email + password to the pharmacy. On their first login they are forced to:
   - Fill in their pharmacy profile, and
   - Change their password.
4. The pharmacy dashboard unlocks automatically after setup.

## Resetting a pharmacy password

Client apps cannot change another user's password. Use the **reset** action in the admin portal — it emails the pharmacy a password-reset link. (For full user management, e.g. permanently deleting auth accounts, use the Firebase console.)

## Firestore rules

Rules live in `firestore.rules` (deploy as above). They:
- Require authentication everywhere.
- Allow each pharmacy to read/write only its own `pharmacies/{uid}` document and subcollections.
- Allow admins (users present in `admins`) to manage every pharmacy and the admins collection.
- Allow the first-run admin bootstrap only with the matching setup key.

## Deploying updates to the live website

The live site (https://pharma-finder-6d99d.web.app) is hosted on Firebase Hosting. After making changes to the code, push them online with:

```bash
flutter build web --release     # 1. Compile the app into build/web
firebase deploy --only hosting  # 2. Upload it to the live site
```

Notes:

- If you changed **Firestore rules** (`firestore.rules`), deploy those too:

  ```bash
  firebase deploy --only firestore:rules
  ```

- `firebase deploy` (with no flags) deploys everything configured in `firebase.json` (hosting + rules) in one command.
- After deploying, hard-refresh the browser (Ctrl+Shift+R) to bypass cached files.
- To fully clear cached builds, you can delete `build/` before building:

  ```bash
  rm -rf build && flutter build web --release
  ```

## Development

```bash
flutter pub get
flutter run -d chrome        # run locally
flutter build web --release  # production build (build/web)
flutter test                 # unit tests
flutter analyze              # static analysis
```
