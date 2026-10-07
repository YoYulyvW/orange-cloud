//
//  WorkerSecretsDialogs.swift
//  Orange Cloud
//
//  WorkerSecretsView 的三个删除/解绑确认弹窗（拆出以免 body 类型检查超时）。
//

import SwiftUI

/// 三个确认弹窗的载体：绑定与动作由调用方注入。
struct WorkerSecretsDialogs: ViewModifier {
    let secretTitle: String
    let secretPresented: Binding<Bool>
    let onDeleteSecret: () -> Void
    let variableTitle: String
    let variablePresented: Binding<Bool>
    let onDeleteVariable: () -> Void
    let bindTitle: String
    let bindPresented: Binding<Bool>
    let onUnbind: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(secretTitle, isPresented: secretPresented, titleVisibility: .visible) {
                Button("删除", role: .destructive) { onDeleteSecret() }
            } message: {
                Text("密钥值无法读回，删除后需重新设置，不可撤销。")
            }
            .confirmationDialog(variableTitle, isPresented: variablePresented, titleVisibility: .visible) {
                Button("删除", role: .destructive) { onDeleteVariable() }
            }
            .confirmationDialog(bindTitle, isPresented: bindPresented, titleVisibility: .visible) {
                Button("解除绑定", role: .destructive) { onUnbind() }
            } message: {
                Text("仅解除该 Worker 与此资源的绑定，不会删除资源本身。")
            }
    }
}
