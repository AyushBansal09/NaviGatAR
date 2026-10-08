# NaviGatAR for iPhone

Indoor navigation with augmented reality. Visitors scan a QR sign on the wall
and follow markers drawn in the camera view to their destination. Building
managers set up a venue on the same app: add locations, print their signs,
and record routes by walking them once.

Native Swift app: SwiftUI, ARKit, RealityKit, and Vision. It works fully
offline and needs no server or account.

## Requirements

| | |
|---|---|
| iPhone | Any iPhone that can run **iOS 18 or later** (iPhone XS/XR and newer). LiDAR on Pro models makes sign detection more precise. |
| iOS | **18.0 minimum.** That covers the current iOS 27 plus the two releases before it (iOS 26 and iOS 18). |
| Mac | Xcode 26 or newer (the newest Xcode is recommended). |
| Apple ID | A free Apple ID is enough to install on your own iPhone. A paid developer account is only needed for TestFlight or the App Store. |

The iOS Simulator can't run ARKit. You can use it to try the manager screens,
but test navigation on a real iPhone.

## Run it on your iPhone

1. Open `ios/NaviGatAR.xcodeproj` in Xcode.
2. Select the **NaviGatAR** target, then **Signing & Capabilities**:
   - choose your **Team** (your Apple ID; add it under *Xcode › Settings › Accounts* if it isn't listed);
   - if Xcode says the bundle identifier is taken, change `io.github.ayushbansal09.navigatar` to something unique, for example `com.yourname.navigatar`.
3. Connect the iPhone with a cable, or use Wi‑Fi pairing. Choose it as the run destination at the top of the Xcode window.
4. On the iPhone, enable **Settings › Privacy & Security › Developer Mode** and restart when asked. Xcode prompts for this the first time.
5. Press **Run** (⌘R). The first time, go to **Settings › General › VPN & Device Management** on the iPhone and trust your developer certificate.
6. Allow camera access when the app asks.

> With a free Apple ID the app expires after 7 days. Press Run in Xcode again to reinstall it.

## Try it in 1 minute

On the **Navigate** tab, tap **Start AR demo**. A path appears from where you
stand: about 4 m ahead, a floating "Open the door!" note, then a right turn.
Walk it to see the turn instructions, voice guidance, the **Map** and
**Steps** modes, and the arrival screen.

## Set up a real building

1. **Manage › + › New building**, then **Add location** for each place people
   look for: entrance, rooms, restrooms, elevators (one location per floor),
   and so on.
2. **Share › Print QR signs (PDF)** and print the sheet. Put each sign flat on
   a wall at eye level (about 1.4 m), in good light, where people naturally
   stop.
3. **Record a walking route** between two neighbouring locations:
   - stand in front of the start sign and scan it;
   - walk the route at a normal pace with the iPhone held up;
   - tap **Add note** for things like "Open the door!";
   - tap **Finish** and scan the sign at the end.

   Routes can be walked in both directions. You don't need a route between
   every pair of places, because NaviGatAR chains them together.
4. Use **Add elevator / stairs link** between locations on different floors,
   for example "Elevator – Floor 1" ↔ "Elevator – Floor 3". Mark stairs as not
   step-free so the **Step-free route** option avoids them.
5. **Needs attention** lists any location that isn't connected to the others yet.
6. **Share building file** sends the whole building, including routes, to
   other iPhones (AirDrop, Files, Messages). They import it with
   **Manage › + › Import building file**.

A visitor then picks a destination on the **Navigate** tab, taps **See route**
and **Start AR navigation**, and scans the nearest sign. If the iPhone Camera
app scans a sign, NaviGatAR opens with that sign set as the starting point.

## Features

- **AR path**: spheres, small dots or arrows; colours can be changed. Floating
  notes, a destination pin, and green outlines around signs on the way, so you
  can see the path is aligned.
- **Turn-by-turn**: instructions with distances, built from the recorded
  geometry. Shows "You're off the route" when you stray.
- **Voice and haptics**: spoken directions (routed through VoiceOver when it's
  on) and a vibration at each step.
- **Map and Steps modes**: a top-down map with your live position, and a step
  list, for people who don't want to look through the camera.
- **Accessibility**: step-free routing, high-contrast markers and banner,
  large instructions, Dynamic Type, VoiceOver labels, Reduce Motion.
- **Multi-floor**: elevator, stairs and escalator links with automatic
  instructions such as "Take the elevator to floor 3", then scan the sign to
  continue.
- **Re-alignment**: scan any sign along the way to correct drift. Scanning a
  sign that isn't on the route re-plans from there.
- **Help and feedback**: visitors can leave a message. Managers see it under
  the building.
- **Private and offline**: everything stays on the device.

## How positioning works

Each QR sign encodes `navigatar://location?b=<building>&l=<location>`. When
the camera sees a sign, Vision finds the code's corners and ARKit raycasts
them onto the real wall. That gives the sign's exact 3D position and the
direction the wall faces. Recorded routes are stored relative to the sign
they start from. Aligning the sign seen now with the sign seen during
recording places the whole path correctly in the room. ARKit's
visual-inertial tracking (and LiDAR on Pro iPhones) keeps it in place while
you walk.

## Project layout

```
ios/
├── NaviGatAR.xcodeproj
├── NaviGatAR/
│   ├── App/          app entry, storage, settings, onboarding
│   ├── Core/         platform-independent logic: models, geometry, route planning,
│   │                 turn-by-turn, sign pose estimation, file format (unit-tested)
│   ├── AR/           ARKit session, QR detection + raycasting, RealityKit rendering
│   ├── Navigation/   trip state machine, AR/Map/Steps screens, voice guidance
│   ├── Visitor/      home screen, location search, route preview, feedback
│   ├── Manager/      buildings, locations, QR sign PDFs, route recording, links
│   └── Assets.xcassets
├── CoreTests/        unit tests for Core
└── Package.swift     lets `swift test` run the Core tests (macOS or Linux)
```

Run the logic tests with:

```sh
cd ios
swift test
```

## Known limitations

- Very long routes can drift by a few percent. Place signs at junctions so
  people re-align on the way.
- Elevators break AR tracking, which is why floors are joined with links and a
  re-scan.
- Buildings are shared as files. Syncing through a server is a natural next
  step; the old Node.js backend in `../NaviGatAR/backend` could be adapted for
  that.
