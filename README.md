# MeetCue

A macOS menu bar app that keeps your next meeting in view, so you don't lose track of time and end up late.

MeetCue is in early development (version 0.1.0). It isn't on the App Store; you build it yourself from source, as described below.

## What it does today

- **Your next meeting in the menu bar.** More than an hour out it shows the start time (`2:30 PM · Team Sync`). Within the hour it counts down (`in 24m`), and during the meeting it shows the time left (`12m left`, or `1h 20m left` for long ones). Titles longer than 10 characters scroll as the meeting approaches.
- **A dropdown with the details.** The meeting's time, location and video service together (`Room 4B · Google Meet`), and a **Join meeting** button for Zoom, Google Meet and Microsoft Teams links. Links found in the event's URL, location or notes all work.
- **Quiet mode.** Turn it on for an hour, until the end of the day, or until you turn it off. The menu bar shows a moon while it's on.
- **Follows your Mac.** It reads every calendar you've added to macOS Calendar (iCloud, Google, Exchange), skips meetings you've declined, and follows the macOS 24-hour time setting.

## Coming next

- A full-screen alert a few minutes before each meeting, which you can shrink to a countdown in the corner.
- Markdown notes on any meeting, with topics you haven't covered carried over to the next occurrence of a recurring meeting.
- A notes card that appears in the corner when a meeting starts.
- A calendar window, a Settings window, and an optional Google Calendar connection for richer meeting details.

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26, with its license accepted (`sudo xcodebuild -license accept`) and selected as the active developer directory:

  ```bash
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  ```

- [XcodeGen](https://github.com/yonaskolb/XcodeGen), which generates the Xcode project from `project.yml`:

  ```bash
  brew install xcodegen
  ```

## Build and run locally

1. Clone the repository and generate the Xcode project:

   ```bash
   git clone https://github.com/kev-cao/MeetCue.git
   ```

   ```bash
   cd MeetCue && xcodegen generate
   ```

2. Build a Release copy of the app:

   ```bash
   xcodebuild -project MeetCue.xcodeproj -scheme MeetCue -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData build
   ```

3. Copy it to your Applications folder and open it:

   ```bash
   cp -R build/DerivedData/Build/Products/Release/MeetCue.app /Applications/
   ```

   ```bash
   open /Applications/MeetCue.app
   ```

MeetCue has no Dock icon; look for it in the menu bar. On first launch macOS asks for access to your calendars. Click **Allow**, and your next meeting appears. If you denied access, open the dropdown and click **Open Privacy Settings**, or go to System Settings › Privacy & Security › Calendars.

To quit, open the dropdown and click **Quit MeetCue** (or press ⌘Q while it's open).

**Start at login:** add `MeetCue.app` in System Settings › General › Login Items.

### Calendar access after rebuilding

The project signs the app ad hoc, so you don't need an Apple developer account. The catch is that macOS ties the calendar permission to that exact build, and may ask again after you rebuild. To keep the permission across builds, sign with your free personal team: in `project.yml`, replace

```yaml
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual
```

with your team ID (shown in Xcode › Settings › Accounts):

```yaml
    DEVELOPMENT_TEAM: YOUR_TEAM_ID
    CODE_SIGN_STYLE: Automatic
```

then run `xcodegen generate` and build again.

## Running the tests

The decision logic lives in the `MeetCueCore` Swift package and has its own test suite:

```bash
cd MeetCueCore && swift test
```

The app's tests (the meeting store, quiet mode, the menu bar model, and view snapshots) run through Xcode:

```bash
xcodebuild -project MeetCue.xcodeproj -scheme MeetCue -destination 'platform=macOS' -derivedDataPath build/DerivedData test
```

The tests launch the app as their host but skip its setup, so they never ask for calendar access.

## Project layout

```
project.yml                XcodeGen spec for the app and its tests
App/MeetCue/               the app: EventKit loading, menu bar item, dropdown, quiet mode
App/MeetCueTests/          app tests
MeetCueCore/               Swift package with the decision logic and its tests:
                           meetings, video links, filtering, menu bar text,
                           alert rules, Markdown topics and carry-over
```

## Privacy

MeetCue reads your calendars on your Mac through Apple's EventKit and never changes them. Nothing is sent anywhere.
