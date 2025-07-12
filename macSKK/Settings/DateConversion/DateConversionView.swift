// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// 日付の変換候補の編集画面
struct DateConversionView: View {
    struct Inputs {
        var format: String
        var locale: DateConversion.DateConversionLocale
        var calendar: DateConversion.DateConversionCalendar
        let dateFormatter = DateFormatter()
        let current = Date()
        var formatted: String {
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale.locale
            dateFormatter.calendar = calendar.calendar
            return dateFormatter.string(from: current)
        }
    }
    @StateObject var settingsViewModel: SettingsViewModel
    // 新規ならnil、編集なら編集中のDateConversionのid
    let id: UUID?
    @State var inputs: Inputs
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Form {
                TextField("Format", text: $inputs.format, prompt: Text("YYYY/MM/dd"))
                Picker("Locale", selection: $inputs.locale) {
                    ForEach(DateConversion.DateConversionLocale.allCases, id: \.rawValue) { locale in
                        Text(locale.localized).tag(locale)
                    }
                }
                Picker("Calendar", selection: $inputs.calendar) {
                    ForEach(DateConversion.DateConversionCalendar.allCases, id: \.rawValue) { calendar in
                        Text(calendar.localized).tag(calendar)
                    }
                }
                HStack(alignment: .center) {
                    Spacer()
                    Text(inputs.formatted)
                        .font(.callout)
                        .fontWeight(.light)
                    Spacer()
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button {
                    if let id {
                        settingsViewModel.updateDateConversion(id: id, format: inputs.format, locale: inputs.locale, calendar: inputs.calendar)
                    } else {
                        settingsViewModel.addDateConversion(format: inputs.format, locale: inputs.locale, calendar: inputs.calendar)
                    }
                    dismiss()
                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
                .disabled(inputs.format.isEmpty)
            }
            .padding()
        }
    }
}

#Preview {
    DateConversionView(
        settingsViewModel: try! SettingsViewModel(),
        id: nil,
        inputs: DateConversionView.Inputs(
            format: "yyyy-MM-dd",
            locale: .enUS,
            calendar: .gregorian))
}
