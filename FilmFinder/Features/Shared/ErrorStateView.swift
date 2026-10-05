import SwiftUI

enum ErrorKind {
    case noResults
    case offline
    case serviceUnavailable
    case quotaExceeded
    case generic

    init(_ error: APIError) {
        switch error {
        case .offline: self = .offline
        case .serviceUnavailable: self = .serviceUnavailable
        case .quotaExceeded: self = .quotaExceeded
        default: self = .generic
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .noResults: "Não encontramos nada..."
        case .offline: "Sem conexão"
        case .serviceUnavailable: "Serviço indisponível no momento"
        case .quotaExceeded: "Suas buscas de hoje acabaram"
        case .generic: "Algo deu errado"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .noResults: "Tente novamente mais tarde ou descreva algo diferente"
        case .offline: "Verifique sua internet e tente novamente"
        case .serviceUnavailable: "Estamos com instabilidade. Tente novamente em instantes"
        case .quotaExceeded: "Volte amanhã para novas recomendações"
        case .generic: "Tente novamente"
        }
    }
}

struct ErrorStateView: View {
    let kind: ErrorKind
    var onRetry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            Image("onboardingTop")
                .padding()

            Image("error")
                .padding(.bottom, 2)
                .padding(.top, 20)

            VStack {
                Text(kind.title)
                    .foregroundColor(Color("branco"))
                    .fontWeight(.bold)
                    .padding(.bottom)

                Text(kind.message)
                    .foregroundColor(Color("branco"))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
            }
            .padding(.vertical)
            .padding(.horizontal, 32)

            if let onRetry {
                Button(action: onRetry) {
                    Text("Tentar de novo")
                        .font(.system(size: 17))
                        .fontWeight(.bold)
                        .foregroundColor(Color("preto"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color("laranja"))
                        .cornerRadius(16)
                }
            }

            Button {
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "chevron.backward")
                    Text("Voltar")
                }
                .font(.system(size: 20))
                .fontWeight(.bold)
                .foregroundColor(Color("laranja"))
            }
            .padding(.vertical, 8)

            Spacer()
        }
    }
}
