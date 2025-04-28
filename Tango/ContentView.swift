import SwiftUI
import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var capturedImage: NSImage? = nil
    @State private var isCapturing = false
    @State private var isFullScreenCapture = false
    @State private var stream: SCStream? = nil
    @State private var output: MyStreamOutput? = nil
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                VStack {
                    VStack {
                        if let image = capturedImage {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    maxWidth: isFullScreenCapture ? .infinity : 600,
                                    maxHeight: isFullScreenCapture ? .infinity : 400
                                )
                                .transition(.opacity)
                                .padding()
                        } else {
                            Text("No screenshot captured yet.")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                Divider()
                
                HStack(spacing: 20) {
                    Button("Capture Full Screen") {
                        captureScreen()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isCapturing)
                    
                    Button("Capture Selected Area") {
                        launchOverlayAndCapture()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isCapturing)
                    
                    Button("Save Image") {
                        saveCapturedImage()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(capturedImage == nil)
                    
                    Button("Reset") {
                        withAnimation {
                            capturedImage = nil
                            isFullScreenCapture = false
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(capturedImage == nil)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }
    
    func captureScreen() {
        isCapturing = true
        isFullScreenCapture = true
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    print("No displays found")
                    isCapturing = false
                    return
                }
                
                let config = SCStreamConfiguration()
                config.width = display.width
                config.height = display.height
                config.pixelFormat = kCVPixelFormatType_32BGRA
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                let myOutput = MyStreamOutput { pixelBuffer in
                    if let pixelBuffer = pixelBuffer {
                        capturedImage = nsImage(from: pixelBuffer)
                    }
                    
                    Task {
                        do {
                            try await stream?.stopCapture()
                        } catch {
                            print("Failed to stop capture: \(error)")
                        }
                        stream = nil
                        output = nil
                        isCapturing = false
                    }
                }
                
                output = myOutput
                stream = SCStream(filter: filter, configuration: config, delegate: myOutput)
                try stream?.addStreamOutput(myOutput, type: .screen, sampleHandlerQueue: DispatchQueue.main)
                try await stream?.startCapture()
                
            } catch {
                print("Failed to capture screen: \(error)")
                isCapturing = false
            }
        }
    }
    
    func launchOverlayAndCapture() {
        let overlay = ScreenCaptureOverlay()
        
        overlay.onSelectionComplete { rect in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                captureScreenPortion(rect: rect)
            }
        }
    }
    
    func captureScreenPortion(rect: CGRect) {
        isFullScreenCapture = false
        
        if let cgImage = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]) {
            capturedImage = NSImage(cgImage: cgImage, size: rect.size)
        } else {
            print("Failed to capture selected area")
        }
    }
    
    func saveCapturedImage() {
        guard let image = capturedImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Screenshot.png"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
    
    func nsImage(from pixelBuffer: CVPixelBuffer) -> NSImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

// MARK: - SCStreamOutput Delegate
class MyStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    var frameHandler: (CVPixelBuffer?) -> Void
    private var didCapture = false

    init(frameHandler: @escaping (CVPixelBuffer?) -> Void) {
        self.frameHandler = frameHandler
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard !didCapture else { return }
        
        if let pixelBuffer = sampleBuffer.imageBuffer {
            didCapture = true
            frameHandler(pixelBuffer)
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(minWidth: 120)
            .background(configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(minWidth: 100)
            .background(configuration.isPressed ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3))
            .foregroundColor(.black)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
