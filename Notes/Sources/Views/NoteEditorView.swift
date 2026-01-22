import SwiftUI

struct NoteEditorView: View {
    @StateObject private var viewModel: NoteEditorViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(filePath: String, existingNote: Note? = nil) {
        _viewModel = StateObject(wrappedValue: NoteEditorViewModel(filePath: filePath, existingNote: existingNote))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with file info
            headerView
            
            Divider()
            
            // Text editor
            textEditorView
            
            Divider()
            
            // Footer with stats and buttons
            footerView
        }
        .frame(width: 600, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.isNewNote ? "Add Note" : "Edit Note")
                .font(.headline)
            
            HStack {
                Image(systemName: viewModel.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.small)
                
                Text(viewModel.fileName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    viewModel.showFilePicker()
                }) {
                    Text("Change...")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            
            Text(viewModel.filePath)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding()
    }
    
    // MARK: - Text Editor
    
    private var textEditorView: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $viewModel.noteContent)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .padding(8)
            
            if viewModel.noteContent.isEmpty {
                Text("Enter your note here...")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // Stats
            HStack(spacing: 16) {
                Label("\(viewModel.characterCount)", systemImage: "textformat.abc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(viewModel.wordCount)", systemImage: "text.word.spacing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(viewModel.isNewNote ? "Create" : "Save") {
                    viewModel.saveNote()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.noteContent.isEmpty)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    NoteEditorView(filePath: "/Users/test/Documents/example.txt")
}
