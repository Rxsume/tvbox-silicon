import SwiftUI

private struct IOS16Change<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: (Value, Value) -> Void
    @State private var previous: Value

    init(value: Value, initial: Bool, action: @escaping (Value, Value) -> Void) {
        self.value = value
        self.initial = initial
        self.action = action
        _previous = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content
            .onAppear { if initial { action(value, value) } }
            .onChange(of: value) { next in
                let old = previous
                previous = next
                action(old, next)
            }
    }
}

private struct IOS16ScrollPosition<ID: Hashable>: ViewModifier {
    @Binding var selection: ID?
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onAppear { if let selection { proxy.scrollTo(selection, anchor: .top) } }
                .onChange(of: selection) { value in
                    if let value { proxy.scrollTo(value, anchor: .top) }
                }
        }
    }
}

extension View {
    @ViewBuilder func ios16ScrollLayout() -> some View {
        if #available(iOS 17, tvOS 17, macOS 14, *) { scrollTargetLayout() } else { self }
    }

    @ViewBuilder func ios16ScrollPosition<ID: Hashable>(id: Binding<ID?>) -> some View {
        if #available(iOS 17, tvOS 17, macOS 14, *) {
            scrollPosition(id: id, anchor: .top)
        } else {
            modifier(IOS16ScrollPosition(selection: id))
        }
    }

    func ios16OnChange<Value: Equatable>(of value: Value, initial: Bool = false,
                                        _ action: @escaping (Value, Value) -> Void) -> some View {
        modifier(IOS16Change(value: value, initial: initial, action: action))
    }
}
