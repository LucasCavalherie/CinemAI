import Foundation

/// Idioma e região enviados ao backend (`pt-BR` / `BR`). Cai em `en-US`/`US` quando o aparelho
/// não tem os dois no formato esperado pelo servidor.
struct LocaleInfo: Equatable, Sendable {
    let locale: String
    let region: String

    init(locale: String, region: String) {
        self.locale = locale
        self.region = region
    }

    init(_ source: Locale = .current) {
        if let language = source.language.languageCode?.identifier,
           let region = source.region?.identifier,
           language.count == 2, region.count == 2 {
            self.init(locale: "\(language)-\(region)", region: region)
        } else {
            self.init(locale: "en-US", region: "US")
        }
    }
}
