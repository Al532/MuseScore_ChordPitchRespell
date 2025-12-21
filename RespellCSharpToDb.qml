import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins/Enharmonic Respeller/Remplacer quintes justes"
    description: qsTr("Pour chaque accord, orthographie chaque note par rapport à la basse avec la distance de TPC minimale.")
    version: "1.2.0"
    requiresScore: true

    function processChord(notes) {
        if (notes.length < 2)
            return;

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

    function processSelection() {
        var cursor = curScore.newCursor();
        cursor.rewind(Cursor.SELECTION_START);

        var hasSelection = !!cursor.segment;
        if (!hasSelection)
            cursor.rewind(Cursor.START);

        var selectionEndTick = hasSelection ? curScore.selectionEndTick : -1;

        while (cursor.segment && (!hasSelection || cursor.tick < selectionEndTick)) {
            if (cursor.element && cursor.element.type === Element.CHORD) {
                var notes = cursor.element.notes;
                processChord(notes);
            }
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
