import Foundation
import CoreML
import CoreImage
import Vision
import AppKit

class UpscaleManager {
    static let shared = UpscaleManager()
    private var model: MLModel?
    private let context = CIContext()
    
    private init() {
        do {
            // Load the GFPGAN model
            let config = MLModelConfiguration()
            config.computeUnits = .all // Use all available compute units
            let modelUrl = Bundle.main.url(forResource: "gfpgan", withExtension: "mlmodelc")!
            model = try MLModel(contentsOf: modelUrl, configuration: config)
        } catch {
            print("Error loading model: \(error.localizedDescription)")
        }
    }
    
    func upscaleImage(_ image: NSImage) async throws -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw UpscaleError.invalidImage
        }
        
        guard let model = model else {
            throw UpscaleError.modelError
        }
        
        // Create Vision model
        let vnModel = try VNCoreMLModel(for: model)
        
        // Create and configure request
        let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
            if let error = error {
                print("Vision request error: \(error.localizedDescription)")
                return
            }
        }
        request.imageCropAndScaleOption = .scaleFit
        
        // Create request handler and perform request
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        
        // Get result image
        guard let results = request.results as? [VNPixelBufferObservation],
              let pixelBuffer = results.first?.pixelBuffer else {
            throw UpscaleError.processingError
        }
        
        // Convert pixel buffer to CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert CIImage to CGImage
        guard let outputCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw UpscaleError.processingError
        }
        
        // Create final NSImage
        let size = NSSize(width: outputCGImage.width, height: outputCGImage.height)
        let outputImage = NSImage(size: size)
        outputImage.lockFocus()
        NSGraphicsContext.current?.cgContext.draw(outputCGImage, in: NSRect(origin: .zero, size: size))
        outputImage.unlockFocus()
        
        return outputImage
    }
}

enum UpscaleError: Error {
    case invalidImage
    case modelError
    case processingError
} 