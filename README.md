## Chord Pitch Respell Plugin for MuseScore

Enharmonic respelling tool optimized for MIDI-entered chords, preserving chord quality and respecting the current key signature. Best results are achieved when applied to a range selection, allowing chord-level logic to be applied.

Note that the plugin analyzes each chord independently, without using a time window. **As such, its logic could be applied directly to MuseScore’s core MIDI input. This plugin is intended as a proof of concept demonstrating improved enharmonic spelling behavior.**

The core idea is to minimize the spread of [Tonal Pitch Classes](https://musescore.github.io/MuseScore_PluginAPI_Docs/plugins/html/tpc.html) across all notes of a chord, while also taking the current key signature into account.
A configurable constant is used to down-weight the use of extreme accidentals (double flats and double sharps), and a homonym penalty discourages spellings that place homonyms (e.g. G and G♯) inside the same chord window.

### Parallel maj7 chords

#### Raw MIDI entry
![](img/1-1.png)

#### MuseScore default 'optimize enharmonic spelling'
Chords highlighted in red exhibit inconsistent chord quality, even worse than the raw MIDI entry.<br>
![](img/1-2.png)

#### This plugin
All chords are correctly spelled, with the key signature properly taken into account and improved readability.<br>
![](img/1-3.png)

### Big band saxophone chords (to be exploded across parts)

#### Raw MIDI entry
![](img/2-1.png)

#### MuseScore default 'optimize enharmonic spelling'
Chord highlighted in red exhibits inconsistent chord quality, and some double flats could have been avoided.<br>
![](img/2-2.png)

#### This plugin
All chords are correctly spelled, with the key signature properly taken into account and improved readability.<br>
![](img/2-3.png)

### Big band trombone chords (to be exploded across parts)

#### Raw MIDI entry
![](img/4-1.png)

#### MuseScore default 'optimize enharmonic spelling'
Chord highlighted in red exhibits inconsistent chord quality (A♭, C# and F♯), and some double flats could have been avoided.<br>
![](img/4-2.png)

#### This plugin
All chords are correctly spelled, with just enough flexibility relative to the key signature to improve readability.<br>
![](img/4-3.png)
