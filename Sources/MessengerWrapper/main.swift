import AppKit

let app: NSApplication = NSApplication.shared
// NSApplication.delegate is weak; this top-level constant keeps the delegate alive.
let appDelegate: AppDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.run()
