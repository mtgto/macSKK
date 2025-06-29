// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ListFooterControls: ViewModifier {
    @Environment(\.defaultMinListRowHeight) var defaultMinListRowHeight
    var addAction: () -> Void
    var removeAction: () -> Void

    func body(content: Content) -> some View {
        content
            .padding(.bottom, defaultMinListRowHeight)
            .overlay(alignment: .bottom) {
                HStack(spacing: 0) {
                    Button {
                        addAction()
                    } label: {
                        Image(systemName: "plus")
                            .contentShape(Rectangle())
                            .frame(width: 20, height: 20)
                    }
                    .labelStyle(.iconOnly)
                    Divider()
                        .padding(.horizontal, 4)
                    Button {
                        removeAction()
                    } label: {
                        Image(systemName: "minus")
                            .contentShape(Rectangle())
                            .frame(width: 20, height: 20)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(false)
                    Spacer()
                }
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                .background(.separator)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .frame(height: defaultMinListRowHeight)
            }
    }
}

extension List {
    func listFooterControls(addAction: @escaping () -> Void, removeAction: @escaping () -> Void) -> some View {
        self
            .modifier(ListFooterControls(addAction: addAction, removeAction: removeAction))
    }
}
