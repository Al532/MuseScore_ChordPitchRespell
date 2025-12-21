import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins/"
    description: qsTr("General-purpose enharmonic respell tool, especially effective on chords entered via MIDI.")
    version: "1.3.0"
    requiresScore: true

    function respellNotesRelativeToBass(notes) {
        if (notes.length < 2)
            return;

        // Identify the bass note as the lowest pitch in the chord to use as reference.
        var bassNote = notes[0];
        for (var i = 1; i < notes.length; i++) {
            if (notes[i].pitch < bassNote.pitch)
                bassNote = notes[i];
        }

        var pitchClassToTpcs = {
            0: [2, 14, 26],
            1: [9, 21, 33],
            2: [4, 16, 28],
            3: [-1, 11, 23],
            4: [6, 18, 30],
            5: [1, 13, 25],
            6: [8, 20, 32],
            7: [3, 15, 27],
            8: [10, 22],
            9: [5, 17, 29],
            10: [0, 12, 24],
            11: [7, 19, 31]
        };

        for (var j = 0; j < notes.length; j++) {
            var note = notes[j];

            if (note === bassNote)
                continue;

            // Choose the TPC closest to the bass note so the spelling aligns naturally.
            var candidates = pitchClassToTpcs[note.pitch % 12];
            var closestTpc = candidates[0];
            var minimalDistance = Math.abs(closestTpc - bassNote.tpc);

            for (var k = 1; k < candidates.length; k++) {
                var distance = Math.abs(candidates[k] - bassNote.tpc);
                if (distance < minimalDistance) {
                    minimalDistance = distance;
                    closestTpc = candidates[k];
                }
            }

            note.tpc = closestTpc;
        }
    }

    function applyKeySignatureAdjustment(notes, keySignature) {
        if (!notes.length)
            return;

        // Find the overall TPC span to gauge the chord's average spelling weight.
        var minTpc = notes[0].tpc;
        var maxTpc = notes[0].tpc;

        for (var i = 1; i < notes.length; i++) {
            var tpc = notes[i].tpc;
            if (tpc < minTpc)
                minTpc = tpc;
            if (tpc > maxTpc)
                maxTpc = tpc;
        }

        var averageTpc = (minTpc + maxTpc) / 2;
        var TpcAdjust = 2;
        var keyTpc = 16 + keySignature/TpcAdjust;

        var difference = keyTpc - averageTpc;


        var adjustment = Math.round(difference / 12) * 12;
        if (!adjustment)
            return;

        // Shift every note by a diatonic octave to better fit the key context.
        for (var j = 0; j < notes.length; j++)
            notes[j].tpc += adjustment;
    }

    // Run both respelling steps on a single chord.
    function processChord(notes, keySignature) {
        respellNotesRelativeToBass(notes);
        applyKeySignatureAdjustment(notes, keySignature);
    }

function processSelection() {
    var sel = curScore.selection;
    var elems = sel ? sel.elements : null;

    // 1) No selection => nothing to process.
    if (!elems || elems.length === 0) {
        return;
    }

    // 2) Range selection => reliable start/end ticks.
    if (sel.isRange) {
        processRangeSelection(sel.startSegment.tick, sel.endSegment.tick);
        return;
    }

    // 3) List selection => iterate over the chosen elements.
    processListSelection(elems);
}


function processRangeSelection(startTick, endTick) {
    var cursor = curScore.newCursor();
    cursor.rewind(Cursor.SELECTION_START);

    // Walk through every segment inside the selection and respell its chords.
    while (cursor.segment && cursor.tick < endTick) {
        if (cursor.element && cursor.element.type === Element.CHORD)
            processChord(cursor.element.notes, cursor.keySignature);
        cursor.next();
    }
}

function processListSelection(elements) {
    // Always process CHORDs, even if the user selected NOTE heads or other parts.
    var cursor = curScore.newCursor();

    var seen = {}; // de-duplicate chords.
    for (var i = 0; i < elements.length; i++) {
        var e = elements[i];
        if (!e) continue;

        var chord = null;

        if (e.type === Element.CHORD) {
            chord = e;
        } else if (e.type === Element.NOTE) {
            chord = e.parent; // a NOTE belongs to a CHORD
        } else {
            continue;
        }

        if (!chord) continue;

        // Deduplication key: tick + track is sufficient in practice.
        var key = chord.tick + ":" + chord.track;
        if (seen[key]) continue;
        seen[key] = true;

        // Safely retrieve the key signature at the chord's tick.
        cursor.track = chord.track;
        cursor.rewindToTick(chord.tick);

        processChord(chord.notes, cursor.keySignature);
    }
}


    onRun: {
        if (!curScore) {
            Qt.quit();
            return;
        }

        curScore.startCmd();
        processSelection();
        curScore.endCmd();
        Qt.quit();
    }
}
