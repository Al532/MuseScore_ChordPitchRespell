from __future__ import annotations

from dataclasses import dataclass
from typing import List

PITCH_CLASS_TO_TPCS = {
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
    11: [7, 19, 31],
}

LETTER_INDEXES = {"C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6}
NATURAL_PITCH_CLASSES = [0, 2, 4, 5, 7, 9, 11]


@dataclass
class Note:
    name: str
    pitch: int
    tpc: int


def tpc_to_pitch_class(tpc: int) -> int:
    return ((tpc - 14) * 7) % 12


def tpc_to_letter_index(tpc: int) -> int:
    return (4 * (tpc - 14)) % 7


def note_name_from_tpc(tpc: int) -> str:
    letter_index = tpc_to_letter_index(tpc)
    pitch_class = tpc_to_pitch_class(tpc)
    natural_pc = NATURAL_PITCH_CLASSES[letter_index]

    diff = pitch_class - natural_pc
    while diff > 6:
        diff -= 12
    while diff < -6:
        diff += 12

    accidental = ""
    if diff > 0:
        accidental = "#" * diff
    elif diff < 0:
        accidental = "b" * (-diff)

    letter = list(LETTER_INDEXES.keys())[list(LETTER_INDEXES.values()).index(letter_index)]
    return f"{letter}{accidental}"


def parse_note_name(name: str) -> tuple[int, int]:
    name = name.strip()
    if not name:
        raise ValueError("Empty note name")

    letter = name[0].upper()
    if letter not in LETTER_INDEXES:
        raise ValueError(f"Invalid note letter: {name}")

    accidentals = name[1:]
    sharp_count = accidentals.count("#")
    flat_count = accidentals.count("b")

    if sharp_count + flat_count != len(accidentals):
        raise ValueError(f"Unsupported accidental format: {name}")

    letter_index = LETTER_INDEXES[letter]
    pitch_class = (NATURAL_PITCH_CLASSES[letter_index] + sharp_count - flat_count) % 12

    candidates = PITCH_CLASS_TO_TPCS.get(pitch_class, [])
    for tpc in candidates:
        if tpc_to_letter_index(tpc) == letter_index:
            return pitch_class, tpc

    raise ValueError(f"Could not map note name to TPC: {name}")


def respell_notes_relative_to_bass(notes: List[Note]) -> None:
    if len(notes) < 2:
        return

    bass = min(notes, key=lambda n: n.pitch)

    for note in notes:
        if note is bass:
            continue

        candidates = PITCH_CLASS_TO_TPCS[note.pitch % 12]
        closest = min(candidates, key=lambda t: abs(t - bass.tpc))
        note.tpc = closest


def apply_key_signature_adjustment(notes: List[Note], key_signature: int) -> None:
    if not notes:
        return

    min_tpc = min(n.tpc for n in notes)
    max_tpc = max(n.tpc for n in notes)
    average_tpc = (min_tpc + max_tpc) / 2

    key_tpc = 14 + key_signature
    difference = key_tpc - average_tpc

    if abs(difference) < 12:
        return

    adjustment = round(difference / 12) * 12
    if not adjustment:
        return

    for note in notes:
        note.tpc += adjustment


def process_chord(note_names: List[str], key_signature: int) -> List[str]:
    parsed_notes: List[Note] = []
    for idx, name in enumerate(note_names):
        pitch_class, tpc = parse_note_name(name)
        parsed_notes.append(Note(name=name, pitch=idx * 12 + pitch_class, tpc=tpc))

    respell_notes_relative_to_bass(parsed_notes)
    apply_key_signature_adjustment(parsed_notes, key_signature)

    parsed_notes.sort(key=lambda n: n.pitch)
    return [note_name_from_tpc(n.tpc) for n in parsed_notes]


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Replicate the respellv1 plugin logic.")
    parser.add_argument("key_signature", type=int, help="Key signature value (as in MuseScore).")
    parser.add_argument(
        "notes",
        nargs="+",
        help="Note names from lowest to highest (e.g., Ab C# Eb F A#)",
    )

    args = parser.parse_args()
    result = process_chord(args.notes, args.key_signature)
    print("[" + ", ".join(result) + "]")


if __name__ == "__main__":
    main()
