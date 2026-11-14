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
    func ios16OnChange<Value: Equatable>(of value: Value, initial: Bool = false,
                                        _ action: @escaping (Value) -> Void) -> some View {
        modifier(IOS16Change(value: value, initial: initial) { _, next in action(next) })
    }
    func ios16OnChange<Value: Equatable>(of value: Value, initial: Bool = false,
                                        _ action: @escaping () -> Void) -> some View {
        modifier(IOS16Change(value: value, initial: initial) { _, _ in action() })
    }
    @ViewBuilder func ios16PresentationCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, tvOS 16.4, macOS 13.3, *) { presentationCornerRadius(radius) } else { self }
    }
    @ViewBuilder func ios16PresentationBackground(_ color: Color) -> some View {
        if #available(iOS 16.4, tvOS 16.4, macOS 13.3, *) { presentationBackground(color) } else { self }
    }
    @ViewBuilder func ios16ScrollClipDisabled() -> some View {
        if #available(iOS 17, tvOS 17, macOS 14, *) { scrollClipDisabled() } else { self }
    }
    @ViewBuilder func ios16DefaultFocus<Value: Hashable>(_ binding: FocusState<Value>.Binding, _ value: Value) -> some View {
        if #available(iOS 17, tvOS 17, macOS 14, *) { defaultFocus(binding, value) } else { self }
    }
    func ios16NavigationDestination<Item: Hashable, Destination: View>(item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination) -> some View {
        navigationDestination(isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })) {
            if let value = item.wrappedValue { destination(value) }
        }
    }
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
