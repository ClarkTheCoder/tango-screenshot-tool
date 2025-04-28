import AppKit

class SelectionView: NSView {
    
    var onSelectionComplete: ((CGRect) -> Void)?
    
    private var startPoint: CGPoint?
    private var endPoint: CGPoint?
    
    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        endPoint = startPoint
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        endPoint = event.locationInWindow
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        endPoint = event.locationInWindow
        needsDisplay = true
        
        if let start = startPoint, let end = endPoint {
            let localRect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            
            if let window = self.window, let screen = window.screen {
                let screenHeight = screen.frame.height
                let globalRect = CGRect(
                    x: window.frame.origin.x + localRect.origin.x,
                    y: window.frame.origin.y + (screenHeight - localRect.origin.y - localRect.height),
                    width: localRect.width,
                    height: localRect.height
                )
                
                onSelectionComplete?(globalRect)
            }
        }
        
        window?.orderOut(nil)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        
        if let start = startPoint, let end = endPoint {
            let selectionRect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            
            NSColor.clear.setFill()
            NSBezierPath(rect: selectionRect).fill()
            
            NSColor.blue.setStroke()
            NSBezierPath(rect: selectionRect).stroke()
        }
    }
}
