import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins/"
    description: qsTr("Pour chaque accord, orthographie chaque note par rapport à la basse avec la distance de TPC minimale.")
    version: "1.3.0"
    requiresScore: true

    function respellNotesRelativeToBass(notes) {
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

    function applyKeySignatureAdjustment(notes, keySignature) {
        if (!notes.length)
            return;

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
        var TpcAdjust = 2;
        var keyTpc = 16 + keySignature/TpcAdjust;
		
        var difference = keyTpc - averageTpc;


        var adjustment = Math.round(difference / 12) * 12;
        if (!adjustment)
            return;

        for (var j = 0; j < notes.length; j++)
            notes[j].tpc += adjustment;
    }

    function processChord(notes, keySignature) {
        respellNotesRelativeToBass(notes);
        applyKeySignatureAdjustment(notes, keySignature);
    }

function processSelection() {
    var sel = curScore.selection;
    var elems = sel ? sel.elements : null;

    // 1) Pas de sélection => ne rien faire
    if (!elems || elems.length === 0) {
        return;
    }

    // 2) Range selection => start/end ticks fiables
    if (sel.isRange) {
        processRangeSelection(sel.startSegment.tick, sel.endSegment.tick);
        return;
    }

    // 3) List selection => itérer les éléments sélectionnés
    processListSelection(elems);
}


function processRangeSelection(startTick, endTick) {
    var cursor = curScore.newCursor();
    cursor.rewind(Cursor.SELECTION_START);

    while (cursor.segment && cursor.tick < endTick) {
        if (cursor.element && cursor.element.type === Element.CHORD)
            processChord(cursor.element.notes, cursor.keySignature);
        cursor.next();
    }
}

function processListSelection(elements) {
    // On veut traiter des CHORDs, même si l’utilisateur a sélectionné des NOTEheads, etc.
    var cursor = curScore.newCursor();

    var seen = {}; // dédoublonnage
    for (var i = 0; i < elements.length; i++) {
        var e = elements[i];
        if (!e) continue;

        var chord = null;

        if (e.type === Element.CHORD) {
            chord = e;
        } else if (e.type === Element.NOTE) {
            chord = e.parent; // une NOTE appartient à un CHORD
        } else {
            continue;
        }

        if (!chord) continue;

        // Clé de dédoublonnage : tick + track (suffisant en pratique)
        var key = chord.tick + ":" + chord.track;
        if (seen[key]) continue;
        seen[key] = true;

        // Récupérer la tonalité (keySignature) de façon sûre au tick du chord
        cursor.track = chord.track;
        cursor.rewindToTick(chord.tick);

        processChord(chord.notes, cursor.keySignature);
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
