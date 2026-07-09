#if canImport(UIKit)
import UIKit
import WebKit

/// WKWebView that suppresses the iOS keyboard's form input-accessory bar — the
/// toolbar (previous/next field chevrons + "Done") WebKit shows above the
/// software keyboard. The flow focuses one field at a time, so the chevrons are
/// inert and "Done" only duplicates the keyboard's own return/send key; hiding
/// the bar keeps the edge-to-edge, no-native-chrome look.
///
/// That bar is the `inputAccessoryView` of WebKit's internal content view (the
/// actual first responder), not of `WKWebView`, so setting `inputAccessoryView`
/// here has no effect. Instead we swap the live content view's class for a
/// runtime-generated subclass whose `inputAccessoryView` getter returns nil.
///
/// The swap is scoped to this instance's content view via `object_setClass` — we
/// never swizzle the shared `WKContentView` class, so a host app's other web
/// views keep their accessory bars. No private symbol is referenced by name; the
/// target class is derived from the live subview.
final class SentinelWebView: WKWebView {
    private var accessoryBarRemoved = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !accessoryBarRemoved else { return }
        if removeInputAccessoryBar() {
            accessoryBarRemoved = true
        }
    }

    @discardableResult
    private func removeInputAccessoryBar() -> Bool {
        // WebKit's content view lives inside the scroll view; match by class-name
        // prefix rather than a hard-coded private class reference.
        guard let contentView = scrollView.subviews.first(where: {
            String(describing: type(of: $0)).hasPrefix("WKContent")
        }) else { return false }

        let targetClass: AnyClass = type(of: contentView)
        let newClassName = "\(NSStringFromClass(targetClass))_NoInputAccessory"

        let newClass: AnyClass
        if let existing = NSClassFromString(newClassName) {
            newClass = existing
        } else {
            guard let name = newClassName.cString(using: .ascii),
                let created = objc_allocateClassPair(targetClass, name, 0)
            else { return false }
            // Override -inputAccessoryView to return nil for this content view.
            let selector = #selector(getter: UIResponder.inputAccessoryView)
            let block: @convention(block) (Any) -> UIView? = { _ in nil }
            let imp = imp_implementationWithBlock(block)
            // "@@:" — returns id (the view), takes self (@) and _cmd (:).
            class_addMethod(created, selector, imp, "@@:")
            objc_registerClassPair(created)
            newClass = created
        }

        object_setClass(contentView, newClass)
        // Force the keyboard to re-query the (now nil) accessory view.
        contentView.reloadInputViews()
        return true
    }
}
#endif
