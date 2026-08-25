import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("История")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Очистить историю") { model.clearHistory() }
                    .disabled(model.history.isEmpty)
                Button("Закрыть") { dismiss() }
            }

            if model.history.isEmpty {
                Text("История пуста.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(model.history) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(item.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack {
                            Text(item.status.displayName)
                            Text(item.finishedAt.formatted(date: .abbreviated, time: .shortened))
                            if let size = item.fileSize {
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            }
                            Spacer()
                            if item.status == .completed {
                                if item.fileExists, let url = item.outputURL {
                                    Button("Показать в Finder") { model.reveal(url: url) }
                                } else {
                                    Text("Файл больше не найден")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .frame(width: 640, height: 480)
    }
}
