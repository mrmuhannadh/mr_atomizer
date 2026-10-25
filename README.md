# Jira Mate

A small app that reminds you to log your time in Jira, and helps you send your daily task plan and end-of-day (EoD) emails. It also logs your worked time in Jira for you.

Works on **Windows** and **Android**.

## Features

- **Time-log reminder.** Get a notification on weekdays if you have logged less than your daily minimum (default 8 hours). You choose the time, the days, and the minimum hours.
- **Today view.** See how many hours you have logged today.
- **Log history.** Browse your logged time for this week, this month, or any date range. Days below your goal are highlighted.
- **Daily task plan email.** Pick your Jira tasks (or search by ID like `ABC-123`), set an estimate for each, and send the plan to your To and CC people as a table.
- **EoD email and automatic time log.** At the end of the day, enter the time you worked and a short description for each task. The app logs the time in Jira and sends the EoD email as a reply to the plan.
- **Plan and EoD reminders.** Get a reminder if you have not sent the plan or the EoD yet.
- **Two ways to send email.** Use your email account (SMTP), or open the email in Outlook and press Send yourself.
- **Runs in the tray (Windows).** Closing the window hides the app so reminders keep working.

## Install

**Windows**
1. Go to the repository's **Releases** page and download `jira-notifier-windows-setup.exe`.
2. Run it. It installs to `C:\Program Files\Jira Mate` and can add a desktop shortcut.
3. Windows may show "Windows protected your PC" because the installer is not code-signed. Click **More info**, then **Run anyway**.

**Android**
1. Download `jira-notifier-android.apk` from the **Releases** page.
2. Open it on your phone. Allow "install unknown apps" for your browser if asked.

## First-time setup

### 1. Create a Jira API token
1. Open <https://id.atlassian.com/manage-profile/security/api-tokens> and sign in.
2. Click **Create API token**, name it (for example "Jira Mate"), and copy the token. It is shown only once.

### 2. Connect the app
1. Open the app and go through the short welcome screens.
2. Fill in:
    - **Jira site:** for example `yourcompany.atlassian.net`
    - **Atlassian email:** the email you use to sign in to Jira
    - **API token:** the token you just copied
3. Tap **Connect**. If the details are right, you land on the home screen.

### 3. Set your reminders
Go to **Settings** (gear icon):
- Choose the **reminder time** for the time-log reminder.
- Choose the **days** and the **minimum hours** per day.

### 4. Turn on the daily plan and EoD emails (optional)
Go to **Settings → Daily plan & EoD emails** and switch it on.
1. Enter the **To** and **CC** email addresses (separate with commas) and your name for the sign-off.
2. Set the **plan reminder** and **EoD reminder** times.
3. Under **Send emails with**, choose one:
    - **Outlook app** (no password needed). The app opens the email in Outlook. For the table, click in the email body and press **Ctrl+V** to paste it, then press Send and confirm in the app.
    - **Email account** (SMTP). Enter your mail server details and password, and the app sends the email itself. Gmail needs an app password. Many company mailboxes do not allow this.
4. Tap **Save**.

## Daily use

1. **Morning:** on the home screen, tap **Send plan**. Add your tasks, set estimates, and send.
2. **Evening:** tap **Send EoD**. Enter the time worked and a description for each task, then send. The time is added to the Jira tasks automatically.
3. Use the **history** icon to review what you logged.

## Privacy

Everything stays on your device. Your Jira token and email password are stored in the device's secure storage. They are only sent to your own Jira site and your own mail server. To remove them, go to **Settings → Disconnect Jira**.

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install).

```bash
flutter pub get
flutter run -d windows     # or: flutter run (for an Android device)
```

Pushing a tag such as `v2.1.0` builds the Android APK and the Windows installer and attaches them to a GitHub Release.