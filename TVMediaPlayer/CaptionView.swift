//
//  Created by Bart Whiteley on 11/5/22.
//

import UIKit

class CaptionView: UIView {
    
    let segmentedControl = UISegmentedControl()
    
    var changeHandler: (Int?) -> Void = { _ in }
    var dismissHandler: () -> Void = { }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .darkGray
        let label = UILabel(frame: .init(x: 0, y: 60, width: frame.width, height: 50))
        label.text = "Captions"
        label.textAlignment = .center
        addSubview(label)
        addSubview(segmentedControl)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            segmentedControl.centerXAnchor.constraint(equalTo: label.centerXAnchor),
        ])
        
        segmentedControl.addTarget(self, action: #selector(segmentSelected(_:)), for: .valueChanged)
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(segmentClicked(_:)))
        segmentedControl.addGestureRecognizer(gesture)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(labels: [String], selected: Int?, handler: @escaping (Int?) -> Void) {
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: "Off", at: 0, animated: false)
        for (i, label) in labels.enumerated() {
            segmentedControl.insertSegment(withTitle: label, at: i + 1, animated: false)
        }
        if let selected {
            segmentedControl.selectedSegmentIndex = selected + 1
        } else {
            segmentedControl.selectedSegmentIndex = 0
        }
        self.changeHandler = handler
    }
    
    var currentSelected: Int? {
        let index = segmentedControl.selectedSegmentIndex
        return index == 0 ? nil : index - 1
    }
    
    @objc private func segmentSelected(_ sender: UISegmentedControl) {
        changeHandler(currentSelected)
    }
    
    @objc private func segmentClicked(_ sender: UISegmentedControl) {
        dismissHandler()
    }
}
