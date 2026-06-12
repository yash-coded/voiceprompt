import FluidAudio
import Foundation

/// Local Parakeet TDT v3 transcription via FluidAudio. Models are downloaded
/// on first use (~600MB) and cached for subsequent runs by FluidAudio itself.
actor Transcriber {
    private var manager: AsrManager?

    func transcribe(_ samples: [Float]) async throws -> String {
        let manager = try await loadedManager()
        var decoderState = try TdtDecoderState()
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadedManager() async throws -> AsrManager {
        if let manager { return manager }
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.manager = manager
        return manager
    }
}
