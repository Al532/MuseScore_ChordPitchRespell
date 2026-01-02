import QtQuick 2.0
import MuseScore 3.0

/**
 * CYCLE ENHARMONIC SPELLING
 * ==========================
 *
 * Cycles through the available enharmonic spellings for each chord in the
 * current selection by shifting all chord TPCs by a shared multiple of 12.
 */
MuseScore {
    description: qsTr("Cycle enharmonic spellings per chord by shifting all chord TPCs together.")
    version: "1.0.0"
    requiresScore: true

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

    function uniqueSorted(values) {
        var map = {};
        var result = [];
        for (var i = 0; i < values.length; i++) {
            var v = values[i];
            if (!map[v]) {
                map[v] = true;
                result.push(v);
            }
        }
        result.sort(function(a, b) { return a - b; });
        return result;
    }

    function intersect(a, b) {
        var set = {};
        var result = [];
        for (var i = 0; i < a.length; i++)
            set[a[i]] = true;
        for (var j = 0; j < b.length; j++) {
            var v = b[j];
            if (set[v])
                result.push(v);
        }
        return uniqueSorted(result);
    }

    function averageTpc(notes) {
        var total = 0;
        for (var i = 0; i < notes.length; i++)
            total += notes[i].tpc;
        return total / notes.length;
    }

    function validShiftsForChord(notes) {
        if (!notes || notes.length === 0)
            return [];

        var shifts = null;
        for (var i = 0; i < notes.length; i++) {
            var note = notes[i];
            var pcs = mod12(note.pitch);
            var allowed = pitchClassToTpcs[pcs];
            if (!allowed) {
                return [];
            }

            var noteShifts = [];
            for (var j = 0; j < allowed.length; j++) {
                var delta = allowed[j] - note.tpc;
                if (delta % 12 === 0)
                    noteShifts.push(delta);
            }

            noteShifts = uniqueSorted(noteShifts);
            if (shifts === null)
                shifts = noteShifts;
            else
                shifts = intersect(shifts, noteShifts);
        }

        return shifts ? shifts : [];
    }

    function chooseShift(notes, shifts) {
        if (!shifts || shifts.length <= 1)
            return 0;

        var sorted = uniqueSorted(shifts);
        var currentIndex = sorted.indexOf(0);
        if (currentIndex === -1)
            return 0;

        if (sorted.length === 2)
            return currentIndex === 0 ? sorted[1] : sorted[0];

        var avg = averageTpc(notes);
        var direction = avg < 16 ? 1 : (avg > 16 ? -1 : 1);

        if (direction > 0) {
            for (var i = currentIndex + 1; i < sorted.length; i++) {
                if (sorted[i] > 0)
                    return sorted[i];
            }
            for (var j = 0; j < sorted.length; j++) {
                if (sorted[j] !== 0)
                    return sorted[j];
            }
        } else {
            for (var k = currentIndex - 1; k >= 0; k--) {
                if (sorted[k] < 0)
                    return sorted[k];
            }
            for (var l = sorted.length - 1; l >= 0; l--) {
                if (sorted[l] !== 0)
                    return sorted[l];
            }
        }

        return 0;
    }

    function cycleChord(notes) {
        var shifts = validShiftsForChord(notes);
        var shift = chooseShift(notes, shifts);
        if (!shift)
            return;

        for (var i = 0; i < notes.length; i++)
            notes[i].tpc += shift;
    }

    function processSelection() {
        var sel = curScore.selection;
        var elems = sel ? sel.elements : null;

        if (!elems || elems.length === 0)
            return;

        if (sel.isRange) {
            var endTick = sel.endSegment ? sel.endSegment.tick : null;
            if (endTick === null) {
                if (curScore.lastSegment)
                    endTick = curScore.lastSegment.tick;
                else
                    endTick = sel.startSegment.tick;
            }
            processRangeSelection(sel.startSegment.tick, endTick);
            return;
        }

        processListSelection(elems);
    }

    function processRangeSelection(startTick, endTick) {
        var cursor = curScore.newCursor();
        cursor.rewind(Cursor.SELECTION_START);

        while (cursor.segment && cursor.tick <= endTick) {
            if (cursor.element && cursor.element.type === Element.CHORD)
                cycleChord(cursor.element.notes);
            cursor.next();
        }
    }

    function processListSelection(elements) {
        var seenChords = {};
        for (var i = 0; i < elements.length; i++) {
            var e = elements[i];
            if (!e || e.type !== Element.NOTE)
                continue;

            var chord = e.parent;
            if (!chord)
                continue;

            var chordKey = chord.tick + ":" + chord.track;
            if (seenChords[chordKey])
                continue;
            seenChords[chordKey] = true;

            cycleChord(chord.notes);
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
