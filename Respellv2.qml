import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins/Enharmonic Respeller/Remplacer quintes justes"
    description: qsTr("Pour chaque accord, orthographie chaque note avec la TPC la plus proche de la tonique.")
    version: "1.3.1"
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

    function respellNotesRelativeToTonic(notes, keySignature) {
        if (!notes.length)
            return;

        var tonicTpc = keySignature + 14;

        for (var i = 0; i < notes.length; i++) {
            var candidates = pitchClassToTpcs[notes[i].pitch % 12];
            var closestTpc = candidates[0];
            var minimalDistance = Math.abs(closestTpc - tonicTpc);

            for (var j = 1; j < candidates.length; j++) {
                var distance = Math.abs(candidates[j] - tonicTpc);
                if (distance < minimalDistance) {
                    minimalDistance = distance;
                    closestTpc = candidates[j];
                }
            }

            notes[i].tpc = closestTpc;
        }
    }

    function processChord(notes, keySignature) {
        respellNotesRelativeToTonic(notes, keySignature);
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
