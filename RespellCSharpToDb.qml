import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins/Enharmonic Respeller/Changer Do# en Ré♭"
    description: qsTr("Remplace tous les do# sélectionnés par des ré bémol.")
    version: "1.0.0"
    requiresScore: true

    function respellCSharpToDb(note) {
        // tpc 22 corresponds to C sharp; 10 corresponds to D flat in MuseScore's tonal pitch class mapping.
        if (note.tpc === 22)
            note.tpc = 10;
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
                for (var i = 0; i < notes.length; i++)
                    respellCSharpToDb(notes[i]);
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
