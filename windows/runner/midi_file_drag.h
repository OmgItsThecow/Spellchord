#ifndef RUNNER_MIDI_FILE_DRAG_H_
#define RUNNER_MIDI_FILE_DRAG_H_

#include <string>

// Initiates a native Windows OLE file drag-and-drop operation for the file at
// |utf8_path| (e.g. a temporary .mid file) so it can be dropped directly into
// Ableton Live or any Windows DAW. Returns true if the drop succeeded.
bool StartWindowsFileDrag(const std::string& utf8_path);

#endif  // RUNNER_MIDI_FILE_DRAG_H_
