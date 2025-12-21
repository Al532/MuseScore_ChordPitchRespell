import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins/Enharmonic Respeller/Remplacer quintes justes"
    description: qsTr("Pour chaque accord, décale aléatoirement la TPC d'une quinte juste pour qu'elle soit à 1 de l'autre.")
    version: "1.1.0"
    requiresScore: true

    function adjustPerfectFifthPair(noteA, noteB) {
        // Choose one of the two notes randomly and adjust its TPC so that it differs by 1 from the other.
        var adjustFirst = Math.random() < 0.5;
        var referenceNote = adjustFirst ? noteB : noteA;
        var targetNote = adjustFirst ? noteA : noteB;
        var delta = Math.random() < 0.5 ? 1 : -1;

        targetNote.tpc = referenceNote.tpc + delta;
    }

    function processChord(notes) {
        if (notes.length < 2)
            return;

        for (var i = 0; i < notes.length; i++) {
            for (var j = i + 1; j < notes.length; j++) {
                var semitoneDistance = Math.abs(notes[i].pitch - notes[j].pitch);
                if (semitoneDistance === 7)
                    adjustPerfectFifthPair(notes[i], notes[j]);
            }
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
