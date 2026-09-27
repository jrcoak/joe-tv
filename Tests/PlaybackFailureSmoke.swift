import AVFoundation
import Foundation

private final class CyclicNSError: NSError, @unchecked Sendable {
    override var userInfo: [String: Any] {
        [
            NSUnderlyingErrorKey: self,
            NSLocalizedDescriptionKey: "https://secret.example/live.m3u8?token=do-not-log"
        ]
    }
}

@main
private enum PlaybackFailureSmoke {
    private static var checks = 0

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError(message) }
    }

    private static func classify(
        domain: String,
        code: Int,
        underlying: NSError? = nil,
        log: PlaybackFailureLogEvidence? = nil
    ) -> PlaybackFailurePresentation {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "https://secret.example/live.m3u8?hmac=never-print",
            "headers": ["Cookie": "session=never-print"],
            "body": "license-payload-never-print"
        ]
        if let underlying { userInfo[NSUnderlyingErrorKey] = underlying }
        return PlaybackFailureClassifier.classify(
            error: NSError(domain: domain, code: code, userInfo: userInfo),
            latestErrorLog: log
        )
    }

    private static func checkSanitized(
        _ presentation: PlaybackFailurePresentation,
        _ context: String
    ) {
        let output = presentation.message + " " + presentation.supportCode
        for forbidden in ["secret.example", "hmac", "never-print", "Cookie", "license-payload", "evil.example"] {
            check(!output.contains(forbidden), "\(context) leaked \(forbidden)")
        }
        check(presentation.supportCode.count <= 32, "\(context) support code was not compact")
    }

    static func main() {
        let offline = classify(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
        check(offline.cause == .network, "Offline URL error did not identify network failure")
        check(offline.supportCode == "P-URLN1009", "Offline URL support code changed")
        checkSanitized(offline, "Offline URL")

        let timeout = classify(domain: NSURLErrorDomain, code: URLError.timedOut.rawValue)
        check(timeout.cause == .timeout, "URL timeout did not identify timeout")
        check(timeout.message.contains("timed out"), "URL timeout lacked a friendly cause")

        let format = classify(domain: AVFoundationErrorDomain, code: -11828)
        check(format.cause == .format, "AVFoundation format error was not classified")
        check(format.supportCode == "P-AVFN11828", "AVFoundation support code changed")

        let protected = classify(domain: AVFoundationErrorDomain, code: -11831)
        check(protected.cause == .protectedContent, "Protected-content error was not classified")

        let coreMedia = classify(domain: "CoreMediaErrorDomain", code: -12642)
        check(coreMedia.cause == .media, "CoreMedia error was not classified")
        check(coreMedia.supportCode == "P-CMN12642", "CoreMedia support code changed")

        let osStatus = classify(domain: NSOSStatusErrorDomain, code: -42668)
        check(osStatus.cause == .unknown, "Unknown OSStatus invented a cause")
        check(osStatus.supportCode == "P-OSN42668", "OSStatus support code changed")

        let forbidden = classify(
            domain: "https://evil.example/raw-domain?hmac=never-print",
            code: Int.max,
            log: PlaybackFailureLogEvidence(
                errorDomain: "HTTP",
                errorCode: 403
            )
        )
        check(forbidden.cause == .authorization, "HTTP 403 did not identify authorization failure")
        check(forbidden.supportCode == "P-HTTP403", "Arbitrary domains entered support code")
        checkSanitized(forbidden, "Malicious strings")

        let loggedHTTP = classify(
            domain: AVFoundationErrorDomain,
            code: -11850,
            log: PlaybackFailureLogEvidence(
                errorDomain: "CoreMediaErrorDomain",
                errorCode: -12660
            )
        )
        check(loggedHTTP.cause == .service, "Root AVFoundation server failure was not retained")
        check(loggedHTTP.supportCode == "P-AVFN11850-CMN12660", "Error-log evidence was not bounded")
        checkSanitized(loggedHTTP, "CoreMedia error log")

        let prioritizedHTTP = classify(
            domain: AVFoundationErrorDomain,
            code: -11850,
            log: PlaybackFailureLogEvidence(errorDomain: "HTTPErrorDomain", errorCode: 403)
        )
        check(prioritizedHTTP.cause == .authorization, "HTTP evidence did not outrank generic server failure")
        check(prioritizedHTTP.supportCode == "P-AVFN11850-HTTP403", "HTTP support evidence changed")

        let wrappedHTTP = NSError(
            domain: AVFoundationErrorDomain,
            code: AVError.Code.unknown.rawValue,
            userInfo: [
                NSUnderlyingErrorKey: NSError(domain: "CoreMediaErrorDomain", code: -12642)
            ]
        )
        let retainedLatestLog = PlaybackFailureClassifier.classify(
            error: wrappedHTTP,
            latestErrorLog: PlaybackFailureLogEvidence(errorDomain: "HTTP", errorCode: 403)
        )
        check(retainedLatestLog.cause == .authorization, "Wrapped HTTP evidence lost its cause")
        check(
            retainedLatestLog.supportCode == "P-AVFN11800-HTTP403",
            "Latest error-log evidence was dropped after two wrapper errors"
        )

        let wrappedOffline = NSError(
            domain: AVFoundationErrorDomain,
            code: AVError.Code.unknown.rawValue,
            userInfo: [
                NSUnderlyingErrorKey: NSError(
                    domain: "CoreMediaErrorDomain",
                    code: -12642,
                    userInfo: [
                        NSUnderlyingErrorKey: NSError(
                            domain: NSURLErrorDomain,
                            code: URLError.notConnectedToInternet.rawValue
                        )
                    ]
                )
            ]
        )
        let retainedNestedURL = PlaybackFailureClassifier.classify(error: wrappedOffline)
        check(retainedNestedURL.cause == .network, "Generic CoreMedia wrapper hid nested URL cause")
        check(
            retainedNestedURL.supportCode == "P-AVFN11800-URLN1009",
            "Specific nested URL evidence was dropped from compact support code"
        )

        let nestedURL = NSError(domain: NSURLErrorDomain, code: URLError.cannotConnectToHost.rawValue)
        let nested = classify(domain: "arbitrary-root", code: 9, underlying: nestedURL)
        check(nested.cause == .network, "Known nested URL error was not classified")
        check(nested.supportCode == "P-URLN1004", "Unknown root contaminated nested support code")
        checkSanitized(nested, "Nested URL")

        var tooDeep = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
        for depth in 0..<4 {
            tooDeep = NSError(
                domain: "untrusted-depth-\(depth)",
                code: depth,
                userInfo: [NSUnderlyingErrorKey: tooDeep]
            )
        }
        let bounded = PlaybackFailureClassifier.classify(error: tooDeep)
        check(bounded.cause == .unknown, "Classifier exceeded its error-chain depth bound")
        check(bounded.supportCode == "P-UNKNOWN", "Deep untrusted chain entered support code")
        checkSanitized(bounded, "Deep chain")

        let cyclic = PlaybackFailureClassifier.classify(
            error: CyclicNSError(domain: NSURLErrorDomain, code: URLError.networkConnectionLost.rawValue)
        )
        check(cyclic.cause == .network, "Cyclic error lost its known root cause")
        check(cyclic.supportCode == "P-URLN1005", "Cyclic chain duplicated support evidence")
        checkSanitized(cyclic, "Cyclic chain")

        let hugeCode = PlaybackFailureClassifier.classify(
            error: NSError(domain: AVFoundationErrorDomain, code: Int.max)
        )
        check(hugeCode.supportCode == "P-AVFX", "Unbounded numeric code entered support output")
        checkSanitized(hugeCode, "Huge numeric code")

        let fallback = PlaybackFailureClassifier.classify(
            error: nil,
            fallbackDomain: NSURLErrorDomain,
            fallbackCode: URLError.secureConnectionFailed.rawValue
        )
        check(fallback.cause == .secureConnection, "Sanitized observer fallback was ignored")
        check(fallback.supportCode == "P-URLN1200", "Observer fallback support code changed")

        let unknown = PlaybackFailureClassifier.classify(
            error: NSError(
                domain: "untrusted https://evil.example",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "token=never-print"]
            )
        )
        check(unknown.cause == .unknown, "Unknown domain invented a friendly cause")
        check(unknown.message == "This stream could not be played.", "Unknown failure changed generic copy")
        check(unknown.supportCode == "P-UNKNOWN", "Unknown failure exposed raw evidence")
        checkSanitized(unknown, "Unknown error")

        print("Playback failure smoke passed (\(checks) checks)")
    }
}
