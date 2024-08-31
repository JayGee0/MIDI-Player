import pretty_midi
import sys
import math

notes_label = ['C', 'CS', 'D', 'DS', 'E', 'F', 'FS', 'G', 'GS', 'A', 'AS', 'B']
mid2 = pretty_midi.PrettyMIDI(sys.argv[1])

de_chorder = set()
max_duration = 0

for m in mid2.instruments[0].notes:
    max_duration = max(max_duration, m.get_duration())
scale = 1
if max_duration > 15/8:
    scale = (15/8) / max_duration

last_note = 0

for i, m in enumerate(mid2.instruments[0].notes):
    
    if m.start > last_note and not math.isclose(m.start, last_note):
        pause = f"DEFW {min(int(round((m.start-last_note)*scale*8)), 15)<< 8  | (0) << 4 | (0):#0{6}x}"
        if pause != 'DEFW 0x0000':
            print(pause)
    
    max_pitch = m.pitch
    for mv in mid2.instruments[0].notes[(i+1):]:
        if mv.start != m.start:
            break
        max_pitch = max(max_pitch, mv.pitch)
    
    last_note = m.end
    if (m.start, m.end) not in de_chorder:
        print(f"DEFW {min(int(round(m.get_duration()*8)), 15)<< 8  | (max_pitch // 12) << 4 | (max_pitch% 12):#0{6}x}")
        de_chorder.add((m.start, m.end))

print('DEFW 0x0000')