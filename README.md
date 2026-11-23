# PolyFind

PolyFind is a Flutter lost-and-found app for students and staff of The Nyeri
National Polytechnic.

## Stack

- Flutter, Riverpod, and `go_router`
- Supabase Postgres, Auth, Storage, and Realtime
- `image_picker` and `flutter_image_compress` (item photos are compressed to
  under 300 KB before upload)
- `cached_network_image`, Freezed, `json_serializable`, and `intl`

Push notifications are not configured in this first version. Claim changes
appear in the app through Supabase Realtime while it is open.

## Supabase setup

1. Create a Supabase project on the [Supabase Dashboard](https://supabase.com/dashboard).
   The free plan is sufficient to get started.
2. In **Authentication → Providers**, enable Email. To sign in immediately
   after registration as this app currently expects, disable email
   confirmations under **Authentication → Settings**. If confirmations stay
   enabled, users must confirm their email and then sign in.
3. Open **SQL Editor**, paste and run [`supabase/schema.sql`](supabase/schema.sql).
   It creates the tables, indexes, profile signup trigger, RLS policies,
   `item-photos` bucket, Storage policies, claim-review RPC, and Realtime
   publication entries.
4. In **Project Settings → API**, copy the **Project URL** and the **anon /
   publishable key**. Do not use the `service_role` or secret key in the app.
   The app reads both values from Dart defines and does not contain project
   credentials.
5. Install packages and generate the Freezed/JSON/Riverpod code:

   ```sh
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

6. Run on a device or emulator, replacing the placeholders with values from
   your Supabase project:

   ```sh
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_OR_PUBLISHABLE_KEY
   ```

   Use the same `--dart-define` values with `flutter build` for release builds.
   Keep them in your local launch configuration or CI environment rather than
   hardcoding them. The anon/publishable key is intended for client use; RLS
   policies are the security boundary. Never ship a service-role key.

7. The schema enables Realtime for `items` and `claims`. If using a project
   where those tables already existed, verify they are listed under
   **Database → Publications → supabase_realtime**.
8. The `item-photos` bucket is public-read and accepts images no larger than
   300 KiB. Upload paths are scoped to each authenticated user's UUID.

### First admin

New signups receive the `student` role. Promote a trusted account from the SQL
Editor using its email; the SQL Editor runs with administrative privileges:

```sql
update public.profiles
set role = 'admin'
where id = (
  select id from auth.users where email = 'admin@thenyeripoly.ac.ke'
);
```

Role changes made through the app are blocked for non-admin users by RLS.

## Data and access rules

The schema is in [`supabase/schema.sql`](supabase/schema.sql).

- `profiles`: auth user id, display name, role, and creation time.
- `items`: lost/found details, optional `image_path`, owner, status, and dates.
- `claims`: claimant, item, verification answer, status, and creation time.
- RLS is enabled on every application table. Signed-in users can read open
  items and their own/related items; users can create and edit only their own
  content. Item owners (and admins) can review claims. Only admins can change
  roles or remove another user's item.
- Claim review uses a Postgres function so approving a claim and marking its
  item claimed happen in one transaction.
- Public photo URLs are derived from `image_path`; the database stores object
  paths, not expiring signed URLs.

Admission number is sent as Auth user metadata during signup and is not stored
in the public profile table. It is not checked against an official student
roster.

## Development

```sh
flutter test
flutter analyze
```

The school email domain and image size limit are in
[`lib/core/constants/app_constants.dart`](lib/core/constants/app_constants.dart).
The app's Flutter configuration is in `lib/main.dart`; credentials are supplied
at runtime as `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

To create launcher icons, put a 1024×1024 image at `assets/images/logo.png` and
run:

```sh
dart run flutter_launcher_icons
```
