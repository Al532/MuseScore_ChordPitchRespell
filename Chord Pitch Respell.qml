import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    description: qsTr("Enharmonic respelling tool optimized for MIDI-entered chords, preserving chord quality and respecting the current key signature. Best results are achieved when applied to a range selection, allowing chord-level logic to be applied.")
    version: "1.3.0"
    requiresScore: true

    function respellNotes(notes) {
    if (!notes || notes.length < 2)
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

    function mod12(x) {
        var r = x % 12;
        return r < 0 ? r + 12 : r;
    }

    // 1) Compute each note's residue class (TPC mod 12) from pitch class.
    var residues = [];
    for (var i = 0; i < notes.length; i++) {
        var pcs = mod12(notes[i].pitch);
        // Any candidate works for residue; take the first and reduce mod 12
        residues.push(mod12(pitchClassToTpcs[pcs][0]));
    }

    // 2) Find minimal arc on the circle (length 12) covering all residues.
    // Sort residues (keep duplicates).
    var s = residues.slice().sort(function(a,b){ return a-b; });

    // Duplicate with +12
    var t = s.slice();
    for (var k = 0; k < s.length; k++)
        t.push(s[k] + 12);

    // Sliding window of size n
    var n = s.length;
    var bestSpan = 1e9;
    var bestStart = t[0];

    for (var startIdx = 0; startIdx < n; startIdx++) {
        var span = t[startIdx + n - 1] - t[startIdx];
        if (span < bestSpan) {
            bestSpan = span;
            bestStart = t[startIdx];
        }
    }

    var start = bestStart;
    var end   = start + bestSpan;

    // 3) For each note, pick a candidate TPC that lies in [start, end] (allow +/-12 shifts).
    // Tie-break: closest to the chord reference (first note current tpc).
    var refTpc = notes[0].tpc;

    function liftIntoWindow(x, lo, hi) {
        // Return x + 12k in [lo, hi] if possible; else nearest (clamped) by shifting.
        // Because window length <= 11, there is at most one k that fits.
        var y = x + 12 * Math.floor((lo - x) / 12);
        if (y < lo) y += 12;
        if (y > hi) y -= 12; // safety
        return y;
    }

    for (i = 0; i < notes.length; i++) {
        var note = notes[i];
        var candidates = pitchClassToTpcs[mod12(note.pitch)];

        var chosen = candidates[0];
        var bestScore = 1e9;
        var bestSevenPenalty = 1e9;

        for (k = 0; k < candidates.length; k++) {
            var c = candidates[k];
            var cIn = liftIntoWindow(c, start, end);

            // Prefer candidates that actually land inside the window.
            // If window construction is correct, at least one should.
            var inside = (cIn >= start && cIn <= end);
            if (!inside)
                continue;

            // Score: keep chord tight (already ensured) + align to ref spelling
            var score = Math.abs(cIn - refTpc);

            // Tie-breaker: avoid homonyms (TPC distances of 7) when possible.
            var sevenPenalty = 0;
            for (var otherIdx = 0; otherIdx < notes.length; otherIdx++) {
                if (otherIdx === i)
                    continue;
                var otherTpc = notes[otherIdx].tpc;
                if (typeof otherTpc !== "number")
                    continue;
                if (Math.abs(cIn - otherTpc) % 7 === 0 && cIn !== otherTpc)
                    sevenPenalty++;
            }

            var betterScore = score < bestScore;
            var betterTie = score === bestScore && sevenPenalty < bestSevenPenalty;

            if (betterScore || betterTie) {
                bestScore = score;
                bestSevenPenalty = sevenPenalty;
                chosen = cIn;
            }
        }

        note.tpc = chosen;
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
