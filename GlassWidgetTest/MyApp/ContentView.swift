import SwiftUI
import WidgetKit

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Проверка стекла") {
                    Text("Четыре виджета с твоим логотипом и тестовым текстом. Погода пока не подключена.")
                    Text("Это эксперимент: прозрачность и размытие могут не работать на твоей версии iOS.")
                        .foregroundStyle(.secondary)
                }
                Section("Как проверить") {
                    Label("Оставь оформление иконок Default.", systemImage: "app.badge")
                    Label("Удерживай домашний экран → Изменить → Добавить виджет → Glass Test.", systemImage: "plus.square")
                    Label("Добавь варианты 01–04. Начни со среднего размера.", systemImage: "rectangle.grid.1x2")
                    Label("Смени обои и пролистни экран. Настоящий фон должен следовать за обоями.", systemImage: "photo")
                    Label("Если фоны одинаково непрозрачные, обход не сработал.", systemImage: "info.circle")
                }
                Section("Варианты") {
                    Text("01 · Обычный — контрольный тёмный фон")
                    Text("02 · Прозрачный — запрос прозрачности")
                    Text("03 · Размытый — запрос системного размытия")
                    Text("04 · Синий — размытие с синим оттенком")
                }
                Section {
                    Button("Запросить обновление виджетов") {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    Text("Кнопка обновляет содержимое, но не гарантирует сброс системного кэша фона. После переустановки при необходимости удали виджет с экрана и добавь снова.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Glass Test")
        }
    }
}
