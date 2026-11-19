# Setup

## Requirements

Use Flutter 3.22 or newer and Dart 3.4 or newer (see `pubspec.yaml`).

## Firebase

1. Create or select a Firebase project and register the app's platform
   identifiers.
2. Enable **Email/Password** under Firebase Authentication.
3. Run `flutterfire configure` for the target platform and check the generated
   `lib/firebase_options.dart` and platform configuration files into the
   appropriate environment as needed.

## Supabase

1. Create a Supabase project.
2. In its SQL Editor, apply [supabase_setup.sql](../supabase_setup.sql) to
   create the baseline schema.
3. In the Supabase Dashboard, configure **Authentication → Third-Party Auth**
   to trust the Firebase project. The app sends its Firebase ID token to
   Supabase; configuring this trust is required for database identity checks.
4. Apply migrations 001 through 005 in the order documented in
   [DATABASE.md](DATABASE.md). In particular, migration 005 is currently at
   `supabase/005_cashout_idempotency_and_status.sql`.
5. Configure the Supabase project URL and public publishable/anon key used by
   `lib/main.dart`. These client values are not a substitute for database
   authorization. Never put a service-role key in the Flutter app.

Fetch dependencies with `flutter pub get`, then run on a configured device with
`flutter run`. These instructions do not imply that this setup was tested here.

## Creating an admin

First create and sign in to the intended account through the app so its
`public.profiles` row exists. In the Supabase SQL Editor, identify the exact
profile and promote it by its Firebase UID:

```sql
select id, email, role
from public.profiles
where email = '<exact account email>';

update public.profiles
set role = 'admin'
where id = '<Firebase UID from the selected profile>'
  and role = 'scholar'
returning id, email, role;
```

Check the returned row before using the admin account. Do not grant the role
from the client or expose SQL editor credentials to the app.
