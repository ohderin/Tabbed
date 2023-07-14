import SwiftUI

struct SpendingTab: Identifiable, Codable {
    let id = UUID()
    var name: String
    var totalAmount: Double
    var expenses: [Double]
    var reasons: [String] // Array to store reasons associated with expenses
    
    var formattedTotalAmount: String {
        String(format: "%.2f", totalAmount)
    }
    
    mutating func addExpense(amount: Double, reason: String) {
        expenses.append(amount)
        reasons.append(reason) // Add the reason to the array
        totalAmount += amount
    }
    
    mutating func updateExpense(at index: Int, with newValue: Double) {
        let oldValue = expenses[index]
        expenses[index] = newValue
        totalAmount += (newValue - oldValue)
    }
}

private func saveTabs(_ tabs: [SpendingTab]) {
    do {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("tabs.json")
        let data = try JSONEncoder().encode(tabs)
        try data.write(to: fileURL)
    } catch {
        print("Error saving tabs data: \(error)")
    }
}

private func loadTabs() -> [SpendingTab] {
    do {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("tabs.json")
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        let tabs = try JSONDecoder().decode([SpendingTab].self, from: data)
        return tabs.sorted(by: { $0.name < $1.name })
    } catch {
        print("Error loading tabs data: \(error)")
        return []
    }
}

struct ContentView: View {
    @State private var tabs: [SpendingTab] = []
    @State private var newTabName = ""
    @State private var selectedTabIndex = 0
    @State private var isEditingExpenses = false // Track editing expenses mode
    @State private var isCreateTabVisible = false // Track visibility of "Create a New Tab" elements
    
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
                
                // Rest of the code...
            }
            .onAppear {
                tabs = loadTabs()
            }
            .navigationTitle("Tabbed by Derin")
        }
    }
}


struct SpendingTabView: View {
    @Binding var tab: SpendingTab
    @Binding var isEditingExpenses: Bool
    @State private var customAmount = ""
    @State private var customReason = ""
    
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
                            ExpenseEditRow(expense: $tab.expenses[index], reason: $tab.reasons[index])
                        } else {
                            HStack {
                                Text("$\(String(format: "%.2f", tab.expenses[index]))")
                                    .font(.headline)
                                Text(tab.reasons[index])
                                    .font(.body)
                            }
                            .onTapGesture {
                                isEditingExpenses = true
                            }
                        }
                    }
                    .onDelete { indexSet in
                        tab.expenses.remove(atOffsets: indexSet)
                        tab.reasons.remove(atOffsets: indexSet)
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
                        }
                        .padding()
                        
                        HStack {
                            Text("Enter Reason")
                            Spacer()
                            TextField("", text: $customReason)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding()
                        
                        HStack {
                            Button(action: {
                                if let amount = Double(customAmount) {
                                    tab.addExpense(amount: amount, reason: customReason)
                                    customAmount = ""
                                    customReason = ""
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
                                    tab.addExpense(amount: -amount, reason: customReason)
                                    customAmount = ""
                                    customReason = ""
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
                    
                    if !tab.reasons.isEmpty {
                        Text("Reasons:")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        ForEach(tab.reasons.indices, id: \.self) { index in
                            HStack {
                                Text("$\(String(format: "%.2f", tab.expenses[index]))")
                                    .font(.headline)
                                Text(tab.reasons[index])
                                    .font(.body)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ExpenseEditRow: View {
    @Binding var expense: Double
    @Binding var reason: String
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
            
            TextField("Reason", text: $reason)
                .textFieldStyle(RoundedBorderTextFieldStyle())
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
