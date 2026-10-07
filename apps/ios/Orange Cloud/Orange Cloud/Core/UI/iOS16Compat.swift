//
//  iOS16Compat.swift
//  Orange Cloud
//
//  iOS 16.4 移植兼容层：把 iOS 17+ 专属的 SwiftUI 组件用 #available 降级，
//  iOS 17+ 走原生（外观一致），iOS 16 用等价自绘实现。
//

import SwiftUI

// MARK: - ContentUnavailableView（iOS 17+）

struct OCContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    let _label: Label
    let _description: Description
    let _actions: Actions

    init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder description: () -> Description = { EmptyView() },
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self._label = label()
        self._description = description()
        self._actions = actions()
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView {
                _label
            } description: {
                _description
            } actions: {
                _actions
            }
        } else {
            VStack(spacing: 14) {
                _label
                    .font(.system(size: 52))
                    .foregroundStyle(.secondary)
                _description
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                _actions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }
}

extension OCContentUnavailableView
where Label == SwiftUI.Label<Text, Image>, Description == Text, Actions == EmptyView {

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.init(
            label: { SwiftUI.Label(title, systemImage: systemImage) },
            description: { description ?? Text("") },
            actions: { EmptyView() }
        )
    }

    static func search(text: String) -> Self {
        Self(
            label: { SwiftUI.Label(String(localized: "无结果"), systemImage: "magnifyingglass") },
            description: { Text(String(localized: "没有匹配「\(text)」的内容")) },
            actions: { EmptyView() }
        )
    }
}

// MARK: - sensoryFeedback（iOS 17+）

extension View {
    @ViewBuilder
    func ocSensoryFeedback(_ feedback: OCSensoryFeedback, trigger: some Equatable) -> some View {
        if #available(iOS 17.0, *) {
            switch feedback {
            case .success:
                self.sensoryFeedback(.success, trigger: trigger)
            case .impactLight:
                self.sensoryFeedback(.impact(weight: .light), trigger: trigger)
            }
        } else {
            self
        }
    }
}

enum OCSensoryFeedback {
    case success
    case impactLight
}
