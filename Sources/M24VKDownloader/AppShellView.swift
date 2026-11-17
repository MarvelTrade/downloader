import SwiftUI

struct ContentView: View {
    @StateObject private var downloads = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)
            DownloaderView(model: downloads)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().opacity(0.35)
            HStack {
                Spacer()
                Text("Антон Белый")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .frame(minWidth: 900, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $downloads.showingHistory) { HistoryView(model: downloads) }
        .sheet(isPresented: $downloads.showingSettings) { SettingsView(model: downloads) }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.gradient)
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Загрузчик")
                    .font(.title2.weight(.semibold))
                Text("Загрузка видео по ссылке")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 18)

            Button { downloads.showingHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                .buttonStyle(.bordered)
                .help("История загрузок")
            Button { downloads.showingSettings = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(.bordered)
                .help("Настройки загрузчика")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
    }
}
