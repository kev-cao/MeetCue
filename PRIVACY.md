# MeetCue Privacy Policy

Effective November 10, 2026

MeetCue is a macOS menu bar app that shows your next meeting, alerts you before it starts, and keeps notes for each meeting. This policy explains what data MeetCue uses and where it goes.

## The short version

MeetCue runs entirely on your Mac. It has no servers, no accounts of its own, no analytics, and no ads. Your calendar data and notes never leave your Mac, except for MeetCue's requests to Google when you connect a Google account.

## Data MeetCue uses

### Calendars on your Mac

With your permission, MeetCue reads the events in the macOS Calendar app: titles, times, locations, video links, notes, attendees, and your replies. It uses them to show your meetings, find join links, and decide which meetings to alert you about. MeetCue reads events and never changes them.

### Google Calendar (optional)

If you choose Connect Google Calendar in Settings, MeetCue asks Google for read-only access to your calendar events (the `calendar.events.readonly` scope). It uses that access to read:

- your events' titles, times, and locations
- video meeting links, such as Google Meet links
- whether you've accepted, declined, or not yet replied

MeetCue uses this data only to show your meetings and alert you about them. It doesn't create, change, or delete anything in your Google account.

Google's data is kept in memory while MeetCue runs and is not saved to disk. The exception is notes you write, described below. The sign-in token Google issues is stored in your Mac's Keychain.

You can disconnect at any time with Disconnect in MeetCue's Settings, which deletes the token from your Keychain. You can also remove MeetCue's access from your Google account at https://myaccount.google.com/permissions.

### Your notes and settings

Notes you write for a meeting are stored on your Mac in `~/Library/Application Support/MeetCue`. Each note is linked to its meeting by the meeting's calendar identifier and start time. Settings, hidden calendars, and quiet mode are stored in MeetCue's preferences on your Mac.

If you export your notes, MeetCue writes them as Markdown files to a folder you choose. What happens to those files afterward is up to you.

## Sharing

MeetCue doesn't sell, share, or transfer your data to anyone. The only network requests it makes go to Google, to sign you in and to read your calendar, and only after you connect a Google account.

## Google API Services

MeetCue's use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

## Deleting your data

- To delete your notes, quit MeetCue and delete `~/Library/Application Support/MeetCue`.
- To remove Google access, use Disconnect in Settings, or remove MeetCue at https://myaccount.google.com/permissions.
- Deleting the app and that folder removes everything MeetCue stored.

## Changes

If this policy changes, the new version will be posted here with a new effective date.

## Contact

Questions about this policy can be filed as an issue at https://github.com/kev-cao/MeetCue/issues.
