// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// 日付の変換候補の編集画面
struct DateConversionView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    // 新規ならnil、編集なら編集中のDateConversionのid
    let id: UUID?
    @State var format: String
    @State var locale: DateConversion.DateConversionLocale
    @State var calendar: DateConversion.DateConversionCalendar
    let dateFormatter = DateFormatter()
    let current = Date()
    @State var preview = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Form {
                TextField("Format", text: $format, prompt: Text("YYYY/MM/dd"))
                Picker("Locale", selection: $locale) {
                    ForEach(DateConversion.DateConversionLocale.allCases, id: \.rawValue) { locale in
                        Text(locale.localized).tag(locale)
                    }
                }
                Picker("Calendar", selection: $calendar) {
                    ForEach(DateConversion.DateConversionCalendar.allCases, id: \.rawValue) { calendar in
                        Text(calendar.localized).tag(calendar)
                    }
                }
                HStack(alignment: .center) {
                    Spacer()
                    Text(preview)
                        .font(.callout)
                        .fontWeight(.light)
                    Spacer()
                }
            }
            .formStyle(.grouped)
            .onChange(of: format) { newValue in
                dateFormatter.dateFormat = newValue
                preview = dateFormatter.string(from: current)
            }
            .onChange(of: locale) { newValue in
                dateFormatter.locale = newValue.locale
                preview = dateFormatter.string(from: current)
            }
            .onChange(of: calendar) { newValue in
                dateFormatter.calendar = newValue.calendar
                preview = dateFormatter.string(from: current)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button {
                    if let id {
                        settingsViewModel.updateDateConversion(id: id, format: format, locale: locale, calendar: calendar)
                    } else {
                        settingsViewModel.addDateConversion(format: format, locale: locale, calendar: calendar)
                    }
                    dismiss()
                } label: {
                    Text("Done")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(format.isEmpty)
            }
            .padding()
        }.onAppear {
            dateFormatter.dateFormat = format
            dateFormatter.calendar = calendar.calendar
            dateFormatter.locale = locale.locale
            preview = dateFormatter.string(from: current)
        }
    }
}

#Preview {
    DateConversionView(settingsViewModel: try! SettingsViewModel(),
                       id: nil,
                       format: "yyyy-MM-dd",
                       locale: .enUS,
                       calendar: .gregorian)
}
