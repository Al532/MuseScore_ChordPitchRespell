import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins/"
    description: qsTr("Enharmonic respelling tool optimized for MIDI-entered chords, preserving chord quality and respecting the current key signature. Best results are achieved when applied to a range selection, allowing chord-level logic to be applied.")
    version: "1.3.0"
    requiresScore: true

    function respellNotes(notes) {
        if (notes.length < 2)
            return;

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

        for (var j = 1; j < notes.length; j++) {
            var note = notes[j];

            if (note === notes[0])
                continue;

            // Choose the Tonal Pitch Class (TPC) closest to the first note so the spelling aligns naturally.
            var candidates = pitchClassToTpcs[note.pitch % 12];
            var closestTpc = candidates[0];
            var minimalDistance = Math.abs(closestTpc - notes[0].tpc);

            for (var k = 1; k < candidates.length; k++) {
                var distance = Math.abs(candidates[k] - notes[0].tpc);
                if (distance < minimalDistance) {
                    minimalDistance = distance;
                    closestTpc = candidates[k];
                }
            }

            note.tpc = closestTpc;
        }

        // Compute the average TPC after the initial pass, then run a second pass
        // to align each note toward this average spelling.
        var totalTpc = 0;
        for (var i = 0; i < notes.length; i++)
            totalTpc += notes[i].tpc;

        var meanTpc = totalTpc / notes.length;

        for (var j = 0; j < notes.length; j++) {
            var note = notes[j];
            var candidates = pitchClassToTpcs[note.pitch % 12];
            var closestToMean = candidates[0];
            var minDistanceToMean = Math.abs(closestToMean - meanTpc);

            for (var k = 1; k < candidates.length; k++) {
                var distanceToMean = Math.abs(candidates[k] - meanTpc);
                if (distanceToMean < minDistanceToMean) {
                    minDistanceToMean = distanceToMean;
                    closestToMean = candidates[k];
                }
            }

            note.tpc = closestToMean;
        }
    }

    function applyKeySignatureAdjustment(notes, keySignature) {
        if (!notes.length)
            return;

        // Find the chord's mean TPC span
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
		
		// TpcAdjust weights the spelling towards the center.
		// If TpcAdjust=1, spelling fully aligns with the key signature.
        // If TpcAdjust>1, spelling is more "centered", avoiding most double sharps/flats and extreme alterations.
		// Default value is 2.
		var TpcAdjust = 2;
		// Key Signature is mapped to a TPC, centered on 16 and weighted by TpcAdjust.
        var keyTpc = 16 + keySignature/TpcAdjust;

        var difference = keyTpc - averageTpc;


        var adjustment = Math.round(difference / 12) * 12;
        if (!adjustment)
            return;

        // Shift the whole chord enharmonically to better fit the key context.
        for (var j = 0; j < notes.length; j++)
            notes[j].tpc += adjustment;
    }

    // Run both respelling steps on a single chord.
    function processChord(notes, keySignature) {
        respellNotes(notes);
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
    var cursor = curScore.newCursor();
    var seenNotes = {};

    for (var i = 0; i < elements.length; i++) {
        var e = elements[i];
        if (!e) continue;

        if (e.type !== Element.NOTE)
            continue;

        var chord = e.parent;
        if (!chord) continue;

        var noteKey = chord.tick + ":" + chord.track + ":" + e.pitch;
        if (seenNotes[noteKey]) continue;
        seenNotes[noteKey] = true;

        cursor.track = chord.track;
        cursor.rewindToTick(chord.tick);

        applyKeySignatureAdjustment([e], cursor.keySignature);
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
