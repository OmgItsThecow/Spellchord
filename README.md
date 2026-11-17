# Spellchord — Harmonic & Modal Explorer

Cross-platform **Chord Progression, Voice Leading & Modal Interchange Explorer** targeting **Windows**, **Linux**, and **Android**, built with Flutter and deterministic MIDI-integer music theory algorithms (`0..127`).

## Key Features

- **Strict Dark Mode Interface**: Charcoal/slate surfaces (`#121212`, `#18181B`, `#1E1E24`) with high-contrast off-white typography and muted harmonic function accents.
- **Deterministic MIDI Music Theory Engine**:
  - **Progression Builder**: Triads, seventh chords, extensions (`add9`, `9`, `11`, `13`), and chromatic alterations (`b5`, `#5`, `b9`, `#9`, `#11`, `b13`).
  - **Harmonic Analysis**: Automatic key-center detection and lockable tonal center assigning Roman numeral functions (diatonic chords, secondary dominants, diminished passing chords, and borrowed chords).
  - **Inversion & Voice Leading Solver**: Computes optimal chord inversions minimizing semitone movement while prioritizing common tones and stepwise voice motion, with manual inversion stepping and spacing variants.
  - **Modal Interchange Explorer**: Compares the active tonal center against parallel modes (`Dorian`, `Phrygian`, `Lydian`, `Mixolydian`, `Aeolian`, `Locrian`, and `Ionian`) and suggests 1-click borrowed chord substitutions.
- **Interactive Instrument Visualizers**:
  - **Piano Mode**: Scalable 2-octave interactive MIDI keyboard distinguishing bass/root tones from upper chord tones, with common-tone markers and voice-leading motion vectors.
  - **Guitar Mode**: Dynamic fretboard matrix driven by configurable open-string MIDI pitches and a per-string boolean filter mask (e.g., top 4 strings `D-G-B-E`), plus tuning presets (`Standard`, `Drop D`, `DADGAD`, `Open G`, `All Fourths`) and per-string semitone tuning steppers.
- **Bilingual UI & Experience Modes**:
  - Startup language selector supporting **English** and **Español**.
  - **Basic Mode** (guided beginner layout without raw MIDI integers or complex alterations) and **Advanced Mode** (full MIDI telemetry, SATB motion table, and custom tunings).
- **Custom User Presets**: Save, load, and manage custom chord progressions locally (`user_presets.json`), alongside 9 built-in progression templates.

## Running & Testing

```bash
flutter pub get
flutter analyze
flutter test

# Launch on Linux, Windows, or Android:
flutter run -d linux
flutter run -d windows
flutter run -d android
```

## License

Copyright (C) 2026 **SniffingWizard** and **OMGitstheCow**.

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)** — see the [LICENSE](LICENSE) file for details.
