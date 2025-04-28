import AppKit

class ScreenCaptureOverlay: NSWindow {
    
    private var selectionView: SelectionView!
    
    init() {
        let screenRect = NSScreen.main?.frame ?? .zero
        
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .statusBar
        self.ignoresMouseEvents = false
        self.makeKeyAndOrderFront(nil)
        
        selectionView = SelectionView(frame: screenRect)
        self.contentView = selectionView
    }
    
    func onSelectionComplete(_ handler: @escaping (CGRect) -> Void) {
        selectionView.onSelectionComplete = handler
    }
}
