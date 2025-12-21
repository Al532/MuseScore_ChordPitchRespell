import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins/Enharmonic Respeller/Remplacer quintes justes"
    description: qsTr("Pour chaque accord, orthographie chaque note en minimisant l'écart de TPC à la tonique et, à égalité, à la basse.")
    version: "1.3.0"
    requiresScore: true

    function findBass(notes) {
        var bass = notes[0];
        for (var i = 1; i < notes.length; i++) {
            if (notes[i].pitch < bass.pitch)
                bass = notes[i];
        }
        return bass;
    }

    function chooseClosestTpc(candidates, targetTpc, tieTpc) {
        var closestTpc = candidates[0];
        var minimalDistance = Math.abs(closestTpc - targetTpc);
        var tieDistance = tieTpc !== undefined ? Math.abs(closestTpc - tieTpc) : Number.MAX_VALUE;

        for (var i = 1; i < candidates.length; i++) {
            var candidate = candidates[i];
            var distance = Math.abs(candidate - targetTpc);
            var candidateTieDistance = tieTpc !== undefined ? Math.abs(candidate - tieTpc) : Number.MAX_VALUE;

            if (distance < minimalDistance || (distance === minimalDistance && candidateTieDistance < tieDistance)) {
                closestTpc = candidate;
                minimalDistance = distance;
                tieDistance = candidateTieDistance;
            }
        }

        return closestTpc;
    }

    function respellChord(notes, keySignature) {
        if (!notes.length)
            return;

        var tonicTpc = keySignature + 14;
        var bassNote = findBass(notes);

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

        var bassCandidates = pitchClassToTpcs[bassNote.pitch % 12];
        bassNote.tpc = chooseClosestTpc(bassCandidates, tonicTpc);

        for (var j = 0; j < notes.length; j++) {
            var note = notes[j];
            var candidates = pitchClassToTpcs[note.pitch % 12];
            var tieTpc = note === bassNote ? undefined : bassNote.tpc;
            note.tpc = chooseClosestTpc(candidates, tonicTpc, tieTpc);
        }
    }

    function processChord(notes, keySignature) {
        respellChord(notes, keySignature);
    }

    function processSelection() {
        var cursor = curScore.newCursor();
        cursor.rewind(Cursor.SELECTION_START);

        var hasSelection = !!cursor.segment;
        if (!hasSelection)
            cursor.rewind(Cursor.START);

        var selectionEndTick = hasSelection ? curScore.selectionEndTick : -1;

        while (cursor.segment && (!hasSelection || cursor.tick < selectionEndTick)) {
            if (cursor.element && cursor.element.type === Element.CHORD)
                processChord(cursor.element.notes, cursor.keySignature);
            cursor.next();
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
