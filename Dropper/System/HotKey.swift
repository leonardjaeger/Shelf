import Carbon.HIToolbox
import Foundation

/// Systemweites Tastenkürzel über die Carbon-API.
/// Funktioniert ohne Freigabe unter „Bedienungshilfen“ und auch, wenn Dropper nicht aktiv ist.
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    private var reference: EventHotKeyRef?
    private let identifier: UInt32

    /// - Parameters:
    ///   - keyCode: virtueller Tastencode, z. B. `kVK_ANSI_P`
    ///   - modifiers: Carbon-Modifier, z. B. `optionKey | shiftKey`
    ///   - identifier: eindeutige Nummer je Tastenkürzel
    /// - Returns: `nil`, wenn das Kürzel schon von einer anderen App belegt ist.
    init?(keyCode: Int, modifiers: Int, identifier: UInt32, handler: @escaping () -> Void) {
        self.identifier = identifier
        HotKey.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: HotKey.signature, id: identifier)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        reference = ref
        HotKey.handlers[identifier] = handler
    }

    deinit {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        HotKey.handlers[identifier] = nil
    }

    /// Vier Zeichen „DRPR“ als Kennung dieser App.
    private static let signature: OSType = {
        "DRPR".utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }()

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            if status == noErr, let handler = HotKey.handlers[hotKeyID.id] {
                DispatchQueue.main.async { handler() }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
