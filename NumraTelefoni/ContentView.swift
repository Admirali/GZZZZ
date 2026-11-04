import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: PhoneStore
    @State private var query = ""
    @State private var importPresented = false
    @State private var replacePresented = false
    @State private var helpPresented = false
    @FocusState private var searchFocused: Bool
    private let teal = Color(red: 0.03, green: 0.50, blue: 0.47)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("KONTAKTET E MIA · OFFLINE")
                    .font(.caption.weight(.semibold)).tracking(1).foregroundStyle(teal)
                Text("Numra Telefoni").font(.largeTitle.bold())
                Text("Kërko me telefon, emër e mbiemër ose vetëm mbiemër.")
                    .font(.subheadline).foregroundStyle(.secondary)
                TextField("Emër Mbiemër ose 069…", text: $query)
                    .textFieldStyle(.roundedBorder).font(.body)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .submitLabel(.search).focused($searchFocused)
                    .onSubmit(runSearch).disabled(store.busy)
                    .onChange(of: query) { value in if value.count > 160 { query = String(value.prefix(160)) } }
                HStack(spacing: 12) {
                    Button(action: runSearch) { Label("Kërko", systemImage: "magnifyingglass").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).disabled(!store.ready || store.busy)
                    Button {
                        searchFocused = false
                        if store.ready { replacePresented = true } else { importPresented = true }
                    } label: { Label("Importo", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).disabled(store.busy)
                }
                Button { helpPresented = true } label: { Label("Si të kërkoj?", systemImage: "questionmark.circle") }
                    .font(.footnote)
                if store.busy {
                    if let progress = store.progress { ProgressView(value: progress) }
                    else { ProgressView().frame(maxWidth: .infinity, alignment: .leading) }
                }
                Text(store.status).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityLabel(store.status)
                if !store.ready && !store.busy {
                    VStack(spacing: 10) {
                        Image(systemName: "externaldrive.badge.plus").font(.system(size: 42)).foregroundStyle(teal)
                        Text("Shto bazën e numrave").font(.headline)
                        Text("Zgjidh allphone_perditesuar.db nga Files. Importimi bëhet vetëm një herë.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.results) { person in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(person.name + " " + person.surname).font(.headline)
                                    if !person.father.isEmpty { Text("Atësia: " + person.father).font(.footnote).foregroundStyle(.secondary) }
                                    Text(person.phone.isEmpty ? "Pa numër telefoni" : person.phone)
                                        .font(.title3.weight(.medium)).foregroundStyle(teal).textSelection(.enabled)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                                    .background(.background, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }.padding(.bottom, 16)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 12)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .tint(teal)
            .fileImporter(isPresented: $importPresented, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let url = urls.first { store.importDatabase(from: url) }
                case .failure(let error):
                    let ns = error as NSError
                    if ns.code != NSUserCancelledError { store.report("Skedari nuk mund të hapet. Provo përsëri nga Files.") }
                }
            }
            .confirmationDialog("Zëvendëso bazën ekzistuese?", isPresented: $replacePresented, titleVisibility: .visible) {
                Button("Zgjidh skedarin e ri") { importPresented = true }
                Button("Anulo", role: .cancel) { }
            } message: { Text("Baza e vjetër zëvendësohet pasi skedari i ri importohet dhe kontrollohet. Gjatë importimit duhet hapësirë për të dyja.") }
            .sheet(isPresented: $helpPresented) { help }
        }
    }

    private func runSearch() {
        searchFocused = false
        store.search(query)
    }

    private var help: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Formatet e kërkimit").font(.title2.bold())
                    Text("Emër Mbiemër\nEmër Atësi Mbiemër\nEmër Mbiemër /Atësi\nVetëm mbiemër\nNumër telefoni ose fillimi i tij")
                    Text("Për telefonin shkruaj të paktën 4 shifra. Përdor * për vazhdime të ndryshme të emrit, si Ar* Hoxha. Pa *, emrat përputhen plotësisht.")
                    Text("Ë/E, Ç/C dhe shkronjat e mëdha/vogla trajtohen njësoj. Shfaqen deri në 500 rezultate.")
                    Text("Importimi").font(.title2.bold())
                    Text("Kopjo allphone_perditesuar.db në Files dhe zgjidhe me Importo. Mbaje aplikacionin hapur derisa të përfundojë. Pas importimit kërkimi punon edhe në modalitetin avion.")
                    Text("Skedari ruhet në hapësirën private të aplikacionit. Nuk ngarkohet në server. Nëse e fshin aplikacionin, baza duhet importuar sërish.")
                }.padding(20)
            }.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Mbyll") { helpPresented = false } } }
        }.presentationDragIndicator(.visible)
    }
}
