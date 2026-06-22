import UIKit

enum DeviceInfo {
    static var feedbackDescription: String {
        "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
    }
}
