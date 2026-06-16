import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var trimmer = AudioTrimmer()
    @State private var waveformPeaks: [Float] = []
    
    // File Importer & Exporter States
    @State private var isFileImporterPresented = false
    @State private var isFileExporterPresented = false
    @State private var tempExportURL: URL? = nil
    
    // Alerts and messages
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        ZStack {
            // Background Theme
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            // Faint background light glow for premium feel
            VStack {
                HStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 250, height: 250)
                        .blur(radius: 80)
                }
            }
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Title
                    HeaderView()
                    
                    if trimmer.sourceURL == nil {
                        // File Selector Dropzone
                        EmptyStateView(action: { isFileImporterPresented = true })
                    } else {
                        // Main Audio Interface
                        VStack(spacing: 20) {
                            
                            // Audio Details
                            AudioInfoCard(
                                fileName: trimmer.fileName,
                                fileExt: trimmer.originalExtension,
                                duration: trimmer.totalDuration
                            )
                            
                            // Interactive Waveform Chart
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WAVEFORM TIMELINE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 5)
                                
                                AudioWaveformView(
                                    peaks: waveformPeaks,
                                    duration: trimmer.totalDuration,
                                    startTime: $trimmer.startTime,
                                    endTime: $trimmer.endTime,
                                    playbackProgress: trimmer.playbackProgress,
                                    isPlaying: trimmer.isPlaying
                                )
                                
                                // Time indicators under waveform
                                HStack {
                                    Text("0.0s")
                                    Spacer()
                                    Text(String(format: "%.1fs", trimmer.playbackProgress))
                                        .foregroundColor(.cyan)
                                        .fontWeight(.semibold)
                                        .opacity(trimmer.isPlaying ? 1.0 : 0.0)
                                    Spacer()
                                    Text(String(format: "%.1fs", trimmer.totalDuration))
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                            }
                            .padding(.vertical, 10)
                            
                            // Playback controls row
                            PlaybackControlsView(trimmer: trimmer)
                            
                            // Trimming Interval Settings
                            IntervalSettingsCard(trimmer: trimmer)
                            
                            // Volume Fades configuration card
                            FadesSettingsCard(trimmer: trimmer)
                            
                            // Destination Settings (File name & location option)
                            DestinationSettingsCard(trimmer: trimmer)
                            
                            // Trim Action Button
                            Button(action: handleTrimAction) {
                                Text("Trim & Export Audio")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        LinearGradient(
                                            colors: [.indigo, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                    .shadow(color: Color.indigo.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .padding(.top, 10)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            
            // Full Screen Exporting Progress HUD Overlay
            if trimmer.isExporting {
                ExportingProgressOverlay(progress: trimmer.exportProgress)
            }
        }
        // File pick modifier
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                trimmer.loadAudio(from: selectedURL) { peaks in
                    self.waveformPeaks = peaks
                }
            case .failure(let error):
                showNotice(title: "Import Failed", message: error.localizedDescription)
            }
        }
        // File export modifier
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: tempExportURL.map { AudioDocument(fileURL: $0) },
            contentType: .audio,
            defaultFilename: trimmer.outputFileName
        ) { result in
            switch result {
            case .success(let url):
                showNotice(title: "Success", message: "Audio file exported successfully to: \(url.lastPathComponent)")
            case .failure(let error):
                showNotice(title: "Export Error", message: error.localizedDescription)
            }
            // Clear temp URL
            tempExportURL = nil
        }
        // Handle changes in trimmer export success/error states
        .onReceive(trimmer.$exportSuccessURL) { successURL in
            if let successURL = successURL {
                showNotice(title: "Success", message: "Trimmed file saved to: \(successURL.path)")
                trimmer.exportSuccessURL = nil
            }
        }
        .onReceive(trimmer.$exportError) { errorMsg in
            if let errorMsg = errorMsg {
                showNotice(title: "Export Failed", message: errorMsg)
                trimmer.exportError = nil
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func handleTrimAction() {
        trimmer.trimAndExport { localTempURL in
            self.tempExportURL = localTempURL
            self.isFileExporterPresented = true
        }
    }
    
    private func showNotice(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// Wrapper to comply with SwiftUI Document Picker / File Exporter protocol
struct AudioDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.audio] }
    var fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        self.fileURL = URL(fileURLWithPath: "")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: fileURL, options: .immediate)
    }
}

// MARK: - Subviews

struct HeaderView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cutty")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .tracking(-1)
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .purple, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                Text("Native Audio Trimmer")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }
}

struct EmptyStateView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 110, height: 110)
                
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
                    )
            }
            
            VStack(spacing: 8) {
                Text("Select an Audio File")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Supports MP3, WAV, M4A, AAC, and other formats.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Button(action: action) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Browse Files")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: Color.indigo.opacity(0.25), radius: 5, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 40)
    }
}

struct AudioInfoCard: View {
    let fileName: String
    let fileExt: String
    let duration: Double
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundColor(.indigo)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(fileExt.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f seconds", duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

struct PlaybackControlsView: View {
    @ObservedObject var trimmer: AudioTrimmer
    
    var body: some View {
        HStack(spacing: 24) {
            // Stop button
            Button(action: trimmer.stopPlayback) {
                Image(systemName: "square.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 50, height: 50)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            
            // Play/Pause middle button
            Button(action: trimmer.togglePlayback) {
                Image(systemName: trimmer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.indigo.opacity(0.2), radius: 6, x: 0, y: 3)
            }
            
            // Browse other button
            Button(action: trimmer.stopPlayback) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 50, height: 50)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .opacity(0.0) // Kept for symmetry
            .disabled(true)
        }
    }
}

struct IntervalSettingsCard: View {
    @ObservedObject var trimmer: AudioTrimmer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRIM RANGE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            // Start time input
            VStack(spacing: 6) {
                HStack {
                    Text("Start Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    TimeInputView(value: $trimmer.startTime, maxValue: trimmer.totalDuration)
                }
                Slider(value: $trimmer.startTime, in: 0...max(0.1, trimmer.endTime - 0.5))
                    .tint(.indigo)
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // End time input
            VStack(spacing: 6) {
                HStack {
                    Text("End Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    TimeInputView(value: $trimmer.endTime, maxValue: trimmer.totalDuration)
                }
                Slider(value: $trimmer.endTime, in: max(0.1, trimmer.startTime + 0.5)...trimmer.totalDuration)
                    .tint(.purple)
            }
            
            HStack {
                Text("Total Trimmed Duration:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f seconds", max(0.0, trimmer.endTime - trimmer.startTime)))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

struct TimeInputView: View {
    @Binding var value: Double
    let maxValue: Double
    
    var body: some View {
        HStack(spacing: 8) {
            // Decrement button
            Button(action: { value = max(0.0, value - 0.5) }) {
                Image(systemName: "minus")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
            }
            
            // Text presentation
            Text(String(format: "%.1f s", value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .center)
            
            // Increment button
            Button(action: { value = min(maxValue, value + 0.5) }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
            }
        }
    }
}

struct FadesSettingsCard: View {
    @ObservedObject var trimmer: AudioTrimmer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("VOLUME FADES")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            // Fade In Controls
            VStack(spacing: 10) {
                Toggle(isOn: $trimmer.isFadeInEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fade In")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if trimmer.isFadeInEnabled {
                            Text("Gradually increases volume at start")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.indigo)
                
                if trimmer.isFadeInEnabled {
                    HStack(spacing: 12) {
                        Slider(value: $trimmer.fadeInDuration, in: 0.5...10.0, step: 0.5)
                            .tint(.indigo)
                        Text(String(format: "%.1fs", trimmer.fadeInDuration))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .transition(.opacity)
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Fade Out Controls
            VStack(spacing: 10) {
                Toggle(isOn: $trimmer.isFadeOutEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fade Out")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if trimmer.isFadeOutEnabled {
                            Text("Gradually decreases volume at end")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.purple)
                
                if trimmer.isFadeOutEnabled {
                    HStack(spacing: 12) {
                        Slider(value: $trimmer.fadeOutDuration, in: 0.5...10.0, step: 0.5)
                            .tint(.purple)
                        Text(String(format: "%.1fs", trimmer.fadeOutDuration))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: trimmer.isFadeInEnabled)
        .animation(.easeInOut(duration: 0.2), value: trimmer.isFadeOutEnabled)
    }
}

struct DestinationSettingsCard: View {
    @ObservedObject var trimmer: AudioTrimmer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("EXPORT CONFIGURATION")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            // File Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Filename")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Output File Name", text: $trimmer.outputFileName)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                    
                    Text(".m4a")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Save location toggle
            Toggle(isOn: $trimmer.saveInOriginalFolder) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save in Original Folder")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(trimmer.saveInOriginalFolder ? "Tries to place file in same folder" : "Launches folder picker on completion")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.indigo)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

struct ExportingProgressOverlay: View {
    let progress: Float
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .indigo))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("Trimming Audio...")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(String(format: "%.0f%% Completed", progress * 100))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(32)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
        }
    }
}
