import Foundation

final class InstallState {
    private let installMarkerKey = "install_marker"

    func isFreshInstall() -> Bool {
        let defaults = UserDefaults.standard

        if defaults.string(forKey: installMarkerKey) == nil {
            defaults.set(UUID().uuidString, forKey: installMarkerKey)
            return true
        }

        return false
    }
}
