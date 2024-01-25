import SwiftUI

struct Expense: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var cost: Double
    var personName: String
}

class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var groupedExpenses: [String: [Expense]] = [:]
    @Published var totalExpenses: [String: Double] = [:]

    init() {
        loadExpenses()
        updateGroupedExpenses()
    }

    func addExpense(name: String, cost: Double, personName: String) {
        let newExpense = Expense(name: name, cost: cost, personName: personName)
        expenses.append(newExpense)
        saveExpenses()
        updateGroupedExpenses()
    }

    func editExpense(expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            saveExpenses()
            updateGroupedExpenses()
        }
    }

    func deleteExpense(at indexSet: IndexSet) {
        expenses.remove(atOffsets: indexSet)
        saveExpenses()
        updateGroupedExpenses()
    }

    func saveExpenses() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(encoded, forKey: "expenses")
        }
    }

    func loadExpenses() {
        if let data = UserDefaults.standard.data(forKey: "expenses"),
           let loadedExpenses = try? JSONDecoder().decode([Expense].self, from: data) {
            expenses = loadedExpenses
        }
    }

    func updateGroupedExpenses() {
        groupedExpenses = Dictionary(grouping: expenses, by: { $0.personName })
        
        totalExpenses = groupedExpenses.mapValues { expensesArray in
            expensesArray.reduce(0) { $0 + $1.cost }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @State private var showingAddExpense = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.groupedExpenses.keys.sorted(), id: \.self) { personName in
                    Section(header: Text("\(personName) Total: $\(String(format: "%.2f", viewModel.totalExpenses[personName] ?? 0))")) {
                        ForEach(viewModel.groupedExpenses[personName]!) { expense in
                            NavigationLink(destination: ExpenseDetail(expense: expense, viewModel: viewModel)) {
                                Text("\(expense.name): $\(String(format: "%.2f", expense.cost))")
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    let personNames = viewModel.groupedExpenses.keys.sorted()
                    for index in indexSet {
                        if let expenses = viewModel.groupedExpenses[personNames[index]] {
                            let expense = expenses[0] // Assuming we delete the first expense for simplicity
                            viewModel.deleteExpense(at: [viewModel.expenses.firstIndex(of: expense)!])
                        }
                    }
                }
            }
            .navigationTitle("Tabbed by Derin")
            .navigationBarItems(trailing:
                Button(action: {
                    showingAddExpense.toggle()
                }) {
                    Image(systemName: "plus")
                }
            )
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(viewModel: viewModel)
        }
    }
}

struct AddExpenseView: View {
    @State private var expenseName = ""
    @State private var expenseCost = ""
    @State private var personName = ""
    @ObservedObject var viewModel: ExpenseViewModel

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Expense Name", text: $expenseName)
                    TextField("Expense Cost", text: $expenseCost)
                        .keyboardType(.decimalPad)
                    TextField("Person's Name", text: $personName)
                }

                Section {
                    Button("Add Expense") {
                        if let cost = Double(expenseCost) {
                            viewModel.addExpense(name: expenseName, cost: cost, personName: personName)
                            expenseName = ""
                            expenseCost = ""
                            personName = ""
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
        }
    }
}

struct ExpenseDetail: View {
    @State private var editedExpenseName: String = ""
    @State private var editedExpenseCost: String = ""
    @State private var editedPersonName: String = ""

    let expense: Expense
    @ObservedObject var viewModel: ExpenseViewModel

    init(expense: Expense, viewModel: ExpenseViewModel) {
        self.expense = expense
        self.viewModel = viewModel
        _editedExpenseName = State(initialValue: expense.name)
        _editedExpenseCost = State(initialValue: String(expense.cost))
        _editedPersonName = State(initialValue: expense.personName)
    }

    var body: some View {
        Form {
            Section {
                TextField("Expense Name", text: $editedExpenseName)
                TextField("Expense Cost", text: $editedExpenseCost)
                    .keyboardType(.decimalPad)
                TextField("Person's Name", text: $editedPersonName)
            }

            Section {
                Button("Save Changes") {
                    if let cost = Double(editedExpenseCost) {
                        var editedExpense = expense
                        editedExpense.name = editedExpenseName
                        editedExpense.cost = cost
                        editedExpense.personName = editedPersonName
                        viewModel.editExpense(expense: editedExpense)
                    }
                }
                .disabled(editedExpenseName.isEmpty || editedExpenseCost.isEmpty)

                Button("Delete Expense") {
                    viewModel.deleteExpense(at: [viewModel.expenses.firstIndex(where: { $0.id == expense.id })!])
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Edit Expense")
    }
}

@main
struct TabbedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
