import CloudKit
import SwiftUI

/// Where the app's links point; the pages live in the repo's `site/` folder (GitHub Pages).
enum AppLinks {
    static let support = URL(string: "https://matheusmsil.github.io/Sendlog/")!
    static let privacyPolicy = URL(string: "https://matheusmsil.github.io/Sendlog/privacidade/")!
    static let supportEmail = "matheusmsil.pro@gmail.com"
}

/// Backup status, plus app information: privacy policy, support and the health disclaimer.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accountStatus: CKAccountStatus?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(status.title).font(.headline)
                            Text(status.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: status.icon).foregroundStyle(status.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                    .padding(.vertical, 4)
                }

                Section("Vai para o iCloud") {
                    Label("Treinos, planos, blocos, boulders e séries", systemImage: "checkmark.circle")
                    Label("Notas, ginásios e links de vídeo", systemImage: "checkmark.circle")
                }

                Section {
                    Label("Calorias e frequência cardíaca do Apple Watch", systemImage: "iphone")
                    Label("Peso corporal e preferências das telas", systemImage: "iphone")
                } header: {
                    Text("Fica só neste iPhone")
                } footer: {
                    Text("A Apple não permite guardar dados do app Saúde no iCloud. Num iPhone novo, eles voltam pelo próprio app Saúde: é só vincular os treinos do Apple Watch de novo.")
                }

                Section {
                } footer: {
                    Text("Para trocar de celular: entre com o mesmo Apple ID no iPhone novo, instale o Sendlog e aguarde alguns instantes para os treinos aparecerem.")
                }

                Section("Sobre") {
                    LabeledContent("Versão", value: Self.version)
                    Link(destination: AppLinks.privacyPolicy) {
                        Label("Política de privacidade", systemImage: "hand.raised")
                    }
                    Link(destination: AppLinks.support) {
                        Label("Ajuda e suporte", systemImage: "questionmark.circle")
                    }
                    Link(destination: URL(string: "mailto:\(AppLinks.supportEmail)")!) {
                        Label("Fale conosco", systemImage: "envelope")
                    }
                }

                Section {
                } footer: {
                    Text("O Sendlog não é um dispositivo médico. As análises de carga, risco de lesão e força são referências gerais de treino, não diagnóstico. Em caso de dor ou lesão, procure um profissional de saúde.")
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .task {
                guard DataStore.isSyncEnabled else { return }
                accountStatus = try? await CKContainer(identifier: DataStore.cloudContainerID).accountStatus()
            }
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    private var status: (title: String, detail: String, icon: String, isActive: Bool) {
        guard DataStore.isSyncConfigured else {
            return ("Backup no iCloud desligado", "Esta versão do app foi instalada sem iCloud. Seus dados estão salvos só neste iPhone.", "icloud.slash", false)
        }
        guard DataStore.isSyncEnabled else {
            return ("Backup indisponível", "Não foi possível conectar ao iCloud. Seus dados estão salvos só neste iPhone.", "icloud.slash", false)
        }
        switch accountStatus {
        case .available:
            return ("Backup no iCloud ativo", "Seus treinos e planos são salvos no iCloud do seu Apple ID e sincronizados automaticamente.", "checkmark.icloud.fill", true)
        case .noAccount:
            return ("Entre no iCloud", "Entre com seu Apple ID em Ajustes para fazer backup dos treinos. Até lá, eles ficam só neste iPhone.", "icloud.slash", false)
        case .restricted, .temporarilyUnavailable:
            return ("iCloud indisponível no momento", "O backup volta a funcionar sozinho quando o iCloud estiver disponível.", "exclamationmark.icloud", false)
        default:
            return ("Verificando o iCloud…", "", "icloud", false)
        }
    }
}
