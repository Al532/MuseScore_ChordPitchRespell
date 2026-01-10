import QtQuick 2.0
import MuseScore 3.0

/**
 * CHORD PITCH RESPELL
 * =======================================
 * 
 * MuseScore plugin for intelligent enharmonic respelling of MIDI-entered chords,
 * preserving chord quality.
 * 
 * ALGORITHMIC PRINCIPLE:
 * ----------------------
 * The algorithm operates in 2 main phases:
 *
 * PHASE 1: Internal Harmonic Respelling
 *   1. Calculate Tonal Pitch Class (TPC) residues for all notes (modulo 12)
 *   2. Find the optimal arc on the circle of fifths containing all residues,
 *      balancing window span and a penalty for homonyms (e.g. G and G#)
 *      within the candidate chord
 *   3. Assign concrete TPC values within the optimal window
 *
 * PHASE 2: Contextual Adjustment
 *   4. Shift entire chord by multiples of 12 to align with key signature
 * 
 * TPC Reference: https://musescore.github.io/MuseScore_PluginAPI_Docs/plugins/html/tpc.html
 * 
 * RECOMMENDED USAGE:
 * ------------------
 * - Select a range to process one or multiple chords
 * - Also processes isolated notes (key signature adjustment only)
 * 
 */
MuseScore {
    description: qsTr("Enharmonic respelling tool optimized for MIDI-entered chords, preserving chord quality and respecting the current key signature. Best results are achieved when applied to a range selection, allowing chord-level logic to be applied.")
    version: "1.4.0"
    requiresScore: true

    /**
     * PHASE 1: INTERNAL HARMONIC RESPELLING
     * ======================================
     * 
     * This function implements steps 1-3 of the algorithm to achieve
     * harmonic coherence within a chord, independent of key signature.
     * 
     * Algorithm steps:
     * 1. Calculate TPC residue classes (modulo 12) for each note
     * 2. Score circular windows by span plus a configurable homonym penalty
     *    (TPC distance of 7) for every homonym pair inside the candidate window
     * 3. Assign concrete TPC values within the optimal window
     * 
     * @param {Array} notes - Array of Note objects in the chord
     */
    function respellNotes(notes) {
        // Validation: a chord requires at least 2 notes
        if (!notes || notes.length < 2) {
            console.log("respellNotes: skipping because chord has less than two notes");
            return;
        }

        console.log("respellNotes: processing", notes.length, "notes");

        // =====================================================================
        // LOOKUP TABLE: Pitch Class → TPC (Tonal Pitch Class)
        // =====================================================================
        // TPC encodes position on the circle of fifths:
        // - TPC 14 = C natural (center reference)
        // - TPC increases by 7 per ascending fifth (14→21=G, 21→28=D...)
        // - Each MIDI pitch class (0-11) has multiple enharmonic representations
        //
        // Example for pitch class 0 (C/B#/Dbb):
        // - TPC 2  = Dbb (double flat)
        // - TPC 14 = C (natural)
        // - TPC 26 = B# (sharp)
        var pitchClassToTpcs = {
            0: [2, 14, 26],    // C / B# / Dbb
            1: [9, 21, 33],    // C# / Db / B##
            2: [4, 16, 28],    // D / C## / Ebb
            3: [-1, 11, 23],   // Eb / D# / Fbb
            4: [6, 18, 30],    // E / D## / Fb
            5: [1, 13, 25],    // F / E# / Gbb
            6: [8, 20, 32],    // F# / Gb / E##
            7: [3, 15, 27],    // G / F## / Abb
            8: [10, 22],       // G# / Ab
            9: [5, 17, 29],    // A / G## / Bbb
            10: [0, 12, 24],   // Bb / A# / Cbb
            11: [7, 19, 31]    // B / A## / Cb
        };

        /**
         * Mathematically correct modulo 12 (handles negatives)
         */
        function mod12(x) {
            var r = x % 12;
            return r < 0 ? r + 12 : r;
        }

        // =====================================================================
        // STEP 1: CALCULATE TPC RESIDUE CLASSES (modulo 12)
        // =====================================================================
        // Each note is reduced to its residue class on the circle of fifths
        // (values 0-11), independent of the chosen enharmonic spelling.
        // All enharmonic equivalents of a pitch share the same residue class.
        var residues = [];
        for (var i = 0; i < notes.length; i++) {
            var pcs = mod12(notes[i].pitch);
            // Take the first candidate TPC and reduce mod 12
            // (all candidates of the same pitch class have the same residue class)
            residues.push(mod12(pitchClassToTpcs[pcs][0]));
        }

        console.log("respellNotes: residue classes", residues);

        // =====================================================================
        // STEP 2: FIND THE OPTIMAL ARC ON THE CIRCLE OF FIFTHS
        // =====================================================================
        // Score each candidate window on the circular residue space (0-11)
        // by combining the raw span with a penalty for homonym pairs inside
        // the window. This favors compact windows while discouraging spellings
        // that create visually ambiguous homonyms.
        //
        // Technique: sliding window on circular space using duplication
        
        // Sort residue classes (keeping duplicates for counting)
        var s = residues.slice().sort(function(a,b){ return a-b; });
        console.log("respellNotes: sorted residue classes", s);

        // Circular extension: duplicate and shift by 12 to handle wrap-around
        // Example: [1, 5, 10] becomes [1, 5, 10, 13, 17, 22]
        var t = s.slice();
        for (var k = 0; k < s.length; k++)
            t.push(s[k] + 12);
        console.log("respellNotes: extended for circular wrapping", t);

        // Exhaustive search: test all windows of size n
        var n = s.length;

        // Configuration: weight homonym penalties when scoring windows.
        // Tunable so advanced users can calibrate the trade-off between
        // compact spans and avoiding homonym clashes.
        var HomonymPenalty = 4;

        /**
         * Count pairs of homonyms (TPC difference = 7)
         */
        function countHomonyms(values) {
            var count = 0;
            for (var i = 0; i < values.length; i++) {
                for (var j = i + 1; j < values.length; j++) {
                    if (values[j] - values[i] === 7)
                        count++;
                }
            }
            return count;
        }

        var bestSpan = Infinity;
        var bestScore = Infinity;
        var chosenWindow = null;
        var bestHomonyms = 0;

        for (var startIdx = 0; startIdx < n; startIdx++) {
            // Span = arc width (difference between last and first element)
            var span = t[startIdx + n - 1] - t[startIdx];
            var windowStart = t[startIdx];
            var windowEnd = windowStart + span;
            var windowValues = t.slice(startIdx, startIdx + n);
            var homonymPairs = countHomonyms(windowValues);
            var windowScore = span + homonymPairs * HomonymPenalty;

            console.log(
                "respellNotes: window", startIdx,
                "start", windowStart,
                "end", windowEnd,
                "span", span,
                "homonym pairs", homonymPairs,
                "score", windowScore,
                windowScore < bestScore ? "< current best" : (windowScore === bestScore ? "= current best" : "> current best")
            );

            // Prefer lower scores only.
            if (windowScore < bestScore) {
                bestSpan = span;
                bestScore = windowScore;
                chosenWindow = {
                    startIdx: startIdx,
                    windowStart: windowStart,
                    windowEnd: windowEnd,
                    values: windowValues
                };
                bestHomonyms = homonymPairs;
                console.log("respellNotes: new leading window at index", startIdx, "with span", bestSpan, "homonym pairs", bestHomonyms, "score", bestScore);
            }
        }

        var start = chosenWindow.windowStart;
        var end   = chosenWindow.windowEnd;

        console.log("respellNotes: optimal window", start, "to", end, "(span", bestSpan, "homonym pairs", bestHomonyms, "score", bestScore, ")");

        // =====================================================================
        // STEP 3: ASSIGN CONCRETE TPC VALUES
        // =====================================================================
        // Apply the harmonic structure decided in steps 2-3 by selecting the
        // enharmonic candidate that falls within the optimal window.

        // Project a TPC x into window [lo, hi] via ±12 translation
        function liftIntoWindow(x, lo, hi) {
            // Calculate the shift of 12 needed to fit into [lo, hi]
            var y = x + 12 * Math.floor((lo - x) / 12);
            if (y < lo) y += 12;
            if (y > hi) y -= 12; // Safety check (shouldn't happen with window ≤ 11)
            return y;
        }

        function setNoteTpcs(note, tpc) {
            var dtpc = note.tpc2 - note.tpc1;
            note.tpc1 = tpc;
            note.tpc2 = tpc + dtpc;
        }

        // Assignment for each note
        for (i = 0; i < notes.length; i++) {
            var note = notes[i];
            var candidates = pitchClassToTpcs[mod12(note.pitch)];

            var chosen = candidates[0];

            // Find the candidate that falls within the window
            // Since window span ≤ 11 and candidates are 12 apart, only one can fit
            for (k = 0; k < candidates.length; k++) {
                var c = candidates[k];
                var cIn = liftIntoWindow(c, start, end);

                if (cIn >= start && cIn <= end) {
                    chosen = cIn;
                    break;
                }
            }

            setNoteTpcs(note, chosen);
            console.log("respellNotes: note", i, "pitch", note.pitch, "assigned TPC", chosen, "(candidates", candidates, ")");
        }
    }


    /**
     * PHASE 2: CONTEXTUAL ADJUSTMENT TO KEY SIGNATURE
     * ================================================
     * 
     * After internal harmonic respelling (Phase 1), shift the entire chord
     * by multiples of 12 (complete enharmonic cycles: C# ↔ Db, etc.) to
     * align with the tonal context defined by the key signature.
     * 
     * ADJUSTMENT PARAMETER (TpcAdjust):
     * ---------------------------------
     * Controls the strength of key signature influence:
     * - TpcAdjust = 1: strict alignment (may create double accidentals)
     * - TpcAdjust = 2 (default): balanced compromise avoiding extreme accidentals
     * - Other values between 1 and +inf could be tested
     * 
     * FORMULA EXPLANATION:
     * --------------------
     * keyTpc = 16 + keySignature / TpcAdjust
     * 
     * - Base TPC 16 (central value of TPC space)
     * - keySignature ranges from -7 (flats) to +7 (sharps)
     * - Division by TpcAdjust moderates the key signature's pull
     *
	 * Examples:
     * - C major (keySig = 2), TpcAdjust = 2: target TPC = 16 + 0/2 = 16
     * - Gb major (keySig = -6), TpcAdjust = 2: target TPC = 16 - 6/2 = 13
     * 
     * @param {Array} notes - Chord notes
     * @param {Number} keySignature - Key signature (-7 to +7, 0 = C major/A minor)
     */
    function applyKeySignatureAdjustment(notes, keySignature) {
        if (!notes.length) {
            console.log("applyKeySignatureAdjustment: no notes provided");
            return;
        }

        // Calculate the TPC center of the chord (min/max average)
        var minTpc = notes[0].tpc1;
        var maxTpc = notes[0].tpc1;

        for (var i = 1; i < notes.length; i++) {
            var tpc = notes[i].tpc1;
            if (tpc < minTpc)
                minTpc = tpc;
            if (tpc > maxTpc)
                maxTpc = tpc;
        }
        var averageTpc = (minTpc + maxTpc) / 2;

        console.log("applyKeySignatureAdjustment: keySignature", keySignature, "minTpc", minTpc, "maxTpc", maxTpc, "avg", averageTpc);
        
        // Adjustment weight configuration
        // TpcAdjust = 2 provides balanced results for most use cases
        var TpcAdjust = 2;
        
        // Calculate target TPC based on key signature
        // Base 16 (D natural) ± weighted key signature influence
        var keyTpc = 16 + keySignature / TpcAdjust;

        var difference = averageTpc - keyTpc;

        // Round to nearest enharmonic translation (multiple of 12).
        // Favor flats in case of a tie.
        var adjustment;
        if (difference === 6) {
            adjustment = -12;
        } else if (difference === -6) {
            adjustment = 0;
        } else {
            adjustment = - Math.round(difference / 12) * 12;
        }
        if (!adjustment) {
            console.log("applyKeySignatureAdjustment: no adjustment needed");
            return;
        }

        // Apply translation to entire chord (preserves internal relationships)
        for (var j = 0; j < notes.length; j++) {
            var dtpc = notes[j].tpc2 - notes[j].tpc1;
            notes[j].tpc1 += adjustment;
            notes[j].tpc2 = notes[j].tpc1 + dtpc;
        }
        console.log("applyKeySignatureAdjustment: applied adjustment", adjustment);
    }

    /**
     * COMPLETE CHORD PROCESSING
     * =========================
     * 
     * Orchestrates the complete 2-phase algorithm:
     * 
     * Phase 1: Internal harmonic respelling (steps 1-3)
     *          - Analyzes chord structure
     *          - Finds optimal enharmonic spellings
     *          - Balances compact spans with homonym avoidance
     * 
     * Phase 2: Contextual adjustment (step 5)
     *          - Aligns result with key signature
     *          - Preserves Phase 1 relationships
     * 
     * @param {Array} notes - Chord notes
     * @param {Number} keySignature - Key signature
     */
    function processChord(notes, keySignature) {
        console.log("processChord: starting with", notes.length, "notes and key signature", keySignature);
        respellNotes(notes);                            // Phase 1: steps 1-3
        applyKeySignatureAdjustment(notes, keySignature); // Phase 2: step 4
        console.log("processChord: finished");
    }

    /**
     * ENTRY POINT: SELECTION PROCESSING
     * ==================================
     * 
     * Handles two types of MuseScore selections:
     * - Range selection: processes all chords in the area (RECOMMENDED)
     * - List selection: processes individually selected notes (limited)
     */
    function processSelection() {
        var sel = curScore.selection;
        var elems = sel ? sel.elements : null;

        // Case 1: No selection
        if (!elems || elems.length === 0) {
            console.log("processSelection: no selection, exiting");
            return;
        }

        // Case 2: Range selection (RECOMMENDED for best results)
        if (sel.isRange) {
            console.log("processSelection: processing range selection");
            var endTick = sel.endSegment ? sel.endSegment.tick : null;
            if (endTick === null) {
                if (curScore.lastSegment) {
                    endTick = curScore.lastSegment.tick;
                } else {
                    endTick = sel.startSegment.tick;
                }
                console.log("processSelection: end segment missing, using endTick", endTick);
            }
            processRangeSelection(sel.startSegment.tick, endTick);
            return;
        }

        // Case 3: List selection (limited functionality)
        console.log("processSelection: processing list selection");
        processListSelection(elems);
    }

    /**
     * RANGE SELECTION PROCESSING
     * ===========================
     * 
     * Sequentially walks through all musical segments in the range
     * and applies complete respelling (both phases) to each chord encountered.
     * 
     * @param {Number} startTick - Start tick
     * @param {Number} endTick - End tick
     */
    function processRangeSelection(startTick, endTick) {
        var cursor = curScore.newCursor();
        cursor.rewind(Cursor.SELECTION_START);

        console.log("processRangeSelection: from", startTick, "to", endTick);

        // Iterate over all segments in the range
        while (cursor.segment && cursor.tick < endTick) {
            if (cursor.element && cursor.element.type === Element.CHORD) {
                console.log("processRangeSelection: processing chord at tick", cursor.tick, "track", cursor.track);
                processChord(cursor.element.notes, cursor.keySignature);
            }
            cursor.next();
        }
    }

    /**
     * LIST SELECTION PROCESSING
     * ==========================
     * 
     * Applies only Phase 2 (contextual adjustment) to individual notes.
     * 
     * LIMITATION: Cannot apply Phase 1 (harmonic respelling) because
     * chord context is lost when notes are selected individually.
     * 
     * @param {Array} elements - Selected elements
     */
    function processListSelection(elements) {
        var cursor = curScore.newCursor();
        var seenNotes = {}; // Cache to avoid duplicates

        console.log("processListSelection: processing", elements.length, "elements");

        for (var i = 0; i < elements.length; i++) {
            var e = elements[i];
            if (!e) continue;

            // Filter non-note elements
            if (e.type !== Element.NOTE)
                continue;

            var chord = e.parent;
            if (!chord) continue;

            // Avoid processing the same note multiple times
            var noteKey = chord.tick + ":" + chord.track + ":" + e.pitch;
            if (seenNotes[noteKey]) continue;
            seenNotes[noteKey] = true;

            // Apply only Phase 2 (contextual adjustment)
            cursor.track = chord.track;
            cursor.rewindToTick(chord.tick);
            applyKeySignatureAdjustment([e], cursor.keySignature);
        }
    }

    /**
     * EXECUTION TRIGGER
     * =================
     * 
     * Main entry point called by MuseScore.
     */
    onRun: {
        if (!curScore) {
            console.log("onRun: no score open, quitting");
            Qt.quit();
            return;
        }

        console.log("onRun: starting respell process");
        
        // Wrap modifications in an atomic command (undo/redo)
        curScore.startCmd();
        processSelection();
        curScore.endCmd();
        
        console.log("onRun: finished respell process");
        Qt.quit();
    }
}
