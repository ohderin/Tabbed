import SwiftUI

struct SpendingTab: Identifiable, Codable {
    let id = UUID()
    var name: String
    var totalAmount: Double
    var expenses: [Double]
    
    var formattedTotalAmount: String {
        String(format: "%.2f", totalAmount)
    }
    
    mutating func addExpense(amount: Double) {
        expenses.append(amount)
        totalAmount += amount
    }
    
    mutating func updateExpense(at index: Int, with newValue: Double) {
        let oldValue = expenses[index]
        expenses[index] = newValue
        totalAmount += (newValue - oldValue)
    }
}

// Save the tabs array to a file
private func saveTabs(_ tabs: [SpendingTab]) {
    do {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        for tab in tabs {
            let tabFileURL = fileURL.appendingPathComponent("\(tab.name).json")
            let data = try JSONEncoder().encode(tab)
            try data.write(to: tabFileURL)
        }
    } catch {
        print("Error saving tabs data: \(error)")
    }
}

// Load the tabs array from a file and sort it alphabetically
private func loadTabs() -> [SpendingTab] {
    var tabs: [SpendingTab] = []
    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!, includingPropertiesForKeys: nil)
        for fileURL in fileURLs {
            if fileURL.pathExtension == "json" {
                let data = try Data(contentsOf: fileURL)
                let tab = try JSONDecoder().decode(SpendingTab.self, from: data)
                tabs.append(tab)
            }
        }
        tabs.sort { $0.name < $1.name } // Sort tabs alphabetically by name
    } catch {
        print("Error loading tabs data: \(error)")
    }
    return tabs
}


// Remove JSON files for deleted tabs
private func removeDeletedTabFiles(_ tabs: [SpendingTab]) {
    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!, includingPropertiesForKeys: nil)
        let savedTabFiles = tabs.map { "\(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!)\($0.name).json" }
        let deletedFiles = fileURLs.filter { !savedTabFiles.contains($0.absoluteString) }
        for fileURL in deletedFiles {
            try FileManager.default.removeItem(at: fileURL)
        }
    } catch {
        print("Error removing deleted tab files: \(error)")
    }
}

struct ContentView: View {
    @State private var tabs: [SpendingTab] = []
    @State private var newTabName = ""
    @State private var selectedTabIndex = 0
    @State private var isEditingExpenses = false // Track editing expenses mode
    
    var body: some View {
        NavigationView {
            VStack {
                if tabs.isEmpty {
                    Text("No Tabs")
                        .font(.title)
                        .foregroundColor(.gray)
                } else {
                    Picker(selection: $selectedTabIndex, label: Text("")) {
                        ForEach(tabs.indices, id: \.self) { index in
                            Text(tabs[index].name)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    SpendingTabView(tab: $tabs[selectedTabIndex], isEditingExpenses: $isEditingExpenses)
                }
                
                Spacer()
                
                if !isEditingExpenses { // Show only when not editing expenses
                    VStack {
                        Text("Create a New Tab")
                            .font(.headline)
                            .padding()
                        
                        TextField("Tab Name", text: $newTabName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        Button(action: {
                            if !newTabName.isEmpty {
                                let newTab = SpendingTab(name: newTabName, totalAmount: 0, expenses: [])
                                tabs.append(newTab)
                                newTabName = ""
                                saveTabs(tabs)
                                tabs.sort { $0.name < $1.name } // Sort tabs alphabetically after adding new tab
                            }
                        }) {
                            Text("Create Tab")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                
                if !tabs.isEmpty { // Show delete button if there are tabs
                    Button(action: {
                        tabs.remove(at: selectedTabIndex)
                        saveTabs(tabs)
                        removeDeletedTabFiles(tabs)
                        tabs.sort { $0.name < $1.name } // Sort tabs alphabetically after deleting tab
                        selectedTabIndex = 0
                    }) {
                        Text("Delete Tab")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .onAppear {
                tabs = loadTabs()
            }
            .navigationTitle("Tabbed")
        }
    }
}

struct SpendingTabView: View {
    @Binding var tab: SpendingTab
    @Binding var isEditingExpenses: Bool // Pass editing expenses mode binding
    @State private var customAmount = ""
    @State private var isKeyboardVisible = false
    
    var body: some View {
        ScrollView {
            VStack {
                Text("\(tab.name)")
                    .font(.title)
                
                Text("Total Amount: $\(tab.formattedTotalAmount)")
                    .font(.headline)
                
                List {
                    ForEach(tab.expenses.indices, id: \.self) { index in
                        if isEditingExpenses {
                            ExpenseEditRow(expense: $tab.expenses[index])
                        } else {
                            Text("$\(String(format: "%.2f", tab.expenses[index]))")
                                .onTapGesture {
                                    isEditingExpenses = true
                                }
                        }
                    }
                    .onDelete { indexSet in
                        tab.expenses.remove(atOffsets: indexSet)
                        saveTabs([tab])
                    }
                }
                
                if isEditingExpenses {
                    VStack {
                        HStack {
                            Text("Enter Amount")
                            Spacer()
                            TextField("0.00", text: $customAmount)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                                    isKeyboardVisible = true
                                }
                                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                                    isKeyboardVisible = false
                                }
                        }
                        .padding()
                        
                        HStack {
                            Button(action: {
                                if let amount = Double(customAmount) {
                                    tab.addExpense(amount: amount)
                                    customAmount = ""
                                    isEditingExpenses = false
                                    saveTabs([tab])
                                }
                            }) {
                                Text("Add Expense")
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                if let amount = Double(customAmount) {
                                    tab.addExpense(amount: -amount)
                                    customAmount = ""
                                    isEditingExpenses = false
                                    saveTabs([tab])
                                }
                            }) {
                                Text("Subtract Expense")
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onTapGesture {
                        hideKeyboard()
                    }
                } else {
                    Button(action: {
                        isEditingExpenses = true
                    }) {
                        Text("Edit Expenses")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .padding(.bottom, isKeyboardVisible ? 0 : UIApplication.shared.windows.first?.safeAreaInsets.bottom)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ExpenseEditRow: View {
    @Binding var expense: Double
    @State private var editedExpense: String = ""
    
    var body: some View {
        HStack {
            Text("Expense")
            TextField("", text: $editedExpense, onCommit: {
                if let newValue = Double(editedExpense) {
                    expense = newValue
                }
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.decimalPad)
            .onAppear {
                editedExpense = String(expense)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

@main
struct spendTabApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
