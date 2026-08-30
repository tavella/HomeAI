import SwiftUI
import UIKit

public struct ChatInputTextView: UIViewRepresentable {
    @Binding public var text: String
    @Binding public var dynamicHeight: CGFloat
    public var placeholder: String
    public var minHeight: CGFloat
    public var maxHeight: CGFloat
    public var onCommit: () -> Void
    
    public init(
        text: Binding<String>,
        dynamicHeight: Binding<CGFloat> = .constant(36),
        placeholder: String = "Message HomeAI...",
        minHeight: CGFloat = 36,
        maxHeight: CGFloat = 110,
        onCommit: @escaping () -> Void
    ) {
        self._text = text
        self._dynamicHeight = dynamicHeight
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.onCommit = onCommit
    }
    
    public func makeUIView(context: Context) -> CustomUITextView {
        let textView = CustomUITextView()
        textView.delegate = context.coordinator
        textView.onCommit = onCommit
        textView.placeholder = placeholder
        textView.minHeight = minHeight
        textView.maxHeight = maxHeight
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textColor = UIColor(Color.themeText)
        textView.tintColor = .systemBlue
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return textView
    }
    
    public func updateUIView(_ uiView: CustomUITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            uiView.updatePlaceholderVisibility()
        }
        uiView.placeholder = placeholder
        uiView.minHeight = minHeight
        uiView.maxHeight = maxHeight
        uiView.textColor = UIColor(Color.themeText)
        uiView.onCommit = onCommit
        
        context.coordinator.recalculateHeight(for: uiView)
    }
    
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: CustomUITextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? 300
        let fitted = uiView.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        let clampedHeight = min(max(fitted.height, minHeight), maxHeight)
        return CGSize(width: targetWidth, height: clampedHeight)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UITextViewDelegate {
        var parent: ChatInputTextView
        
        init(_ parent: ChatInputTextView) {
            self.parent = parent
        }
        
        public func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            if let customTV = textView as? CustomUITextView {
                customTV.updatePlaceholderVisibility()
                recalculateHeight(for: customTV)
            }
        }
        
        public func recalculateHeight(for textView: UITextView) {
            let width = textView.bounds.width > 0 ? textView.bounds.width : (UIScreen.main.bounds.width - 120)
            let fitted = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            let newHeight = min(max(fitted.height, parent.minHeight), parent.maxHeight)
            textView.isScrollEnabled = fitted.height > parent.maxHeight
            
            if abs(parent.dynamicHeight - newHeight) > 0.5 {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = newHeight
                }
            }
        }
        
        public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard let customTV = textView as? CustomUITextView else { return true }
            
            // Intercept return key press
            if text == "\n" {
                if customTV.isShiftDown {
                    // Shift + Enter: Allow newline
                    return true
                } else {
                    // Enter without Shift: Send message
                    customTV.onCommit?()
                    return false
                }
            }
            return true
        }
    }
}

public final class CustomUITextView: UITextView {
    public var onCommit: (() -> Void)?
    public var minHeight: CGFloat = 36
    public var maxHeight: CGFloat = 110
    public var isShiftDown: Bool = false
    
    public var placeholder: String = "" {
        didSet { placeholderLabel.text = placeholder }
    }
    
    public let placeholderLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(Color.themeSecondaryText)
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.isUserInteractionEnabled = false
        return label
    }()
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupPlaceholder()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlaceholder()
    }
    
    private func setupPlaceholder() {
        addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8)
        ])
    }
    
    public func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !text.isEmpty
    }
    
    override public var intrinsicContentSize: CGSize {
        let targetWidth = bounds.width > 0 ? bounds.width : 300
        let fittedSize = sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        let clampedHeight = min(max(fittedSize.height, minHeight), maxHeight)
        isScrollEnabled = fittedSize.height > maxHeight
        return CGSize(width: UIView.noIntrinsicMetric, height: clampedHeight)
    }
    
    // MARK: - Key Commands for Hardware Keyboard Interception
    override public var keyCommands: [UIKeyCommand]? {
        let sendCommand = UIKeyCommand(
            input: "\r",
            modifierFlags: [],
            action: #selector(handleHardwareReturnKey)
        )
        sendCommand.wantsPriorityOverSystemBehavior = true
        
        let newlineCommand = UIKeyCommand(
            input: "\r",
            modifierFlags: .shift,
            action: #selector(handleHardwareShiftReturnKey)
        )
        newlineCommand.wantsPriorityOverSystemBehavior = true
        
        return [sendCommand, newlineCommand]
    }
    
    @objc public func handleHardwareReturnKey() {
        onCommit?()
    }
    
    @objc public func handleHardwareShiftReturnKey() {
        insertText("\n")
        delegate?.textViewDidChange?(self)
    }
    
    // MARK: - Track Shift Modifier Key in Presses
    override public func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let event = event {
            isShiftDown = event.modifierFlags.contains(.shift)
        }
        super.pressesBegan(presses, with: event)
    }
    
    override public func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let event = event {
            isShiftDown = event.modifierFlags.contains(.shift)
        }
        super.pressesChanged(presses, with: event)
    }
    
    override public func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let event = event {
            isShiftDown = event.modifierFlags.contains(.shift)
        } else {
            isShiftDown = false
        }
        super.pressesEnded(presses, with: event)
    }
    
    override public func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        isShiftDown = false
        super.pressesCancelled(presses, with: event)
    }
}
