import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    description: qsTr("Enharmonic respelling tool optimized for MIDI-entered chords, preserving chord quality and respecting the current key signature. Best results are achieved when applied to a range selection, allowing chord-level logic to be applied.")
    version: "1.3.0"
    requiresScore: true

    function respellNotes(notes) {
    if (!notes || notes.length < 2) {
        console.log("respellNotes: skipping because chord has less than two notes");
        return;
    }

    console.log("respellNotes: processing", notes.length, "notes");

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

    console.log("respellNotes: residues", residues);

    // 2) Find minimal arc on the circle (length 12) covering all residues.
    // Sort residues (keep duplicates).
    var s = residues.slice().sort(function(a,b){ return a-b; });
    console.log("respellNotes: sorted residues", s);

    // Duplicate with +12
    var t = s.slice();
    for (var k = 0; k < s.length; k++)
        t.push(s[k] + 12);
    console.log("respellNotes: extended residues for wrapping", t);

    // Sliding window of size n
    var n = s.length;
    var bestSpan = Infinity;
    var minimalWindows = [];

    for (var startIdx = 0; startIdx < n; startIdx++) {
        var span = t[startIdx + n - 1] - t[startIdx];
        var windowStart = t[startIdx];
        var windowEnd = windowStart + span;
        var isBetter = span < bestSpan;
        var isTie = span === bestSpan;

        console.log(
            "respellNotes: window", startIdx,
            "start", windowStart,
            "end", windowEnd,
            "span", span,
            isBetter ? "< current best" : (isTie ? "= current best" : "> current best")
        );

        if (isBetter) {
            bestSpan = span;
            minimalWindows = [{
                startIdx: startIdx,
                windowStart: windowStart,
                windowEnd: windowEnd,
                values: t.slice(startIdx, startIdx + n)
            }];
            console.log("respellNotes: new leading window at index", startIdx, "with span", bestSpan);
        } else if (isTie) {
            minimalWindows.push({
                startIdx: startIdx,
                windowStart: windowStart,
                windowEnd: windowEnd,
                values: t.slice(startIdx, startIdx + n)
            });
            console.log("respellNotes: window", startIdx, "added to tie for best span", bestSpan);
        }
    }

    console.log("respellNotes: minimal windows count", minimalWindows.length, "with span", bestSpan);

    function countExactHomonyms(values) {
        var count = 0;
        for (var i = 0; i < values.length; i++) {
            for (var j = i + 1; j < values.length; j++) {
                if (values[j] - values[i] === 7)
                    count++;
            }
        }
        return count;
    }

    var chosenWindow = minimalWindows[0];
    var fewestHomonyms = countExactHomonyms(chosenWindow.values);

    console.log("respellNotes: evaluating ties on homonym intervals"); // homonym count is the main tie-breaker
    console.log(
        "respellNotes: window", chosenWindow.startIdx,
        "values", chosenWindow.values,
        "homonyms", fewestHomonyms,
        "<= current minimum"
    );

    for (var w = 1; w < minimalWindows.length; w++) {
        var windowInfo = minimalWindows[w];
        var homonyms = countExactHomonyms(windowInfo.values);

        console.log(
            "respellNotes: window", windowInfo.startIdx,
            "values", windowInfo.values,
            "homonyms", homonyms,
            homonyms < fewestHomonyms ? "< current minimum" : "≥ current minimum"
        );

        if (homonyms < fewestHomonyms) {
            chosenWindow = windowInfo;
            fewestHomonyms = homonyms;
            console.log("respellNotes: new chosen window", windowInfo.startIdx, "with", homonyms, "homonyms");
        }
    }

    var start = chosenWindow.windowStart;
    var end   = chosenWindow.windowEnd;

    console.log("respellNotes: best window", start, "to", end, "(span", bestSpan, "homonyms", fewestHomonyms, ")");

    // 3) For each note, pick a candidate TPC that lies in [start, end] (allow +/-12 shifts).
    // If multiple candidates survive the homonym pass, gently favor the first note's existing TPC;
    // keySignatureAdjustment later ensures the chord still aligns with the key context.
    var baseTpc = notes[0].tpc;

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

        for (k = 0; k < candidates.length; k++) {
            var c = candidates[k];
            var cIn = liftIntoWindow(c, start, end);

            // Prefer candidates that actually land inside the window.
            // If window construction is correct, at least one should.
            var inside = (cIn >= start && cIn <= end);
            if (!inside)
                continue;

            // Score: keep chord tight (already ensured) + gently prefer the existing chord spelling when still tied
            var score = Math.abs(cIn - baseTpc);
            if (score < bestScore) {
                bestScore = score;
                chosen = cIn;
            }
        }

        note.tpc = chosen;
        console.log("respellNotes: note", i, "pitch", note.pitch, "chosen TPC", chosen, "(candidates", candidates, ")");
    }
}


    function applyKeySignatureAdjustment(notes, keySignature) {
        if (!notes.length) {
            console.log("applyKeySignatureAdjustment: no notes provided");
            return;
        }

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

                console.log("applyKeySignatureAdjustment: keySignature", keySignature, "minTpc", minTpc, "maxTpc", maxTpc, "avg", averageTpc);
		
		// TpcAdjust weights the spelling towards the center.
		// If TpcAdjust=1, spelling fully aligns with the key signature.
        // If TpcAdjust>1, spelling is more "centered", avoiding most double sharps/flats and extreme alterations.
		// Default value is 2.
		var TpcAdjust = 2;
		// Key Signature is mapped to a TPC, centered on 16 and weighted by TpcAdjust.
        var keyTpc = 16 + keySignature/TpcAdjust;

        var difference = keyTpc - averageTpc;


        var adjustment = Math.round(difference / 12) * 12;
        if (!adjustment) {
            console.log("applyKeySignatureAdjustment: no adjustment needed");
            return;
        }

        // Shift the whole chord enharmonically to better fit the key context.
        for (var j = 0; j < notes.length; j++) {
            notes[j].tpc += adjustment;
        }
        console.log("applyKeySignatureAdjustment: applied adjustment", adjustment);
    }

    // Run both respelling steps on a single chord.
    function processChord(notes, keySignature) {
        console.log("processChord: starting with", notes.length, "notes and key signature", keySignature);
        respellNotes(notes);
        applyKeySignatureAdjustment(notes, keySignature);
        console.log("processChord: finished");
    }

function processSelection() {
    var sel = curScore.selection;
    var elems = sel ? sel.elements : null;

    // 1) No selection => nothing to process.
    if (!elems || elems.length === 0) {
        console.log("processSelection: no selection, exiting");
        return;
    }

    // 2) Range selection => reliable start/end ticks.
    if (sel.isRange) {
        console.log("processSelection: processing range selection");
        processRangeSelection(sel.startSegment.tick, sel.endSegment.tick);
        return;
    }

    // 3) List selection => iterate over the chosen elements.
    console.log("processSelection: processing list selection");
    processListSelection(elems);
}


function processRangeSelection(startTick, endTick) {
    var cursor = curScore.newCursor();
    cursor.rewind(Cursor.SELECTION_START);

    console.log("processRangeSelection: from", startTick, "to", endTick);

    // Walk through every segment inside the selection and respell its chords.
    while (cursor.segment && cursor.tick < endTick) {
        if (cursor.element && cursor.element.type === Element.CHORD) {
            console.log("processRangeSelection: processing chord at tick", cursor.tick, "track", cursor.track);
            processChord(cursor.element.notes, cursor.keySignature);
        }
        cursor.next();
    }
}

function processListSelection(elements) {
    var cursor = curScore.newCursor();
    var seenNotes = {};

    console.log("processListSelection: processing", elements.length, "elements");

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
            console.log("onRun: no score open, quitting");
            Qt.quit();
            return;
        }

        console.log("onRun: starting respell process");
        curScore.startCmd();
        processSelection();
        curScore.endCmd();
        console.log("onRun: finished respell process");
        Qt.quit();
    }
}
