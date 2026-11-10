import WidgetKit
import SwiftUI

struct TestEntry: TimelineEntry { let date: Date }

struct TestProvider: TimelineProvider {
    func placeholder(in context: Context) -> TestEntry { TestEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (TestEntry) -> Void) {
        completion(TestEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TestEntry>) -> Void) {
        // Static content. No network, location, or periodic refresh.
        completion(Timeline(entries: [TestEntry(date: Date())], policy: .never))
    }
}

enum GlassVariant {
    case normal, clear, blur, blue
    var number: String {
        switch self {
        case .normal: return "01"
        case .clear: return "02"
        case .blur: return "03"
        case .blue: return "04"
        }
    }
    var name: String {
        switch self {
        case .normal: return "Обычный"
        case .clear: return "Прозрачный"
        case .blur: return "Размытый"
        case .blue: return "Синий"
        }
    }
    var caption: String {
        switch self {
        case .normal: return "Контрольный фон"
        case .clear: return "Проверка прозрачности"
        case .blur: return "Проверка стекла"
        case .blue: return "Стекло с оттенком"
        }
    }
}

struct GlassTestView: View {
    @Environment(\.widgetFamily) private var family
    let variant: GlassVariant
    private var isSmall: Bool { family == .systemSmall }

    var body: some View {
        ZStack {
            // A color wash over the requested system blur, not fake wallpaper.
            if variant == .blue {
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.28, blue: 0.66).opacity(0.38),
                             Color(red: 0.02, green: 0.19, blue: 0.48).opacity(0.20)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            if isSmall {
                VStack(alignment: .leading, spacing: 8) {
                    topLabel
                    Spacer(minLength: 0)
                    logo.frame(width: 48, height: 38)
                    Text("Проверка\nстекла")
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.8)
                    Text(variant.name).font(.system(size: 11, weight: .medium)).opacity(0.8)
                }.padding(16)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    topLabel
                    Spacer(minLength: 10)
                    HStack(alignment: .center, spacing: 17) {
                        logo.frame(width: 70, height: 58)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Привет, Егор")
                                .font(.system(size: 25, weight: .semibold, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text("Текст для проверки")
                                .font(.system(size: 13, weight: .medium)).opacity(0.85)
                        }
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 10)
                    Text(variant.caption).font(.system(size: 11, weight: .medium)).opacity(0.7)
                }.padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
    }

    private var logo: some View {
        Image("CloudLogo").renderingMode(.template).resizable().scaledToFit()
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }
    private var topLabel: some View {
        HStack {
            Text("GLASS TEST").tracking(2)
            Spacer()
            Text(variant.number).monospacedDigit()
        }.font(.system(size: 10, weight: .semibold)).opacity(0.8)
    }
}

struct MyNormalWidget: Widget {
    let kind = "MyNormalWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TestProvider()) { _ in
            GlassTestView(variant: .normal)
                .containerBackground(Color(red: 0.07, green: 0.09, blue: 0.14), for: .widget)
        }
        .configurationDisplayName("01 · Обычный")
        .description("Непрозрачный фон для сравнения.")
        .supportedFamilies([.systemSmall, .systemMedium]).contentMarginsDisabled()
    }
}
struct MyClearWidget: Widget {
    let kind = "MyClearWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TestProvider()) { _ in
            GlassTestView(variant: .clear).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("02 · Прозрачный")
        .description("Экспериментальный прозрачный фон. Результат зависит от iOS.")
        .supportedFamilies([.systemSmall, .systemMedium]).contentMarginsDisabled()
    }
}
struct MyBlurWidget: Widget {
    let kind = "MyBlurWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TestProvider()) { _ in
            GlassTestView(variant: .blur).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("03 · Размытый")
        .description("Запрос системного размытия через внутренние настройки виджета.")
        .supportedFamilies([.systemSmall, .systemMedium]).contentMarginsDisabled()
    }
}
struct MyBlueWidget: Widget {
    let kind = "MyBlueWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TestProvider()) { _ in
            GlassTestView(variant: .blue).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("04 · Синий")
        .description("Запрос размытия с полупрозрачным синим оттенком поверх.")
        .supportedFamilies([.systemSmall, .systemMedium]).contentMarginsDisabled()
    }
}

#Preview(as: .systemMedium) {
    MyBlurWidget()
} timeline: {
    TestEntry(date: Date())
}
