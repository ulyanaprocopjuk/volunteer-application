import CoreText
import Foundation

enum FontRegistrar {
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        let bundles: [Bundle] = [.main, .moduleCandidates]
        let fileNames = [
            "NotoSans-Regular.ttf",
            "NotoSans-Medium.ttf",
            "NotoSans-SemiBold.ttf",
            "NotoSans-Bold.ttf",
            "Kadwa-Regular.ttf",
            "Kadwa-Bold.ttf"
        ]

        for fileName in fileNames {
            if let url = url(for: fileName, bundles: bundles) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    private static func url(for fileName: String, bundles: [Bundle]) -> URL? {
        let nsName = fileName as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension

        for bundle in bundles {
            if let url = bundle.url(forResource: base, withExtension: ext) {
                return url
            }
            if let url = bundle.url(forResource: base, withExtension: ext, subdirectory: "Resources/fonts") {
                return url
            }
            if let url = bundle.url(forResource: base, withExtension: ext, subdirectory: "fonts") {
                return url
            }
        }
        return nil
    }
}

private extension Bundle {
    static var moduleCandidates: Bundle {
        Bundle(for: Marker.self)
    }

    private final class Marker {}
}
