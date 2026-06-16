import Foundation
import AVFoundation

enum WaveformRenderer {
    /// Extracts a fixed number of amplitude peaks from an audio file asynchronously.
    /// - Parameters:
    ///   - url: The file URL of the audio resource.
    ///   - targetCount: The number of peaks to extract (default is 100).
    ///   - completion: Callback returns the array of normalized floats [0.0, 1.0].
    static func extractPeaks(from url: URL, targetCount: Int = 100, completion: @escaping ([Float]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Could not access security-scoped resource for waveform generation")
                DispatchQueue.main.async { completion([]) }
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            guard let file = try? AVAudioFile(forReading: url) else {
                print("Error: Failed to open audio file at \(url.path)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let totalFrames = file.length
            guard totalFrames > 0 else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let framesPerWindow = max(1, totalFrames / Int64(targetCount))
            var peaks: [Float] = []
            
            // Set up buffer for window size
            let processingFormat = file.processingFormat
            guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: AVAudioFrameCount(framesPerWindow)) else {
                print("Error: Failed to initialize AVAudioPCMBuffer")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            for i in 0..<targetCount {
                let startFrame = Int64(i) * framesPerWindow
                if startFrame >= totalFrames { break }
                
                file.framePosition = startFrame
                do {
                    try file.read(into: buffer, frameCount: AVAudioFrameCount(framesPerWindow))
                    guard let channelData = buffer.floatChannelData else {
                        peaks.append(0.0)
                        continue
                    }
                    
                    let samples = channelData[0]
                    let frameLength = Int(buffer.frameLength)
                    
                    var maxVal: Float = 0.0
                    // Optimize performance by striding through the window samples
                    let sampleStep = max(1, frameLength / 50)
                    for j in stride(from: 0, to: frameLength, by: sampleStep) {
                        let val = abs(samples[j])
                        if val > maxVal {
                            maxVal = val
                        }
                    }
                    peaks.append(maxVal)
                } catch {
                    peaks.append(0.0)
                }
            }
            
            // Normalize peaks between 0.02 and 1.0 (so bars are always slightly visible)
            if let maxPeak = peaks.max(), maxPeak > 0 {
                peaks = peaks.map { max(0.02, $0 / maxPeak) }
            } else {
                peaks = Array(repeating: 0.05, count: targetCount)
            }
            
            DispatchQueue.main.async {
                completion(peaks)
            }
        }
    }
}
