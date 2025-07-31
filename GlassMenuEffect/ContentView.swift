//
//  ContentView.swift
//  GlassMenuEffect
//
//  Created by Balaji Venkatesh on 28/07/25.
//

import SwiftUI

enum Position: String, CaseIterable {
    case topLeading = "T-Left"
    case topTrailing = "T-Right"
    case bottomLeading = "B-Left"
    case bottomTrailing = "B-Right"
    
    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }
}

enum AnimationType: String, CaseIterable {
    case bouncy = "Bouncy"
    case smooth = "Smooth"
    case snappy = "Snappy"
    
    var value: Animation {
        switch self {
        case .bouncy: .bouncy(duration: 0.7, extraBounce: 0.01)
        case .smooth: .smooth(duration: 0.55, extraBounce: 0.05)
        case .snappy: .snappy(duration: 0.55, extraBounce: 0.05)
        }
    }
}

struct ContentView: View {
    @State private var progress: CGFloat = 0
    @State private var position: Position = .bottomTrailing
    @State private var animation: AnimationType = .smooth
    var body: some View {
        List {
            Section("Preview") {
                Rectangle()
                    .foregroundStyle(.clear)
                    .background {
                        Image(.BG)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .contentShape(.rect)
                            .onTapGesture {
                                withAnimation(animation.value) {
                                    progress = 0
                                }
                            }
                    }
                    .overlay {
                        ExpandableGlassMenu(alignment: position.alignment, progress: progress) {
                            VStack(alignment: .leading, spacing: 12) {
                                RowView("paperplane", "Send")
                                RowView("arrow.trianglehead.2.counterclockwise", "Swap")
                                RowView("arrow.down", "Receive")
                            }
                            .padding(10)
                        } label: {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.title3)
                                .frame(width: 55, height: 55)
                                .contentShape(.rect)
                                .onTapGesture {
                                    withAnimation(animation.value) {
                                        progress = 1
                                    }
                                }
                        }
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: position.alignment
                        )
                        .padding(15)
                    }
                    .frame(height: 330)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            Section("Properties") {
                Slider(value: $progress)
                
                Picker("", selection: $position) {
                    ForEach(Position.allCases, id: \.rawValue) {
                        Text($0.rawValue)
                            .tag($0)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("", selection: $animation) {
                    ForEach(AnimationType.allCases, id: \.rawValue) {
                        Text($0.rawValue)
                            .tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    /// Dummy Row Content View
    @ViewBuilder
    func RowView(_ image: String, _ title: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: image)
                .font(.title3)
                .symbolVariant(.fill)
                .frame(width: 45, height: 45)
                .background(.background, in: .circle)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .fontWeight(.semibold)
                
                Text("This is a sample text description")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .contentShape(.rect)
    }
}

#Preview {
    ContentView()
}

struct ExpandableGlassMenu<Content: View, Label: View>: View, Animatable {
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    /// View Properties
    @State private var contentSize: CGSize = .zero
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        GlassEffectContainer {
            let widthDiff = contentSize.width - labelSize.width
            let heightDiff = contentSize.height - labelSize.height
            
            let rWidth = widthDiff * contentOpacity
            let rHeight = heightDiff * contentOpacity
            
            ZStack(alignment: alignment) {
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .onGeometryChange(for: CGSize.self) {
                        $0.size
                    } action: { newValue in
                        contentSize = newValue
                    }
                    .fixedSize()
                    .frame(
                        width: labelSize.width + rWidth,
                        height: labelSize.height + rHeight
                    )
                
                label
                    .compositingGroup()
                    .blur(radius: 14 * blurProgress)
                    .opacity(1 - labelOpacity)
                    .frame(width: labelSize.width, height: labelSize.height)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: cornerRadius))
            /// OPTIONAL: You can add property to make it clear glass effect!
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
        .scaleEffect(
            x: 1 - (blurProgress * 0.35),
            y: 1 + (blurProgress * 0.45),
            anchor: scaleAnchor
        )
        .offset(y: offset * blurProgress)
    }
    
    var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }
    
    var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }
    
    var contentScale: CGFloat {
        let minAspectScale = min(labelSize.width / contentSize.width, labelSize.height / contentSize.height)
        
        return minAspectScale + (1 - minAspectScale) * progress
    }
    
    var blurProgress: CGFloat {
        /// 0 -> 0.5 -> 0
        return progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }
    
    var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing: return -80
        case .top, .topLeading, .topTrailing: return 80
        /// Center!
        default: return 0
        }
    }
    
    /// Converting Alignment into UnitPoint for ScaleEffect
    var scaleAnchor: UnitPoint {
        switch alignment {
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}
