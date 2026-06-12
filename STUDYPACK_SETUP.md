# Study Pack Sharing — Setup

The app fully supports exporting and importing `.studypack` files **without** any extra setup.

- **Export** — open a lesson, tap the share button. The lesson is bundled with all its
  modules, flashcards, and embeddings, and shared as a `.studypack` file via the standard
  share sheet (AirDrop, Messages, Mail, Save to Files, etc.).
- **Import (in-app picker)** — go to the **Lessons** tab → **+ menu** → **Import Study Pack**,
  then pick a `.studypack` file. Works out of the box.

## Optional: Tap-to-open from Files / AirDrop

For `.studypack` files to open **directly** in this app when the user taps them in Files,
Mail, or accepts via AirDrop, you need to register the file type in the target's Info.plist.
This project uses generated Info.plist values (`GENERATE_INFOPLIST_FILE = YES`), so the
easiest way is to add these via Xcode's **Target → Info** tab.

### 1. Exported Type Identifier

Under **Exported Type Identifiers**, add:

| Field         | Value                                              |
|---------------|----------------------------------------------------|
| Description   | Study Pack                                         |
| Identifier    | `com.mangolassiglazers.learningapp.studypack`      |
| Conforms To   | `public.json`                                      |
| Extensions    | `studypack`                                        |

### 2. Document Type

Under **Document Types**, add:

| Field         | Value                                              |
|---------------|----------------------------------------------------|
| Name          | Study Pack                                         |
| Types         | `com.mangolassiglazers.learningapp.studypack`      |
| Role          | Editor                                             |
| Handler Rank  | Owner                                              |

After this is set up, the existing `onOpenURL` handler in `learningappApp.swift` will fire
automatically when the user taps a `.studypack` file anywhere in iOS.

## Schema versioning

The export format includes a `version` field. If you ever change the format in a
breaking way:

1. Bump `StudyPackExport.currentVersion` in `Models/StudyPackExport.swift`
2. Update `StudyPackService.decode` to handle older versions or surface a clear error
