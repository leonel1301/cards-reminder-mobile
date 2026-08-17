import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class ContractsAPIService {
    var isAnalyzing = false
    var isLoadingUsage = false
    var errorMessage: String?
    var extraction: ContractExtraction?
    var usage: ContractUsage?

    private let api = APIService.shared
    private let maxFileBytes = 10 * 1024 * 1024

    var remainingAnalyses: Int {
        usage?.remaining ?? ContractUsage.betaLimit
    }

    var hasReachedLimit: Bool {
        remainingAnalyses <= 0
    }

    func fetchUsage() async {
        isLoadingUsage = true
        defer { isLoadingUsage = false }

        do {
            let response: ContractUsage = try await api.request(path: "/me/contracts/usage")
            usage = response
        } catch {
            // Keep a conservative default so the button stays usable offline;
            // the analyze call still enforces the server limit.
            if usage == nil {
                usage = ContractUsage(used: 0, limit: ContractUsage.betaLimit, remaining: ContractUsage.betaLimit)
            }
            APIErrorHandling.handle(error) { errorMessage = $0 }
        }
    }

    @discardableResult
    func analyzeContract(
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async -> ContractExtraction? {
        guard fileData.count <= maxFileBytes else {
            errorMessage = String(localized: "contract_file_too_large")
            return nil
        }

        if hasReachedLimit {
            errorMessage = String(localized: "contract_limit_reached")
            return nil
        }

        isAnalyzing = true
        errorMessage = nil
        extraction = nil
        defer { isAnalyzing = false }

        do {
            let result: ContractExtraction = try await api.uploadMultipart(
                path: "/contracts/analyze",
                fieldName: "file",
                fileName: fileName,
                mimeType: mimeType,
                fileData: fileData
            )
            withAnimation(SmoothRevealAnimation.motion) {
                extraction = result
            }
            await fetchUsage()
            return result
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            await fetchUsage()
            return nil
        }
    }

    func clearResult() {
        extraction = nil
        errorMessage = nil
    }

    static func mimeType(for fileURL: URL) -> String {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }

        switch fileURL.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        case "webp":
            return "image/webp"
        default:
            return "application/octet-stream"
        }
    }
}
