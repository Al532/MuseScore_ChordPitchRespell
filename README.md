## Chord Pitch Respell plugin for Musescore

Enharmonic respelling tool optimized for MIDI-entered chords, preserving chord quality and respecting the current key signature. Best results are achieved when applied to a range selection, allowing chord-level logic to be applied. Note that the plugin only analyse the chord itself, without the use of a time window; therefore, its logic could be applied to MuseScore core MIDI entry, and this plugin is a proof of concept of a better behavior.

### Parallel maj7 chords
#### Raw MIDI entry
![](img/1-1.png)
#### MuseScore default pitch respell
Chords in red don't respect the chord quality.
![](img/1-2.png)
#### This plugin
Every chord is correctly written, and time signature also taken into account.
![](img/1-3.png)


![](img/2-1.png)
![](img/1-2.png)
![](img/1-3.png)
![](img/3-1.png)
![](img/3-2.png)
![](img/3-3.png)
