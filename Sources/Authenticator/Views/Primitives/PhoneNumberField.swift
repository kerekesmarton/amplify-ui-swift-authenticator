//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

/// This field allows the user to enter a phone number
/// It consists of two fields: one for the dialing code and one for the actual phone number
/// and updates the associated Binding with the concatenation of both.
/// It also applies Amplify UI's theming
struct PhoneNumberField: View {
    @Environment(\.authenticatorTheme) var theme
    @ObservedObject private var validator: Validator
    @Binding private var text: String
    @FocusState private var isFocused: Bool
    @FocusState private var focusedField: FieldType?
    @State private var callingCode: String = CountryUtils.shared.currentCallingCode
    @State private var phoneNumber: String = ""

    private let label: String?
    private let placeholder: String

    init(_ label: String,
         text: Binding<String>,
         placeholder: String,
         validator: Validator? = nil) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.validator = validator ?? .init(
            using: FieldValidators.none
        )
        self.validator.value = text
    }

    init(_ placeholder: String,
         text: Binding<String>,
         validator: Validator? = nil) {
        self.label = nil
        self._text = text
        self.placeholder = placeholder
        self.validator = validator ?? .init(
            using: FieldValidators.none
        )
        self.validator.value = text
    }

    var body: some View {
        AuthenticatorField(
            label,
            placeholder: placeholder,
            validator: validator,
            isFocused: focusedField != nil
        ) {
            HStack(spacing: 0) {
                CountryCodeList(callingCode: $callingCode)
                    .foregroundColor(foregroundColor)
                    .focused($focusedField, equals: .callingCode)
                    .onChange(of: callingCode) { text in
                        self.text = "\(text)\(phoneNumber)"
                    }

                Divider()
                    .frame(width: 1)
                    .overlay(theme.Colors.Border.primary)

                SwiftUI.TextField(placeholder, text: $phoneNumber)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .phoneNumber)
                    .onChange(of: phoneNumber) { text in
                        if text.isEmpty {
                            // If the phone number is empty, we consider this to be an empty input regardless of the calling code, as that one is automatically populated
                            self.text = ""
                        } else {
                            self.text = "\(callingCode)\(text)"
                        }
                        if validator.state != .normal || !text.isEmpty {
                            validator.validate()
                        }
                    }
                    .onChange(of: focusedField) { focusedField in
                        if focusedField == nil {
                            validator.validate()
                        }
                    }
                    .accessibilityLabel(Text(
                        "authenticator.field.phoneNumber.label".localized()
                    ))
                    .textFieldStyle(.plain)
                    .frame(height: Platform.isMacOS ? 20 : 25)
                    .padding([.top, .bottom, .leading], theme.Fields.style.padding)
                #if os(iOS)
                    .autocapitalization(.none)
                    .keyboardType(.numberPad)
                #endif

                if shouldDisplayClearButton {
                    ImageButton(.clear) {
                        phoneNumber = ""
                    }
                    .tintColor(borderColor)
                    .padding([.top, .bottom, .trailing], theme.Fields.style.padding)
                }
            }
            .focused($isFocused)
            .onAppear {
                validator.value = $phoneNumber
            }
            .onChange(of: isFocused) { isFocused in
                if isFocused && !Platform.isMacOS {
                    focusedField = .phoneNumber
                }
            }
        }
    }

    private var foregroundColor: Color {
        switch validator.state {
        case .normal:
            return theme.Colors.Foreground.secondary
        case .error:
            return theme.Colors.Foreground.error
        }
    }

    private var borderColor: Color {
        switch validator.state {
        case .normal:
            return theme.Colors.Border.interactive
        case .error:
            return theme.Colors.Border.error
        }
    }

    private var shouldDisplayClearButton: Bool {
        // Show the clear button when there's text and
        // the field is focused on non-macOS platforms
        return !text.isEmpty && (Platform.isMacOS || focusedField != nil)
    }

    private enum FieldType: Hashable {
        case callingCode
        case phoneNumber
    }
}

/// This allows the user to select a dialing code from a list of all available ones,
/// showing a localized name of the region associated with each code and its flag
struct CountryCodeList: View {
    @Environment(\.authenticatorTheme) var theme
    @State private var searchCountry: String = ""
    @State private var isShowingList = false
    @FocusState private var isFocused: Bool
    @Binding var callingCode: String
    private let defaultCallingCode = CountryUtils.shared.currentCallingCode
    private let maxCallingCodeLength = 4

    var body: some View {
        SwiftUI.TextField(
            "authenticator.field.diallingCode.placeholder".localized(),
            text: $callingCode
        )
        .focused($isFocused)
        .onChange(of: callingCode) { text in
            if text.isEmpty {
                callingCode = "+"
            } else if !text.hasPrefix("+") {
                var updated = text
                updated.removeAll(where: { $0 == "+" })
                callingCode = "+\(updated)"
            } else if text.count > maxCallingCodeLength {
                callingCode = String(text.prefix(maxCallingCodeLength))
            }
        }
        .onChange(of: isFocused) { isFocused in
            if !isFocused, callingCode == "+" {
                callingCode = defaultCallingCode
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityLabel(Text(
            "authenticator.field.diallingCode.label".localized()
        ))
        .textFieldStyle(.plain)
        .frame(width: 55)
    #if os(iOS)
        .keyboardType(.numberPad)
    #endif
    }

    private var callingCodePicker: some View {
        SwiftUI.Button(
            action: {
                isShowingList = true
            },
            label: {
                SwiftUI.Text(callingCode)
                    .textFieldStyle(.plain)
                    .frame(width: 55, height: 35)
            }
        )
        .buttonStyle(.borderless)
        .sheet(isPresented: $isShowingList) {
            if #available(iOS 16.0, macOS 13.0, *) {
                allCountriesContent
                    .presentationDetents([.medium, .large])
            } else {
                allCountriesContent
            }
        }
    }

    private var allCountriesContent: some View {
    #if os(iOS)
        NavigationView {
            countryList
        }
        .searchable(
            text: $searchCountry,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "authenticator.countryCodes.search".localized()
        )
        .keyboardType(.default)
    #elseif os(macOS)
        VStack {
            SwiftUI.TextField("authenticator.countryCodes.search".localized(), text: $searchCountry)
                .padding([.leading, .top, .trailing])
                .textFieldStyle(.plain)
            Divider()
            countryList
        }
        .frame(width: 400, height: 300)
    #endif
    }

    private var countryList: some View {
        List {
            ForEach(countries, id: \.self) { country in
                SwiftUI.Button(
                    action: {
                        callingCode = country.callingCode
                        isShowingList = false
                    },
                    label: {
                        HStack {
                            Text("\(country.flag) \(country.name)")
                            Spacer()
                            Text("\(country.callingCode)")
                        }
                    }
                )
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(country.name))
            }
        }
        .foregroundColor(theme.Colors.Foreground.primary)
        .listStyle(.plain)
    }

    private var countries: [Country] {
        let allCountries = CountryUtils.shared.allCountries
        guard !searchCountry.isEmpty else {
            return allCountries
        }

        return allCountries.filter {
            $0.name.lowercased().contains(searchCountry.lowercased())
            || $0.callingCode.lowercased().contains(searchCountry.lowercased())
        }
    }
}
