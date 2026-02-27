//
//  MetalView.swift
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 22/02/2026.
//

import SwiftUI
import MetalKit

// MTKView subclass that forwards keyboard and mouse events to Input.shared
class InputMTKView: MTKView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        Input.shared.keyDown(event: event)
    }

    override func keyUp(with event: NSEvent) {
        Input.shared.keyUp(event: event)
    }

    override func mouseMoved(with event: NSEvent) {
        Input.shared.mouseMoved(event: event, in: self)
    }

    override func mouseDragged(with event: NSEvent) {
        Input.shared.mouseMoved(event: event, in: self)
    }

    override func rightMouseDragged(with event: NSEvent) {
        Input.shared.mouseMoved(event: event, in: self)
    }

    override func mouseDown(with event: NSEvent) {
        Input.shared.mouseDown(event: event)
    }

    override func mouseUp(with event: NSEvent) {
        Input.shared.mouseUp(event: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        Input.shared.mouseDown(event: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        Input.shared.mouseUp(event: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self
        ))
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

struct MetalView : NSViewRepresentable {
    public typealias NSViewType = InputMTKView
    public var delegate: MetalViewDelegate?

    public init(delegate: MetalViewDelegate) {
        self.delegate = delegate
    }

    public func makeNSView(context: Context) -> InputMTKView {
        return InputMTKView()
    }

    public func updateNSView(_ view: InputMTKView, context: Context) {
        delegate?.configure(view)
    }
}
