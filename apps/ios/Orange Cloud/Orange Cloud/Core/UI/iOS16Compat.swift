//
//  iOS16Compat.swift
//  Orange Cloud
//
//  iOS 16.4 移植兼容层：把 iOS 17+ 专属的 SwiftUI 组件用 #available 降级。
//

import SwiftUI
import Perception
import Charts

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

    var body: some View { WithPerceptionTracking {
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
    }}
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

// MARK: - symbolEffect / contentTransition（iOS 17+）

extension View {
    /// contentTransition(.symbolEffect(.replace)) 的兼容封装
    @ViewBuilder
    func ocSymbolReplaceTransition() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }

    /// symbolEffect(.bounce, value:) 的兼容封装
    @ViewBuilder
    func ocBounceEffect<V: Equatable>(value: V) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
}

// MARK: - navigationDestination(item:)（iOS 17+）

extension View {
    /// navigationDestination(item:) 的兼容封装：iOS 16 用 isPresented+destination 拆分。
    @ViewBuilder
    func ocNavigationDestination<Item: Hashable, D: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> D
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.navigationDestination(item: item, destination: destination)
        } else {
            self.navigationDestination(isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            )) {
                if let value = item.wrappedValue {
                    destination(value)
                }
            }
        }
    }
}



// MARK: - onChange（iOS 17 新语法 -> iOS 16）

extension View {
    /// 零参数闭包版本
    @ViewBuilder
    func ocOnChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: initial) { action() }
        } else {
            self.onChange(of: value) { _ in action() }
        }
    }

    /// 双参数闭包版本（iOS 16 拿不到旧值，旧值位传新值）
    @ViewBuilder
    func ocOnChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: initial, action)
        } else {
            self.onChange(of: value) { newValue in action(newValue, newValue) }
        }
    }
}

// MARK: - Chart 交互（iOS 17+）

extension View {
    /// chartXSelection(value:) 的兼容封装：iOS 16 不支持图表点选，原样返回。
    func ocChartXSelection<V>(value: Binding<V?>) -> some View {
        self
    }
}
