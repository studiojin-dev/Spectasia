import SwiftUI

/// Single image viewer with zoom and pan support
public struct SingleImageView: View {
    let imageURL: URL
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isFullscreen = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                // Image with zoom and pan
                ScrollView([.horizontal, .vertical]) {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                        .offset(x: offset.width, y: offset.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Overlay info
                VStack {
                    // Top bar
                    HStack {
                        Button(action: { isFullscreen.toggle() }) {
                            Image(systemName: isFullscreen ? "arrow.down.left.and.arrow.up.right" : "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.white)
                        }

                        Spacer()

                        if !isFullscreen {
                            Text("Single Image")
                                .font(GypsumFont.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()

                    Spacer()

                    // Bottom bar (zoom controls)
                    if !isFullscreen {
                        HStack(spacing: 20) {
                            Button("Fit") {
                                withAnimation {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                            .foregroundColor(.white)

                            Button("100%") {
                                withAnimation {
                                    scale = 1.0
                                }
                            }
                            .foregroundColor(.white)

                            Text("\(Int(scale * 100))%")
                                .foregroundColor(.white)
                        }
                        .padding()
                    }
                }
            }
            .statusBar(hidden: isFullscreen)
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastScale
                    lastScale = value
                    scale = max(0.5, min(scale * delta, 5.0))
                }
                .onEnded { _ in
                    lastScale = 1.0
                }
        )
    }
}

#Preview("Single Image Viewer") {
    SingleImageView(imageURL: URL(fileURLWithPath: "/tmp/test.jpg"))
}
