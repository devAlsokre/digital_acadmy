# Digital Academy

Flutter mobile app for the Digital Academy university student portal.

## Phase 2 Scope

Implemented foundation authentication flow:

- Supabase email/password login
- Splash session check
- Profile role lookup
- Student profile fetch by `students.auth_user_id`
- Student-only navigation to the mobile home screen
- Logout

Teacher, college admin, and admin mobile screens are intentionally not included
yet.

## Android Run Command

Use Dart defines for Supabase configuration. Do not hardcode real credentials in
source files.

PowerShell:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=http://192.168.1.106:8000 `
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY `
  --dart-define=ACTIVATION_API_URL=http://192.168.1.106:3000/api/student/activate-account
```

Check available devices:

```powershell
flutter devices
```

## Student Account Activation

Students who have been entered by the university but are not yet linked to
Supabase Auth can activate their account from the login screen. The mobile app
sends the university number, university email, and selected password to the
configured activation endpoint.

Set the activation endpoint at run time:

```powershell
--dart-define=ACTIVATION_API_URL=http://192.168.1.106:3000/api/student/activate-account
```

On an Android phone, do not configure the endpoint using `127.0.0.1`.
Use the LAN address of the computer running the Admin Dashboard server, such as
`http://192.168.1.101:3000/api/student/activate-account`.

The endpoint is responsible for securely creating the Supabase Auth account and
linking `students.auth_user_id`. The Flutter app does not contain a
`service_role` key and does not create Auth users directly.

## Offline Local Background Notifications

Phase 6.2 uses Android WorkManager and local device notifications. No Firebase,
APNs, or cloud push service is used.

How it works:

- After a student signs in, the app saves a small background session for Android
  polling. It does not store the password or any service role key.
- The phone periodically polls the self-hosted Supabase server over the
  university local network.
- New unread notifications are shown as local device alerts.
- Duplicate alerts are avoided with local `shared_preferences` storage.
- Opening notifications in the app still controls read/unread status.
- The app saves the current access token for authenticated RLS polling. It does
  not save the password or refresh token; opening the app after sign-in updates
  the saved background session.

Limitations:

- Android WorkManager periodic jobs have a minimum interval of about 15 minutes.
  This is not instant push notification.
- The phone must be connected to the university Wi-Fi or another network that
  can reach the local Supabase server.
- Android may delay background tasks because of battery optimization, idle mode,
  or vendor restrictions.
- For testing, keep the phone on the university Wi-Fi and manually disable
  battery optimization for the app if needed.
- If guaranteed instant delivery is required later, a real push notification
  service would be needed. This phase intentionally avoids internet/cloud push.

## Realtime + Local Background Notifications

Foreground notification updates use Supabase Realtime while the app is open and
connected to the local Supabase server. Android WorkManager polling remains in
place for background LAN checks. No Firebase, APNs, or cloud push service is
used.

Enable these tables in the Supabase Realtime publication:

```sql
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.notification_targets;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.notification_reads;
exception
  when duplicate_object then null;
end $$;
```

Realtime gives immediate in-app updates only while the app is active and the
phone can reach the local Supabase server. If the app is killed or Android
restricts background work, delivery may be delayed until the app opens again or
WorkManager is allowed to run.

## Android LAN Background Alerts

Phase 6.4 adds an Android foreground service for local LAN notification checks
while the app is minimized. Android requires every foreground service to show a
persistent user-visible notification while it runs. The persistent notification
shows:

- Title: `Digital Academy`
- Text: `Listening for university notifications`

The app intentionally uses foreground-service polling mode:

- App open: Supabase Realtime updates the Notifications screen immediately.
- App minimized: the Android foreground service checks the local Supabase server
  about every 30 seconds and shows local alerts for new unread notifications.
- App killed, force-stopped, or restricted: WorkManager remains as a delayed
  fallback, but Android may delay or stop work.

Notes:

- No Firebase, APNs, or cloud push service is used.
- Alerts work only while the phone can reach the local Supabase server on the
  university network.
- If the user force-stops the app, Android stops all foreground/background work
  until the user opens the app again.
- Battery optimization may still affect behavior on some devices.
- Read notifications are cached locally and checked against
  `notification_reads`, so they should not alert again.
- iOS reliable background push would require APNs and is not implemented in this
  local-only Android phase.

During development, uninstall and reinstall the app after notification-channel
changes. Android keeps old channel settings on the device, so a channel that was
created earlier with sound or badge behavior may keep those settings until the
app is reinstalled.

## Verification

```powershell
dart format lib test
flutter analyze
flutter test
```
