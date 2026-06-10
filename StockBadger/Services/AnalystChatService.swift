import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AnalystChatService {
    func streamResponse(to question: String, conversation: [AnalystChatContextMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await streamResponse(
                        to: question,
                        conversation: conversation,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func streamResponse(
        to question: String,
        conversation: [AnalystChatContextMessage],
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
#if canImport(FoundationModels)
        let prompt = Self.prompt(for: question, conversation: conversation)

        do {
            let cloudModel = PrivateCloudComputeLanguageModel()
            if case .available = cloudModel.availability {
                let session = LanguageModelSession(
                    model: cloudModel,
                    instructions: Self.instructions
                )
                let stream = session.streamResponse(to: prompt)
                for try await snapshot in stream {
                    continuation.yield(String(describing: snapshot.content))
                }
                return
            }
        } catch {
            // Private Cloud Compute requires a managed entitlement. Fall through to the on-device model.
        }

        let deviceModel = SystemLanguageModel.default
        guard case .available = deviceModel.availability else {
            throw AnalystChatError.modelUnavailable(Self.unavailableMessage(for: deviceModel.availability))
        }

        let session = LanguageModelSession(
            model: deviceModel,
            instructions: Self.instructions
        )
        let stream = session.streamResponse(to: prompt)
        for try await snapshot in stream {
            continuation.yield(String(describing: snapshot.content))
        }
#else
        throw AnalystChatError.modelUnavailable("Analyst is unavailable because Foundation Models are not available in this build.")
#endif
    }

    private static let instructions = """
    You are Stock Badger Analyst, a professional equity research assistant. Give concise, practical stock-market analysis using the best available information. Focus on business quality, valuation, risk, catalysts, market context, and whether the evidence supports buy, hold, or sell framing.

    Be transparent about data limits. Do not claim you searched the web, read current news, or fetched articles unless that information is explicitly provided by the app. If live news or web context is unavailable, say so briefly and answer from available market data and general analysis principles.

    For questions about a specific individual company or ticker, especially buy/hold/sell or fair-value questions such as "Is NVDA a buy?" or "What is a fair price for NOW?", always end the answer with this exact block:
    --- Final Summary ---
    Current Price: *CURRENT_PRICE*
    Fair Price: *ASSESSED_FAIR_PRICE*
    Suggested Action: *BUY/HOLD/SELL BASED ON CURRENT & FAIR PRICE*

    Replace the placeholders with your best estimates. If current price is not available from the provided app context, write "Unavailable" for Current Price and still provide a clearly-labeled assessed fair price estimate when possible. Suggested Action must be one of BUY, HOLD, or SELL and should be based primarily on the relationship between current price and assessed fair price, adjusted for major business risks.

    Never include the Final Summary block for market indexes, index funds, ETFs, sectors, macro questions, or broad benchmarks such as the S&P 500, Nasdaq, Dow, SPY, QQQ, VOO, IVV, or similar instruments.

    Do not provide personalized financial advice. Avoid guarantees. When useful, structure answers with: summary, key evidence, risks, and what to watch next.
    """

    private static func prompt(for question: String, conversation: [AnalystChatContextMessage]) -> String {
        let recentContext = conversation.suffix(8).map { message in
            "\(message.role): \(message.content)"
        }.joined(separator: "\n")

        return """
        Recent conversation:
        \(recentContext.isEmpty ? "No prior messages." : recentContext)

        User question:
        \(question)
        """
    }

#if canImport(FoundationModels)
    private static func unavailableMessage(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .unavailable(.deviceNotEligible):
            "This device does not support Apple Intelligence. Use an Apple Intelligence-compatible iPhone, iPad, or Mac."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Apple Intelligence is turned off. Enable it in Settings, then reopen Stock Badger."
        case .unavailable(.modelNotReady):
            "The Apple Intelligence model is still downloading or preparing. Keep the device on Wi-Fi and power, then try again later."
        case .unavailable:
            "Apple Intelligence is not available right now. Check device eligibility, region/language settings, and model download status."
        case .available:
            "Apple Intelligence is available, but the analyst model did not respond. Try again."
        @unknown default:
            "Apple Intelligence is not available on this device right now."
        }
    }
#endif
}

enum AnalystChatError: LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let message):
            message
        }
    }
}

struct AnalystChatContextMessage: Hashable {
    let role: String
    let content: String
}
