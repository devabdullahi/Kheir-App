import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// The long-press view of an athan notification: a paper card with the sky of that
/// prayer, its time, the call to prayer and paper bars moving while the athan plays.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var host: UIHostingController<AthanCard>?

    func didReceive(_ notification: UNNotification) {
        let info = notification.request.content.userInfo
        let prayer = info["prayer"] as? String ?? notification.request.content.title
        let time = (info["time"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? notification.date
        let card = AthanCard(prayer: prayer, time: time)
        if let host {
            host.rootView = card
        } else {
            let host = UIHostingController(rootView: card)
            host.view.backgroundColor = .clear
            addChild(host)
            host.view.frame = view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(host.view)
            host.didMove(toParent: self)
            self.host = host
        }
        preferredContentSize = CGSize(width: view.bounds.width, height: view.bounds.width * 0.92)
    }
}
