import AppKit

import Kingfisher
private let iconResizer = ResizingImageProcessor(referenceSize: CGSize(width: 60, height: 60), mode: .aspectFill)
class StatusCell: NSView {
  let iconView = NSImageView()
  let textLabel = NSTextField()
  var status: Status? {
    willSet {
      iconView.kf.cancelDownloadTask()
    }
    didSet {
      if let avatarURL = (status.flatMap {URL(string: $0.account.avatar)}) {
        iconView.kf.setImage(
          with: avatarURL,
          //          placeholder: stubIcon,
          options: [.scaleFactor(2), .processor(iconResizer)],
          progressBlock: nil,
          completionHandler: nil)
      }
      textLabel.stringValue = "\(status?.account.displayName ?? ""): \(status?.textContent ?? "")".trimmingCharacters(in: CharacterSet.newlines)
    }
  }

  init() {
    super.init(frame: .zero)
    wantsLayer = true
    layer?.isOpaque = true
    layer?.backgroundColor = .black
    iconView.wantsLayer = true
    iconView.layer?.masksToBounds = true
    iconView.layer?.cornerRadius = 4
//    textLabel.wantsLayer = true
    textLabel.font = .systemFont(ofSize: 16)
    textLabel.textColor = .white
//    textLabel.layer?.isOpaque = true
//    textLabel.layer?.backgroundColor = .black
//    textLabel.drawsBackground = true

    let views: [String: NSView] = ["icon": iconView, "text": textLabel]
    views.values.forEach { v in
      v.translatesAutoresizingMaskIntoConstraints = false
      addSubview(v)
    }
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[icon(==30)][text]|", options: [], metrics: nil, views: views))
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[icon(==30)]|", options: [], metrics: nil, views: views))
    addConstraint(NSLayoutConstraint(item: textLabel, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0))
  }
  required init?(coder: NSCoder) {fatalError()}
}

@available(OSX 10.12.2, *)
class DonDon: NSResponder, NSTouchBarDelegate, NSApplicationDelegate {
  let accessToken: String
  init(accessToken: String) {
    self.accessToken = accessToken
    super.init()
  }
  required init?(coder: NSCoder) {fatalError("init(coder:) has not been implemented")}

  lazy var touchbar: NSTouchBar = {
    let tb = NSTouchBar()
    tb.delegate = self
    tb.defaultItemIdentifiers = [NSTouchBarItemIdentifier(rawValue: "test")]
    return tb
  }()

  override func makeTouchBar() -> NSTouchBar? {
    return touchbar
  }

  var statusCells = (0..<5).map {_ in StatusCell()}
  var statusRingBufferIndex = 0

  func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItemIdentifier) -> NSTouchBarItem? {
    let item = NSCustomTouchBarItem(identifier: identifier)
    item.view = NSView(frame: NSRect(x: 0, y: 0, width: 1280, height: 30))
    statusCells.forEach { cell in
      cell.frame = item.view.bounds
      item.view.addSubview(cell)
    }
    return item
  }

  private var statuses: [Status] = []
  private func append(_ s: Status) {
    let cell = statusCells[statusRingBufferIndex]
    statusRingBufferIndex = (statusRingBufferIndex + 1) % statusCells.count

    cell.status = s
    cell.layer?.zPosition = CGFloat(Date().timeIntervalSince1970)

    let animation = CABasicAnimation(keyPath: "position")
    animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
    animation.duration = 2
    animation.fromValue = NSPoint(x: cell.superview?.bounds.maxX ?? 0, y: 0)
    animation.toValue = NSPoint(x: 0, y: 0)
    cell.layer?.add(animation, forKey: "position")
  }

  var eventSource: EventSource?
  func applicationDidFinishLaunching(_ notification: Notification) {
//    append(Status(account: Account(username: "test", displayName: "name", avatar: "https://localhost/"), content: "hoge"))
//    return

    let es = EventSource(url: "https://" + "imastodon.net" + "/api/v1/streaming/public/local", headers:["Authorization": "Bearer \(accessToken)"])
    es.onError { [weak es] e in
      NSLog("%@", "onError: \(String(describing: e))")
      es?.invalidate()
    }
    es.addEventListener("update") { [weak self] id, event, data in
      do {
        let j = try JSONSerialization.jsonObject(with: data?.data(using: .utf8) ?? Data())
        let status = try Status.decodeValue(j)
        DispatchQueue.main.async {
          NSLog("%@", "EventSource event update: \(status)")
          self?.append(status)
        }
      } catch {
        DispatchQueue.main.async {
          NSLog("%@", "EventSource event update, failed to parse with error \(error): \(String(describing: id)), \(String(describing: event)), \(String(describing: data))")
        }
      }
    }
    self.eventSource = es
  }
}

import Himotoki
struct Status {
  public let account: Account
  public let content: String
}
extension Status: Decodable {
  static func decode(_ e: Extractor) throws -> Status {
    return try Status(
      account: e <| "account",
      content: e <| "content")
  }
}
extension Status {
  var textContent: String {
    return attributedTextContent?.string ?? content
  }

  var attributedTextContent: NSAttributedString? {
    guard let data = ("<style>body{font-size: 16px;} p {margin:0;padding:0;display:inline;}</style>" + content).data(using: .utf8),
      let at = try? NSMutableAttributedString(
        data: data,
        options: [
          NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
          NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue],
        documentAttributes: nil) else { return nil }
    return at
  }
}

public struct Account {
  let username: String
  let displayName: String
  let avatar: String
}
extension Account: Decodable {
  public static func decode(_ e: Extractor) throws -> Account {
    return try Account(
      username: e <| "username",
      displayName: e <| "display_name",
      avatar: e <| "avatar")
  }
}


func runTouchBar<D: NSTouchBarDelegate & NSApplicationDelegate>(_ dondon: D) {
  let app = NSApplication.shared()
  app.setActivationPolicy(.regular)
  app.delegate = dondon
  app.run()
}

guard CommandLine.arguments.count > 1 else {
  print("Usage: imastodondon access_token")
  exit(1)
}
let accessToken = CommandLine.arguments[1]

if #available(OSX 10.12.2, *) {
  runTouchBar(DonDon(accessToken: accessToken))
}
