//
//  SuggestionBannerView.swift
//  SocialWandKeyboard
//

import UIKit

class SuggestionBannerView: UIView {
    private let label = UILabel()
    private let closeButton = UIButton(type: .system)
    private let tapGesture = UITapGestureRecognizer()
    
    var onTap: (() -> Void)?
    var onClose: (() -> Void)?
    
    init(
        message: String = "✨ Tap To Paste! Your AI Suggestion",
        backgroundColor: UIColor? = nil,
        textColor: UIColor? = nil
    ) {
        super.init(frame: .zero)
        setupUI(message: message, backgroundColor: backgroundColor, textColor: textColor)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI(message: "✨ Tap To Paste! Your AI Suggestion", backgroundColor: nil, textColor: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(message: String, backgroundColor: UIColor?, textColor: UIColor?) {
        let resolvedTextColor = textColor ?? .white
        self.backgroundColor = backgroundColor ?? UIColor(red: 139/255, green: 92/255, blue: 246/255, alpha: 1.0)
        layer.cornerRadius = 8
        
        // Close button (X)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = resolvedTextColor
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)
        
        // Label
        label.text = message
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = resolvedTextColor
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            // Close button on right
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Label in center (with padding for close button)
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Tap gesture (only on label area, not close button)
        tapGesture.addTarget(self, action: #selector(handleTap))
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap() {
        onTap?()
    }
    
    @objc private func handleClose() {
        onClose?()
        // Animate removal
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
