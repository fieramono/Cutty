import Foundation
import AVFoundation
import Combine

class AudioTrimmer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    // Audio source information
    @Published var sourceURL: URL?
    @Published var totalDuration: TimeInterval = 0.0
    @Published var formatName: String = ""
    @Published var fileName: String = ""
    @Published var originalExtension: String = ""
    
    // Playback state
    @Published var isPlaying = false
    @Published var playbackProgress: TimeInterval = 0.0
    
    // Export state
    @Published var isExporting = false
    @Published var exportProgress: Float = 0.0
    @Published var exportError: String?
    @Published var exportSuccessURL: URL?
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    // Configuration values (bound to UI)
    @Published var startTime: TimeInterval = 0.0
    @Published var endTime: TimeInterval = 60.0
    @Published var isFadeInEnabled = false
    @Published var fadeInDuration: Double = 2.0
    @Published var isFadeOutEnabled = false
    @Published var fadeOutDuration: Double = 2.0
    @Published var outputFileName: String = ""
    @Published var saveInOriginalFolder = true
    
    /// Loads an audio file, analyzes its properties, and triggers waveform peak extraction.
    /// - Parameters:
    ///   - url: The file URL.
    ///   - waveformCompletion: Callback when peaks are calculated.
    func loadAudio(from url: URL, waveformCompletion: @escaping ([Float]) -> Void) {
        stopPlayback()
        
        guard url.startAccessingSecurityScopedResource() else {
            print("Error: Failed to obtain security-scoped URL access for \(url.path)")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        self.sourceURL = url
        self.fileName = url.deletingPathExtension().lastPathComponent
        self.originalExtension = url.pathExtension.lowercased()
        self.outputFileName = "\(fileName)_(demo)"
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            self.audioPlayer = player
            self.totalDuration = player.duration
            self.formatName = url.pathExtension.uppercased()
            
            // Set default boundaries
            self.startTime = 0.0
            self.endTime = min(60.0, player.duration)
            
            // Analyze and generate peaks
            WaveformRenderer.extractPeaks(from: url, targetCount: 100, completion: waveformCompletion)
        } catch {
            print("Error loading audio metadata: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Playback Control
    
    /// Plays the selected audio range, automatically stopping at the specified end time.
    func playSelectedRange() {
        guard let player = audioPlayer, let sourceURL = sourceURL else { return }
        
        stopPlayback()
        
        // Re-open inside security scope for playback
        guard sourceURL.startAccessingSecurityScopedResource() else {
            print("Error: Could not access security resource for playback")
            return
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: sourceURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error initializing audio player: \(error.localizedDescription)")
            return
        }
        
        guard let activePlayer = audioPlayer else { return }
        
        let start = max(0.0, min(startTime, totalDuration))
        let end = max(start + 0.1, min(endTime, totalDuration))
        
        activePlayer.currentTime = start
        activePlayer.play()
        isPlaying = true
        playbackProgress = start
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            
            self.playbackProgress = player.currentTime
            
            if player.currentTime >= end {
                self.stopPlayback()
            }
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            playSelectedRange()
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        playbackProgress = startTime
        playbackTimer?.invalidate()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.stopPlayback()
        }
    }
    
    // MARK: - Audio Trimming & Exporting
    
    /// Clips the source audio, applies fade adjustments, and writes to a temporary file.
    /// If direct write to original directory is unavailable, invokes the fallback closure.
    /// - Parameter fallbackExporter: Callback passing the local temporary URL for user saving.
    func trimAndExport(fallbackExporter: @escaping (URL) -> Void) {
        guard let sourceURL = sourceURL else { return }
        
        stopPlayback()
        
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        exportSuccessURL = nil
        
        let ext = originalExtension
        var finalName = outputFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalName.isEmpty {
            finalName = "\(fileName)_(demo)"
        }
        
        // Default export config: iOS only supports writing audio files as M4A (AAC) natively
        // during transcode/mix operations. If they type another extension, we target .m4a.
        let targetExtension = "m4a"
        let outputFileType = AVFileType.m4a
        let presetName = AVAssetExportPresetAppleM4A
        
        let outputFileNameWithExt = finalName.hasSuffix(".\(targetExtension)") ? finalName : "\(finalName).\(targetExtension)"
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(targetExtension)
        
        guard sourceURL.startAccessingSecurityScopedResource() else {
            self.isExporting = false
            self.exportError = "Access denied: Could not read original file."
            return
        }
        
        let asset = AVURLAsset(url: sourceURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let composition = AVMutableComposition()
        
        guard let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            sourceURL.stopAccessingSecurityScopedResource()
            self.isExporting = false
            self.exportError = "Failed to initialize AVMutableComposition audio track."
            return
        }
        
        guard let assetAudioTrack = asset.tracks(withMediaType: .audio).first else {
            sourceURL.stopAccessingSecurityScopedResource()
            self.isExporting = false
            self.exportError = "Error: Original file has no usable audio channels."
            return
        }
        
        let trimDuration = max(0.1, endTime - startTime)
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let durationCMTime = CMTime(seconds: trimDuration, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, duration: durationCMTime)
        
        do {
            try compositionAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
        } catch {
            sourceURL.stopAccessingSecurityScopedResource()
            self.isExporting = false
            self.exportError = "Failed insertion: \(error.localizedDescription)"
            return
        }
        
        // Audio Mix Settings for Fades
        let audioMix = AVMutableAudioMix()
        let mixParameters = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
        
        // Apply Fade In
        if isFadeInEnabled && fadeInDuration > 0 {
            let fadeTime = min(fadeInDuration, trimDuration)
            let fadeInRange = CMTimeRange(start: .zero, duration: CMTime(seconds: fadeTime, preferredTimescale: 600))
            mixParameters.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 1.0, timeRange: fadeInRange)
        }
        
        // Apply Fade Out
        if isFadeOutEnabled && fadeOutDuration > 0 {
            let fadeTime = min(fadeOutDuration, trimDuration)
            let fadeStart = CMTime(seconds: trimDuration - fadeTime, preferredTimescale: 600)
            let fadeOutRange = CMTimeRange(start: fadeStart, duration: CMTime(seconds: fadeTime, preferredTimescale: 600))
            mixParameters.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: 0.0, timeRange: fadeOutRange)
        }
        
        audioMix.inputParameters = [mixParameters]
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: presetName) else {
            sourceURL.stopAccessingSecurityScopedResource()
            self.isExporting = false
            self.exportError = "Failed to construct AVAssetExportSession."
            return
        }
        
        exportSession.audioMix = audioMix
        exportSession.outputURL = tempFileURL
        exportSession.outputFileType = outputFileType
        
        // Monitor Export progress
        var progressTimer: Timer?
        DispatchQueue.main.async {
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.exportProgress = exportSession.progress
            }
        }
        
        exportSession.exportAsynchronously {
            progressTimer?.invalidate()
            sourceURL.stopAccessingSecurityScopedResource()
            
            DispatchQueue.main.async {
                self.isExporting = false
                
                switch exportSession.status {
                case .completed:
                    self.exportProgress = 1.0
                    self.handleExportCompletion(tempURL: tempFileURL, targetName: outputFileNameWithExt, fallback: fallbackExporter)
                case .failed:
                    self.exportError = exportSession.error?.localizedDescription ?? "Export failed."
                case .cancelled:
                    self.exportError = "Export cancelled."
                default:
                    self.exportError = "An unexpected error occurred during export."
                }
            }
        }
    }
    
    private func handleExportCompletion(tempURL: URL, targetName: String, fallback: @escaping (URL) -> Void) {
        guard let sourceURL = sourceURL else { return }
        
        if saveInOriginalFolder {
            let originalFolder = sourceURL.deletingLastPathComponent()
            let destinationURL = originalFolder.appendingPathComponent(targetName)
            
            // Check direct folder write access
            guard originalFolder.startAccessingSecurityScopedResource() else {
                print("Sandbox alert: Directory write access denied. Invoking fallback exporter.")
                fallback(tempURL)
                return
            }
            defer { originalFolder.stopAccessingSecurityScopedResource() }
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.copyItem(at: tempURL, to: destinationURL)
                self.exportSuccessURL = destinationURL
            } catch {
                print("Directory write failed: \(error.localizedDescription). Invoking fallback exporter.")
                fallback(tempURL)
            }
        } else {
            // Directly launch the document exporter UI
            fallback(tempURL)
        }
    }
}
