import AuthenticationServices
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var confirmingDelete = false

    private var account: AccountModel { environment.account }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                searchesSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.cinza1)
            .navigationTitle("Ajustes")
            .task {
                await account.refresh()
                if !account.isSignedIn { await account.prepareSignIn() }
            }
            .confirmationDialog("Excluir conta?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Excluir conta", role: .destructive) {
                    Task { await account.deleteAccount() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Sua conta e sua assinatura vinculada serão removidas dos nossos servidores. Seus filmes salvos neste aparelho continuam aqui.")
            }
        }
    }

    // MARK: - Conta

    private var accountSection: some View {
        Section("Conta") {
            if account.isSignedIn {
                Label("Conectado com a Apple", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.laranja)
                Button("Sair") {
                    Task { await account.signOut() }
                }
                Button("Excluir conta", role: .destructive) {
                    confirmingDelete = true
                }
            } else {
                Text("Entre para usar sua assinatura em todos os seus aparelhos. Você pode buscar sem entrar.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = []
                    request.nonce = account.signInNonce
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 48)
                .disabled(account.signInNonce == nil || account.isBusy)
            }

            if let error = account.lastError {
                Text(ErrorKind(error).title)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let codeData = credential.authorizationCode,
                let token = String(data: tokenData, encoding: .utf8),
                let code = String(data: codeData, encoding: .utf8)
            else { return }
            Task { await account.completeSignIn(identityToken: token, authorizationCode: code) }
        case .failure:
            // Cancelou ou falhou: o desafio já foi usado pela folha, pega um novo.
            Task { await account.prepareSignIn() }
        }
    }

    // MARK: - Buscas

    private var searchesSection: some View {
        Section("Buscas") {
            if let quota = account.quota {
                Text("\(quota.remaining) de \(quota.limit) buscas restantes hoje")
            } else {
                Text("Carregando…")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sobre

    private var aboutSection: some View {
        Section("Sobre") {
            Text("Dados de filmes e séries: TMDB")
            Text("Dados de streaming: JustWatch")
            if let url = infoURL("PrivacyPolicyURL") {
                Link("Política de privacidade", destination: url)
            }
            if let url = infoURL("TermsURL") {
                Link("Termos de uso", destination: url)
            }
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                LabeledContent("Versão", value: version)
            }
        }
    }

    private func infoURL(_ key: String) -> URL? {
        guard let raw = Bundle.main.infoDictionary?[key] as? String, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment.live())
}
