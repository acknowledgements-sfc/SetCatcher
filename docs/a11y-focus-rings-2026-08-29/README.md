# Keyboard focus-ring stills — 2026-08-29

Captured from live `.build/DJMemory.app` via AX focus + Tab + `screencapture -l`.

## Home

| File | Focused control | Visible focus cue |
|------|-----------------|-------------------|
| `crop_00_home_scanNow.png` | `home.scanNow` | Thin bright blue border around Scan Now |
| `crop_01_home_openLibrary.png` | `home.openLibrary` | Thin blue rectangle around Open Library |
| `lanes_02_home_lane_serato.png` | `home.lane.serato` | Lane strip (blue-channel pixel delta vs next) |
| `lanes_03_home_lane_rekordbox.png` | `home.lane.rekordbox` | Same |

## Library

| File | Focused control | Notes |
|------|-----------------|-------|
| `library_04_archivedSets_segment.png` | Archived Sets segment | Segment selected (system blue fill) |
| `library_05_dateFilter.png` | `library.dateFilter` | Date control focused per AX; ring subtler than Home buttons |

## Settings

| File | Focused control | Notes |
|------|-----------------|-------|
| `settings_00_automaticScanning.png` | `settings.automaticScanning` | AX focus on checkbox; crop shows interval segment selection state |
| `settings_02_verifyCopies.png` | `settings.verifyCopies` | Adjacent step for comparison |

**Verdict:** Home primary/ghost buttons show clear keyboard focus rings. Library/Settings use native controls where selection fill often doubles as the focus cue; no missing-focus defect confirmed on these samples.
EOF
