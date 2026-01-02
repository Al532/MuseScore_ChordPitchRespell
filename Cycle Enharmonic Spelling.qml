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

    property var pitchClassToTpcs: ({
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
    })

    function mod12(x) {
        console.log("mod12", x);
        var r = x % 12;
        var result = r < 0 ? r + 12 : r;
        console.log("mod12 result", result);
        return result;
    }

    function uniqueSorted(values) {
        console.log("uniqueSorted input", values);
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
        console.log("uniqueSorted output", result);
        return result;
    }

    function intersect(a, b) {
        console.log("intersect input", a, b);
        var set = {};
        var result = [];
        for (var i = 0; i < a.length; i++)
            set[a[i]] = true;
        for (var j = 0; j < b.length; j++) {
            var v = b[j];
            if (set[v])
                result.push(v);
        }
        var output = uniqueSorted(result);
        console.log("intersect output", output);
        return output;
    }

    function averageTpc(notes) {
        console.log("averageTpc notes length", notes ? notes.length : "null");
        var total = 0;
        for (var i = 0; i < notes.length; i++)
            total += notes[i].tpc;
        var avg = total / notes.length;
        console.log("averageTpc result", avg);
        return avg;
    }

    function validShiftsForChord(notes) {
        console.log("validShiftsForChord notes length", notes ? notes.length : "null");
        if (!notes || notes.length === 0)
            return [];

        var shifts = null;
        for (var i = 0; i < notes.length; i++) {
            var note = notes[i];
            console.log("validShiftsForChord note", i, "pitch", note.pitch, "tpc", note.tpc);
            var pcs = mod12(note.pitch);
            var allowed = pitchClassToTpcs[pcs];
            if (!allowed) {
                console.log("validShiftsForChord no allowed TPCs for pitch class", pcs);
                return [];
            }

            var noteShifts = [];
            for (var j = 0; j < allowed.length; j++) {
                var delta = allowed[j] - note.tpc;
                if (delta % 12 === 0)
                    noteShifts.push(delta);
            }

            noteShifts = uniqueSorted(noteShifts);
            console.log("validShiftsForChord note shifts", noteShifts);
            if (shifts === null)
                shifts = noteShifts;
            else
                shifts = intersect(shifts, noteShifts);
        }

        var result = shifts ? shifts : [];
        console.log("validShiftsForChord result", result);
        return result;
    }

    function chooseShift(notes, shifts) {
        console.log("chooseShift shifts", shifts);
        if (!shifts || shifts.length <= 1)
            return 0;

        var sorted = uniqueSorted(shifts);
        var currentIndex = sorted.indexOf(0);
        if (currentIndex === -1)
            return 0;

        if (sorted.length === 2)
            return currentIndex === 0 ? sorted[1] : sorted[0];

        var avg = averageTpc(notes);
        console.log("chooseShift avg", avg, "direction", "ascending");

        for (var i = currentIndex + 1; i < sorted.length; i++) {
            if (sorted[i] > 0)
                return sorted[i];
        }
        for (var j = 0; j < sorted.length; j++) {
            if (sorted[j] !== 0)
                return sorted[j];
        }

        return 0;
    }

    function cycleChord(notes) {
        console.log("cycleChord notes length", notes ? notes.length : "null");
        var shifts = validShiftsForChord(notes);
        var shift = chooseShift(notes, shifts);
        console.log("cycleChord selected shift", shift);
        if (!shift) {
            console.log("cycleChord no shift applied");
            return;
        }

        for (var i = 0; i < notes.length; i++) {
            console.log("cycleChord apply shift to note", i, "old tpc", notes[i].tpc, "shift", shift);
            notes[i].tpc += shift;
            console.log("cycleChord new tpc", notes[i].tpc);
        }
    }

    function processSelection() {
        console.log("processSelection start");
        var sel = curScore.selection;
        var elems = sel ? sel.elements : null;

        if (!elems || elems.length === 0) {
            console.log("processSelection no elements in selection");
            return;
        }

        if (sel.isRange) {
            console.log("processSelection range selection");
            var endTick = sel.endSegment ? sel.endSegment.tick : null;
            if (endTick === null) {
                if (curScore.lastSegment)
                    endTick = curScore.lastSegment.tick;
                else
                    endTick = sel.startSegment.tick;
            }
            console.log("processSelection range startTick", sel.startSegment.tick, "endTick", endTick);
            processRangeSelection(sel.startSegment.tick, endTick);
            return;
        }

        console.log("processSelection list selection length", elems.length);
        processListSelection(elems);
    }

    function processRangeSelection(startTick, endTick) {
        console.log("processRangeSelection startTick", startTick, "endTick", endTick);
        var cursor = curScore.newCursor();
        cursor.rewind(Cursor.SELECTION_START);

        while (cursor.segment && cursor.tick <= endTick) {
            if (cursor.element && cursor.element.type === Element.CHORD) {
                console.log("processRangeSelection chord at tick", cursor.tick, "track", cursor.element.track);
                cycleChord(cursor.element.notes);
            }
            cursor.next();
        }
    }

    function processListSelection(elements) {
        console.log("processListSelection elements length", elements.length);
        for (var i = 0; i < elements.length; i++) {
            var e = elements[i];
            if (!e || e.type !== Element.NOTE) {
                console.log("processListSelection skip non-note element", i);
                continue;
            }
            console.log("processListSelection cycle note", i, "pitch", e.pitch, "tpc", e.tpc);
            cycleChord([e]);
        }
    }

    onRun: {
        console.log("Cycle Enharmonic Spelling onRun");
        if (!curScore) {
            console.log("No current score, quitting");
            Qt.quit();
            return;
        }

        console.log("Starting command");
        curScore.startCmd();
        processSelection();
        console.log("Ending command");
        curScore.endCmd();
        console.log("Cycle Enharmonic Spelling finished");
        Qt.quit();
    }
}
