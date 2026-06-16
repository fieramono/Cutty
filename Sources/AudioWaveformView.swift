import SwiftUI

struct AudioWaveformView: View {
    let peaks: [Float]
    let duration: Double
    @Binding var startTime: Double
    @Binding var endTime: Double
    let playbackProgress: Double
    let isPlaying: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Guard against divide-by-zero on empty audio loading
            let totalDuration = max(0.1, duration)
            let startX = CGFloat(startTime / totalDuration) * width
            let endX = CGFloat(endTime / totalDuration) * width
            let progressX = CGFloat(playbackProgress / totalDuration) * width
            
            ZStack(alignment: .leading) {
                // Waveform bars representation
                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<peaks.count, id: \.self) { index in
                        let peak = CGFloat(peaks[index])
                        let timeAtBar = (Double(index) / Double(peaks.count)) * totalDuration
                        let isSelected = timeAtBar >= startTime && timeAtBar <= endTime
                        
                        Capsule()
                            .fill(
                                isSelected ?
                                LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(height: height * peak * 0.95)
                    }
                }
                .frame(width: width, height: height)
                
                // Dark tint on non-selected regions
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: max(0, startX), height: height)
                
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: max(0, width - endX), height: height)
                    .offset(x: endX)
                
                // Playback Position Pointer
                if isPlaying || playbackProgress > 0 {
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 2, height: height)
                        .shadow(color: Color.cyan.opacity(0.8), radius: 4)
                        .offset(x: max(0, min(width - 2, progressX)))
                }
                
                // Selected Border Frame
                Rectangle()
                    .stroke(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 2
                    )
                    .frame(width: max(10, endX - startX), height: height)
                    .offset(x: startX)
                
                // Drag Handle Left (Start Time)
                HandleView()
                    .offset(x: startX - 10, y: (height - 36) / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newX = startX + value.translation.width
                                // Restrict movement so it cannot cross the end handle
                                let newPercent = Double(max(0, min(newX, endX - 15)) / width)
                                self.startTime = newPercent * totalDuration
                            }
                    )
                
                // Drag Handle Right (End Time)
                HandleView()
                    .offset(x: endX - 10, y: (height - 36) / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newX = endX + value.translation.width
                                // Restrict movement so it cannot cross the start handle
                                let newPercent = Double(max(startX + 15, min(newX, width)) / width)
                                self.endTime = newPercent * totalDuration
                            }
                    )
            }
            .contentShape(Rectangle())
        }
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.4))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HandleView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
            .frame(width: 20, height: 36)
            .overlay(
                HStack(spacing: 2) {
                    Rectangle().fill(Color.white.opacity(0.8)).frame(width: 1.5, height: 16)
                    Rectangle().fill(Color.white.opacity(0.8)).frame(width: 1.5, height: 16)
                }
            )
            .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)
    }
}
