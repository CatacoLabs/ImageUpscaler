import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @State private var selectedImage: NSImage?
    @State private var upscaledImage: NSImage?
    @State private var isProcessing = false
    @State private var dragOver = false
    @State private var errorMessage: String?
    @State private var scale: Float = 2.0
    
    private let upscaleManager = UpscaleManager.shared
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with settings
            List {
                Section(header: Text("Settings").font(.headline)) {
                    VStack(alignment: .leading) {
                        Text("Scale Factor: \(String(format: "%.1f", scale))x")
                        Slider(value: $scale, in: 1.0...4.0, step: 0.5)
                    }
                }
            }
            .listStyle(SidebarListStyle())
        } detail: {
            VStack {
                if let selectedImage = selectedImage {
                    HStack {
                        VStack {
                            Text("Original")
                                .font(.headline)
                            Image(nsImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                        }
                        
                        if let upscaledImage = upscaledImage {
                            VStack {
                                Text("Upscaled")
                                    .font(.headline)
                                Image(nsImage: upscaledImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 300)

                                .padding(.top)
                            }
                        }
                    }
                    .padding()
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    Button(action: {
                        Task {
                            await upscaleImage()
                        }
                    }) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                        } else {
                            Text("Upscale Image")
                        }
                    }
                    .disabled(isProcessing)
                    .padding()
                } else {
                    // Drop zone for images
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                            .foregroundColor(dragOver ? .blue : .gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                            Text("Drop image here or click to select")
                                .padding(.top)
                        }
                    }
                    .padding()
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, let image = NSImage(contentsOf: url) else { return }
                    DispatchQueue.main.async {
                        self.selectedImage = image
                        self.upscaledImage = nil
                        self.errorMessage = nil
                    }
                }
                return true
            }
            .navigationTitle("Image Upscaler")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: selectImage) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    if let upscaledImage = upscaledImage {
                        Button(action: saveUpscaledImage) {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                    if selectedImage != nil {
                        Button(action: clearImages) {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }
    
    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK {
            if let url = panel.url, let image = NSImage(contentsOf: url) {
                selectedImage = image
                upscaledImage = nil
                errorMessage = nil
            }
        }
    }
    
    func clearImages() {
        selectedImage = nil
        upscaledImage = nil
        errorMessage = nil
    }
    
    func saveUpscaledImage() {
        guard let imageToSave = upscaledImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "upscaled_image"
        
        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            
            // Convert NSImage to PNG or JPEG data
            guard let imageRep = imageToSave.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: imageRep) else { return }
            
            let imageData: Data?
            if url.pathExtension.lowercased() == "png" {
                imageData = bitmap.representation(using: .png, properties: [:])
            } else {
                imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            }
            
            if let imageData = imageData {
                try? imageData.write(to: url)
            }
        }
    }
    
    func upscaleImage() async {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            if let upscaled = try await upscaleManager.upscaleImage(image) {
                upscaledImage = upscaled
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
}

#Preview {
    ContentView()
}
