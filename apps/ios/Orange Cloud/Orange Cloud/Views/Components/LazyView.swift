//
//  LazyView.swift
//  Orange Cloud
//
//  延迟构造目的视图：NavigationLink(destination:) 会立即调用 destination() 闭包，
//  对本项目「每个子入口 init 里建 ViewModel」的页面，等于每次渲染都急切构造全部目的页——
//  iOS 16 上直接卡死。用 LazyView 把构造推迟到真正导航时。
//

import SwiftUI

/// 直到 body 被求值（真正导航过去）才构造内容。
struct LazyView<Content: View>: View {
    private let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content { build() }
}
