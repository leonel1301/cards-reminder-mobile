import SwiftUI
import UniformTypeIdentifiers

struct ContractAnalyzeView: View {
    @State private var contractsService = ContractsAPIService()
    @State private var isImporterPresented = false
    @State private var importerError: String?

    @State private var selectedFileName = ""
    @State private var selectedFileData: Data?
    @State private var selectedMimeType = "application/octet-stream"

    private var hasFile: Bool {
        selectedFileData != nil && !selectedFileName.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                dropCard
                analyzeCard
                resultSection
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle("contract_title")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleImporter(result)
        }
        .apiErrorAlert()
        .task {
            await contractsService.fetchUsage()
        }
    }

    private var usageLine: String {
        if contractsService.hasReachedLimit {
            return String(localized: "contract_limit_reached")
        }
        return String(
            format: String(localized: "contract_usage_remaining"),
            contractsService.remainingAnalyses,
            contractsService.usage?.limit ?? ContractUsage.betaLimit
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.primaryAction)
                Text("contract_powered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primaryAction.opacity(0.12))
            .clipShape(Capsule())

            Text("contract_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(usageLine)
                .font(.caption.weight(.semibold))
                .foregroundStyle(contractsService.hasReachedLimit ? Color.redStateForeground : .secondary)
        }
    }

    private var dropCard: some View {
        VStack(spacing: 14) {
            Image(systemName: hasFile ? "doc.fill" : "doc.badge.plus")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.primaryAction)

            Text(hasFile ? selectedFileName : String(localized: "contract_empty_file"))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text("contract_formats")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                isImporterPresented = true
            } label: {
                Text(hasFile ? "contract_replace" : "contract_choose_file")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(Color.primaryAction)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if let importerError {
                Text(importerError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .sectionCard(cornerRadius: 20)
    }

    private var analyzeCard: some View {
        let canAnalyze = hasFile && !contractsService.hasReachedLimit
        return Button {
            guard canAnalyze else { return }
            Haptics.lightImpact()
            Task { await analyze() }
        } label: {
            HStack(spacing: 8) {
                if contractsService.isAnalyzing {
                    ProgressView()
                        .tint(canAnalyze ? .white : .secondary)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(analyzeButtonTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(canAnalyze ? Color.white : Color.secondary)
            .background(canAnalyze ? Color.primaryAction : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canAnalyze || contractsService.isAnalyzing)
    }

    private var analyzeButtonTitle: LocalizedStringKey {
        if contractsService.hasReachedLimit {
            return "contract_limit_reached_short"
        }
        return contractsService.isAnalyzing ? "contract_analyzing" : "contract_analyze"
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("contract_result_title")
                .font(.headline)

            if let errorMessage = contractsService.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if contractsService.isAnalyzing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("contract_analyzing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let extraction = contractsService.extraction {
                extractionContent(extraction)
            } else {
                Text("contract_result_idle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sectionCard(cornerRadius: 16)
    }

    @ViewBuilder
    private func extractionContent(_ extraction: ContractExtraction) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            resultBlock(title: "contract_field_summary", value: extraction.summary)

            resultRow(title: "field_card_name", value: extraction.name)
            resultRow(title: "field_last_four_digits", value: extraction.lastFourDigits)
            resultRow(title: "contract_field_issuer", value: extraction.issuer)
            resultRow(
                title: "picker_billing_cycle_day",
                value: dayValue(extraction.billingCycleDay)
            )
            resultRow(
                title: "picker_payment_due_day",
                value: dayValue(extraction.paymentDueDay)
            )
            resultRow(title: "contract_field_annual_fee", value: extraction.annualFee)
            resultRow(title: "contract_field_interest", value: extraction.interestRateSummary)
            resultRow(title: "contract_field_notes", value: extraction.notes)

            resultRow(
                title: "contract_field_confidence",
                value: confidenceLabel(extraction.confidence)
            )

            if !extraction.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("contract_field_warnings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(extraction.warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(warning)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func resultBlock(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultRow(title: LocalizedStringKey, value: String?) -> some View {
        let display = displayValue(value)
        return HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(display)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func displayValue(_ value: String?) -> String {
        guard let value else { return String(localized: "contract_missing_value") }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "contract_missing_value") : trimmed
    }

    private func dayValue(_ day: Int?) -> String? {
        guard let day else { return nil }
        return String(format: String(localized: "contract_day_of_month"), day)
    }

    private func confidenceLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "high":
            return String(localized: "contract_confidence_high")
        case "medium":
            return String(localized: "contract_confidence_medium")
        case "low":
            return String(localized: "contract_confidence_low")
        default:
            return raw
        }
    }

    private func analyze() async {
        guard let data = selectedFileData else { return }
        _ = await contractsService.analyzeContract(
            fileData: data,
            fileName: selectedFileName,
            mimeType: selectedMimeType
        )
    }

    private func handleImporter(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard data.count <= 10 * 1024 * 1024 else {
                    importerError = String(localized: "contract_file_too_large")
                    return
                }

                importerError = nil
                selectedFileData = data
                selectedFileName = url.lastPathComponent
                selectedMimeType = ContractsAPIService.mimeType(for: url)
                contractsService.clearResult()
            } catch {
                importerError = String(localized: "contract_import_error")
            }

        case .failure:
            importerError = String(localized: "contract_import_error")
        }
    }
}

#Preview {
    NavigationStack {
        ContractAnalyzeView()
    }
}
