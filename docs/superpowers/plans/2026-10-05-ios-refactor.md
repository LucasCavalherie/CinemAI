# App iOS — Refatoração e busca ponta a ponta (Fatia 2) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reescrever a camada de dados e rede do app FilmFinder (iOS 18, `@Observable`, SwiftData, camada de serviços, `Title` unificado para filmes e séries) e ligar a busca ponta a ponta ao Worker `dev`, mostrando o motivo da indicação e onde assistir, sem perder a identidade visual.

**Architecture:** Views não fazem rede nem persistência: usam modelos `@Observable` (`ResultsModel`) que dependem de `RecommendationService` (protocolo, implementado por `APIClient`) e de `LibraryStore` (SwiftData, única fonte de histórico/favoritos/assistidos/exclusões). Toda lógica (decodificação, cliente HTTP, biblioteca, importador legado, buffer) é testada com Swift Testing sem rede; as telas são verificadas por build + execução no simulador contra o Worker `dev`.

**Tech Stack:** Swift (modo 5 durante a migração, Swift 6 no fim), SwiftUI, SwiftData, Swift Testing, XcodeGen, Lottie (já usado), `URLSession`.

**Spec:** `docs/superpowers/specs/2026-10-05-filmfinder-relaunch-design.md` (seções 5.1 a 5.6, 5.8 e item 2 da seção 10). Contrato do backend: `backend/src/schemas.ts` (tipo `Title`) e `backend/src/routes/recommendations.ts`.

## Global Constraints

- iOS **18.0** mínimo (`IPHONEOS_DEPLOYMENT_TARGET: '18.0'`); Swift 6 com strict concurrency ao final (Task 11); `@Observable` no lugar de `ObservableObject`; `async/await` no lugar de `DispatchQueue`/completion.
- XcodeGen e Lottie mantidos. `FilmFinder.xcodeproj` é gerado e fica no `.gitignore` (já está).
- Identidade visual mantida: cores (`Color.laranja`, `.cinza1`, `.cinza2`, `.roxo`, `.preto`, `.branco`), fonte expandida, animação `pipocascertasmesmo`, onboarding, ícones.
- Views não fazem rede nem acessam `UserDefaults`; tipo de mídia é o enum `MediaType` (`.movie`, `.tv`), nunca a string `"Filmes"`/`"Séries"`.
- Backend usado nesta fatia: `POST {baseURL}/v1/recommendations` com header `x-dev-key`. Corpo: `{ query, mediaType, excludeTmdbIds, locale, region }` onde `locale` casa `^[a-z]{2}-[A-Z]{2}$` e `region` casa `^[A-Z]{2}$`; `query` até 500 caracteres; `excludeTmdbIds` até 200 ids **do mesmo `mediaType`** (os ids do TMDB de filme e série se sobrepõem). Resposta: `{ "titles": [Title], "quota": null }`.
- `excludeTmdbIds` enviados = ids da biblioteca do mesmo tipo, favoritos e assistidos primeiro, depois os mais recentes por `recommendedAt`, no máximo **200**.
- Buffer: a busca devolve até 12 títulos; mostram-se **3**; o botão trocar usa o buffer **sem nova chamada**; buffer vazio → nova chamada.
- A tela de detalhe mostra o crédito **"Dados de streaming: JustWatch"** (exigência do TMDB) e o `reason` da IA. Sem providers na região: "Não disponível em streaming na sua região".
- Imagens TMDB: pôster `w500`, fundo `w780`, logo de provider `w92` (nunca `original`).
- Nada de segredo versionado: a chave de desenvolvimento fica em `Config/Local.xcconfig` (gitignored).
- Mensagens de commit terminam com a linha `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (ou a linha de atribuição que a sessão exigir).
- Os testes rodam com: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/<Suite>` (sem `-only-testing` roda todos).

## Fora do escopo desta fatia

Sign in with Apple, App Attest, cota exibida no app, paywall/StoreKit, tela de Ajustes (região, excluir conta, créditos), sincronização entre devices. `x-dev-key` é provisório e some na Fatia 3. O app **não** deve ser distribuído (TestFlight/App Store) com a chave de desenvolvimento embutida.

## Decisões de refinamento da spec (registradas aqui)

1. `LibraryItem.inHistory` separa "foi mostrado ao usuário" de "foi recomendado pela IA": os 12 títulos recebidos são gravados como recomendados (e portanto excluídos nas próximas buscas), mas só os **exibidos** entram no Histórico.
2. `LibraryItem` guarda o `Title` como `Data` JSON (`snapshotData`) para evitar problemas de composição no SwiftData e permitir exibir offline.
3. Cada tela de lista (Histórico, Favoritos, Assistidos) usa uma única `LibraryListView` parametrizada por `Kind`.
4. O importador legado trata `SerieData.duration` como número de temporadas (é assim que o app antigo exibia: "`%@ temporadas`") e ignora `originalTitle` legado (o app antigo gravava a data de lançamento nele).

## Estrutura de arquivos

```
project.yml                                   (modificar: iOS 18, Swift 5, testes, xcconfig)
Config/Debug.xcconfig, Release.xcconfig       (criar)
Config/Local.xcconfig                         (criar, gitignored: DEV_API_KEY)
FilmFinder/
  Info.plist                                  (modificar: APIBaseURL, DevAPIKey)
  App/FilmFinderApp.swift                     (renomeado de CimemAIApp.swift)
  App/AppEnvironment.swift
  Domain/MediaType.swift
  Domain/Title.swift                          (Title, Providers, StreamingProvider)
  Domain/Recommendation.swift                 (RecommendationRequest, RecommendationsResponse)
  Domain/TMDBImage.swift
  Domain/LocaleInfo.swift
  Core/API/APIConfig.swift, APIError.swift, APIClient.swift
  Data/LibraryItem.swift, LibraryStore.swift, LegacyImporter.swift
  Features/Results/ResultsModel.swift, ResultsView.swift, TitleCard.swift
  Features/Detail/TitleDetail.swift, StreamingSection.swift
  Features/Search/CategoryQueryBuilder.swift  (+ SearchView.swift, CategoriesView.swift movidos/editados)
  Features/Library/LibraryListView.swift, LibraryRow.swift, HistoryView.swift
  Features/Profile/ProfileView.swift, LibraryPreviewRectangle.swift
  Features/Shared/PosterImage.swift, StarsView.swift, ProviderLogos.swift,
                  ErrorStateView.swift, LoadingStateView.swift, CustomDivider.swift, MediaType+UI.swift
FilmFinderTests/
  Support/TestSupport.swift, LibraryHarness.swift, MockURLProtocol.swift
  Fixtures/recommendations.json
  SmokeTests.swift, TitleTests.swift, APIClientTests.swift, LibraryStoreTests.swift,
  LegacyImporterTests.swift, CategoryQueryBuilderTests.swift, ResultsModelTests.swift
```

---

### Task 1: Ferramentas, configuração do projeto e linha de base

**Files:**
- Modify: `project.yml`, `.gitignore`, `FilmFinder/Info.plist`
- Create: `Config/Debug.xcconfig`, `Config/Release.xcconfig`, `Config/Local.xcconfig` (gitignored)
- Create: `FilmFinder/Secrets.swift` (temporário, gitignored; removido na Task 11)
- Create: `FilmFinderTests/SmokeTests.swift`

**Interfaces:**
- Produces: esquema `FilmFinder` com alvo de testes `FilmFinderTests` (Swift Testing); chaves de Info.plist `APIBaseURL` e `DevAPIKey`; `FilmFinder.xcodeproj` gerável por `xcodegen generate`.

- [ ] **Step 1: Instalar o XcodeGen**

Run: `brew install xcodegen && xcodegen --version`
Expected: imprime uma versão (ex.: `Version: 2.4x.x`).

- [ ] **Step 2: Substituir `project.yml`**

```yaml
name: FilmFinder
options:
  bundleIdPrefix: com.andre
  deploymentTarget:
    iOS: '18.0'

configFiles:
  Debug: Config/Debug.xcconfig
  Release: Config/Release.xcconfig

settings:
  base:
    IPHONEOS_DEPLOYMENT_TARGET: '18.0'
    SWIFT_VERSION: '5.0'

packages:
  Lottie:
    url: 'https://github.com/airbnb/lottie-ios.git'
    from: '4.2.0'

targets:
  FilmFinder:
    type: application
    platform: iOS
    settings:
      base:
        INFO_PLIST_FILE: 'FilmFinder/Info.plist'
        PRODUCT_BUNDLE_IDENTIFIER: 'com.andre.filmfinder'
    sources:
      - path: 'FilmFinder'
    dependencies:
      - package: Lottie
  FilmFinderTests:
    type: bundle.unit-test
    platform: iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: 'com.andre.filmfinder.tests'
        GENERATE_INFOPLIST_FILE: YES
    sources:
      - path: 'FilmFinderTests'
    dependencies:
      - target: FilmFinder

schemes:
  FilmFinder:
    build:
      targets:
        FilmFinder: all
        FilmFinderTests: [test]
    test:
      targets:
        - FilmFinderTests
```

- [ ] **Step 3: Criar os `.xcconfig`**

`Config/Debug.xcconfig`:
```
// "/$()/" evita que o "//" da URL seja lido como comentário.
API_BASE_URL = https:/$()/filmfinder-api-dev.andrefw483.workers.dev
DEV_API_KEY =
#include? "Local.xcconfig"
```

`Config/Release.xcconfig`:
```
// Fatia 5 troca pela URL de produção e remove DEV_API_KEY (substituída por App Attest na Fatia 3).
API_BASE_URL = https:/$()/filmfinder-api-dev.andrefw483.workers.dev
DEV_API_KEY =
#include? "Local.xcconfig"
```

- [ ] **Step 4: Criar `Config/Local.xcconfig` a partir do `.dev.vars` do backend, sem imprimir a chave**

Run:
```bash
bash -c 'set -a; . backend/.dev.vars; set +a; printf "DEV_API_KEY = %s\n" "$DEV_API_KEY" > Config/Local.xcconfig' && awk -F'=' '{print $1"= ("length($2)-1" chars)"}' Config/Local.xcconfig
```
Expected: `DEV_API_KEY = (48 chars)` (o tamanho, nunca o valor).

- [ ] **Step 5: Ignorar o arquivo local — acrescentar ao `.gitignore`**

```
# App iOS
Config/Local.xcconfig
```
Verificar: `git check-ignore Config/Local.xcconfig FilmFinder/Secrets.swift` imprime os dois caminhos.

- [ ] **Step 6: Acrescentar as chaves ao `FilmFinder/Info.plist`** (dentro do `<dict>` raiz, antes de `</dict>` final)

```xml
	<key>APIBaseURL</key>
	<string>$(API_BASE_URL)</string>
	<key>DevAPIKey</key>
	<string>$(DEV_API_KEY)</string>
```

- [ ] **Step 7: Criar o `Secrets.swift` temporário** (o código antigo ainda referencia `Secrets`; o arquivo é gitignored e some na Task 11)

```swift
// Temporário: mantém o código legado compilando até a Task 11. Está no .gitignore.
enum Secrets {
    static let CHATGPT_API_KEY = ""
    static let TMDB_API_KEY = ""
}
```

- [ ] **Step 8: Criar o teste de fumaça `FilmFinderTests/SmokeTests.swift`**

```swift
import Testing
@testable import FilmFinder

@Suite struct SmokeTests {
    @Test func runnerWorks() {
        #expect(1 + 1 == 2)
    }
}
```

- [ ] **Step 9: Gerar o projeto e compilar a linha de base**

Run:
```bash
xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | tail -30
```
Expected: sem `error:` (avisos de código legado são aceitáveis). Se aparecer erro **do código legado** causado só por iOS 18/Xcode novo, corrija o mínimo necessário nesse arquivo; não refatore nada ainda.

- [ ] **Step 10: Rodar o teste de fumaça**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/SmokeTests 2>&1 | tail -15`
Expected: `Test run with 1 test ... passed`.

- [ ] **Step 11: Confirmar que a Info.plist recebeu os valores** (sem mostrar a chave)

Run:
```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug-iphonesimulator/FilmFinder.app' -maxdepth 6 | head -1); /usr/libexec/PlistBuddy -c 'Print :APIBaseURL' "$APP/Info.plist"; /usr/libexec/PlistBuddy -c 'Print :DevAPIKey' "$APP/Info.plist" | awk '{print "DevAPIKey: " length($0) " chars"}'
```
Expected: `https://filmfinder-api-dev.andrefw483.workers.dev` e `DevAPIKey: 48 chars`.

- [ ] **Step 12: Commit**

```bash
git add project.yml .gitignore Config/Debug.xcconfig Config/Release.xcconfig FilmFinder/Info.plist FilmFinderTests
git commit -m "build(ios): target iOS 18, add test target and xcconfig-based API config"
```

---

### Task 2: Domínio — `MediaType`, `Title`, imagens e idioma

**Files:**
- Create: `FilmFinder/Domain/MediaType.swift`, `Title.swift`, `Recommendation.swift`, `TMDBImage.swift`, `LocaleInfo.swift`
- Create: `FilmFinderTests/Support/TestSupport.swift`, `FilmFinderTests/Fixtures/recommendations.json`
- Test: `FilmFinderTests/TitleTests.swift`

**Interfaces:**
- Produces:
  - `enum MediaType: String, Codable, CaseIterable, Sendable { case movie, tv }`
  - `struct StreamingProvider { id: Int; name: String; logoPath: String }`
  - `struct Providers { region: String; link: URL?; flatrate, rent, buy, free: [StreamingProvider]; static func empty(region:) -> Providers; var isEmpty: Bool; func highlighted(limit: Int = 3) -> [StreamingProvider] }`
  - `struct Title: Codable, Hashable, Sendable, Identifiable` com `id` = `"movie-123"`, `static func stars(for rating: Double) -> Int`, `var stars: Int`
  - `struct RecommendationRequest: Encodable, Sendable { query: String; mediaType: MediaType; excludeTmdbIds: [Int]; locale: String; region: String }`
  - `struct RecommendationsResponse: Decodable, Sendable { let titles: [Title] }`
  - `enum TMDBImage { static func poster(_:), backdrop(_:), logo(_:) -> URL? }` (aceitam `String?`)
  - `struct LocaleInfo: Equatable, Sendable { locale: String; region: String; init(_ locale: Locale = .current) }`
  - Teste: `fixtureData(_ name: String) throws -> Data`, `Title.sample(id:type:title:providers:)`

- [ ] **Step 1: Criar a fixture `FilmFinderTests/Fixtures/recommendations.json`** (contrato do backend, escrito à mão)

```json
{
  "titles": [
    {
      "tmdbId": 157336,
      "mediaType": "movie",
      "title": "Interestelar",
      "originalTitle": "Interstellar",
      "year": 2014,
      "overview": "As reservas naturais da Terra estão chegando ao fim.",
      "posterPath": "/poster.jpg",
      "backdropPath": "/backdrop.jpg",
      "rating": 8.5,
      "runtimeMinutes": 169,
      "seasons": null,
      "genres": ["Aventura", "Ficção científica"],
      "reason": "Uma jornada espacial emocionante sobre o tempo.",
      "providers": {
        "region": "BR",
        "link": "https://www.themoviedb.org/movie/157336/watch?locale=BR",
        "flatrate": [
          { "id": 119, "name": "Amazon Prime Video", "logoPath": "/prime.jpg" },
          { "id": 384, "name": "Max", "logoPath": "/max.jpg" }
        ],
        "rent": [{ "id": 2, "name": "Apple TV", "logoPath": "/apple.jpg" }],
        "buy": [],
        "free": [{ "id": 73, "name": "Tubi", "logoPath": "/tubi.jpg" }]
      }
    },
    {
      "tmdbId": 70523,
      "mediaType": "tv",
      "title": "Dark",
      "originalTitle": "Dark",
      "year": 2017,
      "overview": "Uma criança desaparece.",
      "posterPath": null,
      "backdropPath": null,
      "rating": 8.4,
      "runtimeMinutes": null,
      "seasons": 3,
      "genres": ["Drama"],
      "reason": "Mistério denso com viagem no tempo.",
      "providers": { "region": "BR", "link": null, "flatrate": [], "rent": [], "buy": [], "free": [] }
    }
  ],
  "quota": null
}
```

- [ ] **Step 2: Criar `FilmFinderTests/Support/TestSupport.swift`**

```swift
import Foundation
@testable import FilmFinder

private final class BundleToken {}

func fixtureData(_ name: String) throws -> Data {
    guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}

extension Title {
    static func sample(
        id: Int = 1,
        type: MediaType = .movie,
        title: String = "Sample",
        providers: Providers? = nil
    ) -> Title {
        Title(
            tmdbId: id, mediaType: type, title: title, originalTitle: title, year: 2020,
            overview: "Overview", posterPath: "/p.jpg", backdropPath: nil, rating: 7.5,
            runtimeMinutes: type == .movie ? 120 : nil, seasons: type == .tv ? 2 : nil,
            genres: ["Drama"], reason: "Because.", providers: providers ?? .empty(region: "BR")
        )
    }
}
```

- [ ] **Step 3: Escrever os testes que falham — `FilmFinderTests/TitleTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

@Suite struct TitleTests {
    @Test func decodesBackendContract() throws {
        let response = try JSONDecoder().decode(RecommendationsResponse.self, from: fixtureData("recommendations"))
        #expect(response.titles.count == 2)

        let movie = response.titles[0]
        #expect(movie.id == "movie-157336")
        #expect(movie.mediaType == .movie)
        #expect(movie.originalTitle == "Interstellar")
        #expect(movie.year == 2014)
        #expect(movie.runtimeMinutes == 169)
        #expect(movie.seasons == nil)
        #expect(movie.genres == ["Aventura", "Ficção científica"])
        #expect(movie.providers.region == "BR")
        #expect(movie.providers.link?.absoluteString == "https://www.themoviedb.org/movie/157336/watch?locale=BR")
        #expect(movie.providers.flatrate.map(\.name) == ["Amazon Prime Video", "Max"])
        #expect(movie.providers.free.map(\.name) == ["Tubi"])

        let show = response.titles[1]
        #expect(show.id == "tv-70523")
        #expect(show.posterPath == nil)
        #expect(show.seasons == 3)
        #expect(show.providers.link == nil)
        #expect(show.providers.isEmpty)
    }

    @Test func titleSurvivesJSONRoundTrip() throws {
        let original = Title.sample(id: 9, type: .tv)
        let decoded = try JSONDecoder().decode(Title.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func starsAreRoundedAndClamped() {
        #expect(Title.stars(for: 0) == 0)
        #expect(Title.stars(for: 7.571) == 4)
        #expect(Title.stars(for: 9.0) == 5)
        #expect(Title.stars(for: 10) == 5)
        #expect(Title.stars(for: 11) == 5)
        #expect(Title.stars(for: -1) == 0)
    }

    @Test func highlightedPrefersSubscriptionThenFree() throws {
        let response = try JSONDecoder().decode(RecommendationsResponse.self, from: fixtureData("recommendations"))
        #expect(response.titles[0].providers.highlighted(limit: 1).map(\.name) == ["Amazon Prime Video"])
        #expect(response.titles[0].providers.highlighted().count == 2)

        var onlyFree = response.titles[0].providers
        onlyFree.flatrate = []
        #expect(onlyFree.highlighted().map(\.name) == ["Tubi"])
        #expect(response.titles[1].providers.highlighted().isEmpty)
    }

    @Test func requestEncodesBackendFieldNames() throws {
        let request = RecommendationRequest(
            query: "algo leve", mediaType: .tv, excludeTmdbIds: [1, 2], locale: "pt-BR", region: "BR"
        )
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(json["query"] as? String == "algo leve")
        #expect(json["mediaType"] as? String == "tv")
        #expect(json["excludeTmdbIds"] as? [Int] == [1, 2])
        #expect(json["locale"] as? String == "pt-BR")
        #expect(json["region"] as? String == "BR")
    }
}

@Suite struct TMDBImageTests {
    @Test func buildsSizedURLs() {
        #expect(TMDBImage.poster("/a.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w500/a.jpg")
        #expect(TMDBImage.backdrop("/b.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w780/b.jpg")
        #expect(TMDBImage.logo("/c.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w92/c.jpg")
    }

    @Test func rejectsMissingOrMalformedPaths() {
        #expect(TMDBImage.poster(nil) == nil)
        #expect(TMDBImage.poster("") == nil)
        #expect(TMDBImage.poster("a.jpg") == nil)
    }
}

@Suite struct LocaleInfoTests {
    @Test func usesLanguageAndRegion() {
        #expect(LocaleInfo(Locale(identifier: "pt_BR")) == LocaleInfo(locale: "pt-BR", region: "BR"))
        #expect(LocaleInfo(Locale(identifier: "en_GB")) == LocaleInfo(locale: "en-GB", region: "GB"))
    }

    @Test func fallsBackWhenRegionIsMissingOrNotTwoLetters() {
        #expect(LocaleInfo(Locale(identifier: "en")) == LocaleInfo(locale: "en-US", region: "US"))
        #expect(LocaleInfo(Locale(identifier: "es_419")) == LocaleInfo(locale: "en-US", region: "US"))
    }
}
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/TitleTests 2>&1 | grep -E "error:|Test run" | head -5`
Expected: FAIL de compilação — `cannot find 'RecommendationsResponse' in scope` (e similares).

- [ ] **Step 5: Criar `FilmFinder/Domain/MediaType.swift`**

```swift
import Foundation

enum MediaType: String, Codable, CaseIterable, Sendable {
    case movie
    case tv
}
```

- [ ] **Step 6: Criar `FilmFinder/Domain/Title.swift`**

```swift
import Foundation

struct StreamingProvider: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String
}

struct Providers: Codable, Hashable, Sendable {
    var region: String
    var link: URL?
    var flatrate: [StreamingProvider]
    var rent: [StreamingProvider]
    var buy: [StreamingProvider]
    var free: [StreamingProvider]

    static func empty(region: String) -> Providers {
        Providers(region: region, link: nil, flatrate: [], rent: [], buy: [], free: [])
    }

    var isEmpty: Bool {
        flatrate.isEmpty && rent.isEmpty && buy.isEmpty && free.isEmpty
    }

    /// Logos exibidos no card: assinatura primeiro; sem assinatura, os gratuitos.
    func highlighted(limit: Int = 3) -> [StreamingProvider] {
        Array((flatrate.isEmpty ? free : flatrate).prefix(limit))
    }
}

struct Title: Codable, Hashable, Sendable, Identifiable {
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let originalTitle: String
    let year: Int?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let rating: Double
    let runtimeMinutes: Int?
    let seasons: Int?
    let genres: [String]
    let reason: String
    let providers: Providers

    var id: String { "\(mediaType.rawValue)-\(tmdbId)" }

    /// Nota TMDB (0–10) convertida para 0–5 estrelas, como no app antigo.
    static func stars(for rating: Double) -> Int {
        min(5, max(0, Int(rating / 2 + 0.5)))
    }

    var stars: Int { Title.stars(for: rating) }
}
```

- [ ] **Step 6.1: Criar `FilmFinder/Domain/Recommendation.swift`**

```swift
import Foundation

struct RecommendationRequest: Encodable, Sendable {
    let query: String
    let mediaType: MediaType
    let excludeTmdbIds: [Int]
    let locale: String
    let region: String
}

struct RecommendationsResponse: Decodable, Sendable {
    let titles: [Title]
}
```

- [ ] **Step 6.2: Criar `FilmFinder/Domain/TMDBImage.swift`**

```swift
import Foundation

enum TMDBImage {
    static func poster(_ path: String?) -> URL? { url(size: "w500", path) }
    static func backdrop(_ path: String?) -> URL? { url(size: "w780", path) }
    static func logo(_ path: String?) -> URL? { url(size: "w92", path) }

    private static func url(size: String, _ path: String?) -> URL? {
        guard let path, path.hasPrefix("/") else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
```

- [ ] **Step 6.3: Criar `FilmFinder/Domain/LocaleInfo.swift`**

```swift
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
```

- [ ] **Step 7: Rodar e ver passar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS (Smoke + Title + TMDBImage + LocaleInfo).

- [ ] **Step 8: Commit**

```bash
git add FilmFinder/Domain FilmFinderTests
git commit -m "feat(ios): add unified Title domain model, TMDB image URLs and locale info"
```

---

### Task 3: Cliente HTTP e serviço de recomendações

**Files:**
- Create: `FilmFinder/Core/API/APIConfig.swift`, `APIError.swift`, `APIClient.swift`
- Create: `FilmFinderTests/Support/MockURLProtocol.swift`
- Test: `FilmFinderTests/APIClientTests.swift`

**Interfaces:**
- Consumes: `RecommendationRequest`, `RecommendationsResponse`, `Title` (Task 2)
- Produces:
  - `struct APIConfig: Sendable, Equatable { baseURL: URL; devKey: String; init(baseURL:devKey:); init(infoDictionary: [String: Any]?) throws; static func live() throws -> APIConfig }`
  - `enum APIError: Error, Equatable, Sendable { case unauthorized, quotaExceeded, serviceUnavailable, offline, invalidResponse; case invalidInput(String); case server(String) }`
  - `protocol RecommendationService: Sendable { func recommend(_ request: RecommendationRequest) async throws -> [Title] }`
  - `struct APIClient: RecommendationService { init(config: APIConfig, session: URLSession = .shared) }`

- [ ] **Step 1: Criar `FilmFinderTests/Support/MockURLProtocol.swift`**

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

extension URLRequest {
    /// `URLProtocol` recebe o corpo como stream, não em `httpBody`.
    func bodyData() -> Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

func httpResponse(_ url: URL, status: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}
```

- [ ] **Step 2: Escrever os testes que falham — `FilmFinderTests/APIClientTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

@Suite(.serialized) struct APIClientTests {
    private let config = APIConfig(baseURL: URL(string: "https://api.example.com")!, devKey: "secret")
    private let request = RecommendationRequest(
        query: "algo leve", mediaType: .movie, excludeTmdbIds: [1, 2], locale: "pt-BR", region: "BR"
    )

    private func client() -> APIClient { APIClient(config: config, session: MockURLProtocol.session()) }

    private func errorBody(_ code: String, _ message: String) -> Data {
        Data(#"{"error":{"code":"\#(code)","message":"\#(message)"}}"#.utf8)
    }

    @Test func sendsExpectedRequestAndDecodesTitles() async throws {
        let body = try fixtureData("recommendations")
        nonisolated(unsafe) var captured: URLRequest?
        MockURLProtocol.handler = { req in
            captured = req
            return (httpResponse(req.url!, status: 200), body)
        }

        let titles = try await client().recommend(request)

        #expect(titles.map(\.tmdbId) == [157336, 70523])
        let sent = try #require(captured)
        #expect(sent.url?.absoluteString == "https://api.example.com/v1/recommendations")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "x-dev-key") == "secret")
        #expect(sent.value(forHTTPHeaderField: "content-type") == "application/json")
        let json = try #require(JSONSerialization.jsonObject(with: try #require(sent.bodyData())) as? [String: Any])
        #expect(json["query"] as? String == "algo leve")
        #expect(json["mediaType"] as? String == "movie")
        #expect(json["excludeTmdbIds"] as? [Int] == [1, 2])
        #expect(json["locale"] as? String == "pt-BR")
        #expect(json["region"] as? String == "BR")
    }

    @Test func mapsHTTPStatusToAPIError() async {
        let cases: [(Int, Data, APIError)] = [
            (401, errorBody("unauthorized", "no"), .unauthorized),
            (402, errorBody("quota_exceeded", "limit"), .quotaExceeded),
            (503, errorBody("ai_unavailable", "down"), .serviceUnavailable),
            (400, errorBody("invalid_input", "query too long"), .invalidInput("query too long")),
            (500, errorBody("internal", "boom"), .server("boom")),
            (502, Data("<html>bad gateway</html>".utf8), .server("HTTP 502")),
        ]
        for (status, body, expected) in cases {
            MockURLProtocol.handler = { req in (httpResponse(req.url!, status: status), body) }
            await #expect(throws: expected, "status \(status)") {
                try await client().recommend(request)
            }
        }
    }

    @Test func mapsConnectivityFailuresToOffline() async {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed] {
            MockURLProtocol.handler = { _ in throw URLError(code) }
            await #expect(throws: APIError.offline) { try await client().recommend(request) }
        }
    }

    @Test func mapsTimeoutToServiceUnavailable() async {
        MockURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: APIError.serviceUnavailable) { try await client().recommend(request) }
    }

    @Test func malformedSuccessBodyIsInvalidResponse() async {
        MockURLProtocol.handler = { req in (httpResponse(req.url!, status: 200), Data("{}".utf8)) }
        await #expect(throws: APIError.invalidResponse) { try await client().recommend(request) }
    }
}

@Suite struct APIConfigTests {
    @Test func readsInfoDictionary() throws {
        let config = try APIConfig(infoDictionary: ["APIBaseURL": "https://api.example.com", "DevAPIKey": "k"])
        #expect(config.baseURL.absoluteString == "https://api.example.com")
        #expect(config.devKey == "k")
    }

    @Test func rejectsMissingOrEmptyValues() {
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: nil) }
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: ["APIBaseURL": "https://a.b", "DevAPIKey": ""]) }
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: ["APIBaseURL": "not a url", "DevAPIKey": "k"]) }
    }
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/APIClientTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'APIConfig' in scope`.

- [ ] **Step 4: Criar `FilmFinder/Core/API/APIConfig.swift`**

```swift
import Foundation

struct APIConfig: Sendable, Equatable {
    let baseURL: URL
    let devKey: String

    enum ConfigError: Error, Equatable {
        case missing(String)
    }

    init(baseURL: URL, devKey: String) {
        self.baseURL = baseURL
        self.devKey = devKey
    }

    init(infoDictionary: [String: Any]?) throws {
        guard let rawURL = infoDictionary?["APIBaseURL"] as? String,
              let url = URL(string: rawURL), url.scheme == "https", url.host != nil
        else { throw ConfigError.missing("APIBaseURL") }
        guard let key = infoDictionary?["DevAPIKey"] as? String, !key.isEmpty
        else { throw ConfigError.missing("DevAPIKey") }
        self.init(baseURL: url, devKey: key)
    }

    static func live() throws -> APIConfig {
        try APIConfig(infoDictionary: Bundle.main.infoDictionary)
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Core/API/APIError.swift`**

```swift
import Foundation

enum APIError: Error, Equatable, Sendable {
    case unauthorized
    case quotaExceeded
    case serviceUnavailable
    case offline
    case invalidResponse
    case invalidInput(String)
    case server(String)
}

protocol RecommendationService: Sendable {
    func recommend(_ request: RecommendationRequest) async throws -> [Title]
}
```

- [ ] **Step 6: Criar `FilmFinder/Core/API/APIClient.swift`**

```swift
import Foundation

struct APIClient: RecommendationService {
    let config: APIConfig
    let session: URLSession

    init(config: APIConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func recommend(_ request: RecommendationRequest) async throws -> [Title] {
        var urlRequest = URLRequest(url: config.baseURL.appending(path: "v1/recommendations"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 45
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(config.devKey, forHTTPHeaderField: "x-dev-key")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw Self.map(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.map(status: http.statusCode, body: data)
        }
        do {
            return try JSONDecoder().decode(RecommendationsResponse.self, from: data).titles
        } catch {
            throw APIError.invalidResponse
        }
    }

    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable { let code: String; let message: String }
        let error: Body
    }

    private static func map(status: Int, body: Data) -> APIError {
        let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: body))?.error.message
        switch status {
        case 401: return .unauthorized
        case 402: return .quotaExceeded
        case 503: return .serviceUnavailable
        case 400: return .invalidInput(message ?? "Invalid request")
        default: return .server(message ?? "HTTP \(status)")
        }
    }

    private static func map(_ error: URLError) -> Error {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return APIError.offline
        case .timedOut:
            return APIError.serviceUnavailable
        case .cancelled:
            return CancellationError()
        default:
            return APIError.server(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 7: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS.

- [ ] **Step 8: Verificação de contrato contra o Worker real** (única chamada paga desta task; ~US$0,001)

Run:
```bash
bash -c 'set -a; . backend/.dev.vars; set +a; curl -s -m 45 https://filmfinder-api-dev.andrefw483.workers.dev/v1/recommendations -H "content-type: application/json" -H "x-dev-key: $DEV_API_KEY" -d "{\"query\":\"comédia leve\",\"mediaType\":\"movie\",\"locale\":\"pt-BR\",\"region\":\"BR\"}" > /tmp/real-response.json'; python3 - <<'EOF'
import json
d = json.load(open('/tmp/real-response.json'))
t = d['titles'][0]
expected = {'tmdbId','mediaType','title','originalTitle','year','overview','posterPath','backdropPath','rating','runtimeMinutes','seasons','genres','reason','providers'}
print('campos extras/faltando:', set(t) ^ expected)
print('providers:', sorted(t['providers']))
EOF
```
Expected: `campos extras/faltando: set()` e providers `['buy', 'flatrate', 'free', 'link', 'region', 'rent']`. Se houver diferença, ajuste `Title`/`Providers` e a fixture antes de seguir.

- [ ] **Step 9: Commit**

```bash
git add FilmFinder/Core FilmFinderTests
git commit -m "feat(ios): add API client, config and error mapping for the recommendations endpoint"
```

---

### Task 4: Biblioteca em SwiftData

**Files:**
- Create: `FilmFinder/Data/LibraryItem.swift`, `FilmFinder/Data/LibraryStore.swift`
- Create: `FilmFinderTests/Support/LibraryHarness.swift`
- Test: `FilmFinderTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: `Title`, `MediaType` (Task 2)
- Produces:
  - `@Model final class LibraryItem { libraryKey: String; tmdbId: Int; mediaTypeRaw: String; snapshotData: Data; isFavorite, isWatched, inHistory: Bool; recommendedAt: Date; init(title: Title, recommendedAt: Date = Date()); var mediaType: MediaType; var snapshot: Title?; func updateSnapshot(_ title: Title) }`
  - `@MainActor final class LibraryStore { static let maxExcluded = 200; init(context: ModelContext); func item(for: Title) -> LibraryItem?; @discardableResult func upsert(_ title: Title) -> LibraryItem; func recordRecommended(_ titles: [Title]); func markShown(_ title: Title); func setFavorite(_ title: Title, _ value: Bool); func setWatched(_ title: Title, _ value: Bool); func removeFromHistory(_ title: Title); func clearHistory(); func excludedIDs(for mediaType: MediaType) -> [Int]; func save() }`
  - Teste: `@MainActor struct LibraryHarness { container; store; var items: [LibraryItem] }`

- [ ] **Step 1: Criar `FilmFinderTests/Support/LibraryHarness.swift`**

```swift
import Foundation
import SwiftData
@testable import FilmFinder

/// Container em memória; o `container` precisa ficar vivo enquanto o `store` é usado.
@MainActor
struct LibraryHarness {
    let container: ModelContainer
    let store: LibraryStore

    init() throws {
        container = try ModelContainer(
            for: LibraryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = LibraryStore(context: container.mainContext)
    }

    var items: [LibraryItem] {
        (try? container.mainContext.fetch(FetchDescriptor<LibraryItem>())) ?? []
    }

    func item(_ id: String) -> LibraryItem? {
        items.first { $0.libraryKey == id }
    }
}
```

- [ ] **Step 2: Escrever os testes que falham — `FilmFinderTests/LibraryStoreTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LibraryStoreTests {
    @Test func recordRecommendedUpsertsWithoutTouchingHistory() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 1), .sample(id: 2)])
        h.store.recordRecommended([.sample(id: 1)])

        #expect(h.items.count == 2)
        #expect(h.items.allSatisfy { !$0.inHistory && !$0.isFavorite && !$0.isWatched })
    }

    @Test func sameTmdbIdWithDifferentMediaTypeAreDistinctItems() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 5, type: .movie), .sample(id: 5, type: .tv)])
        #expect(h.items.count == 2)
    }

    @Test func markShownAddsToHistoryOnce() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.markShown(title)
        let first = try #require(h.item(title.id)).recommendedAt
        h.store.markShown(title)

        let item = try #require(h.item(title.id))
        #expect(item.inHistory)
        #expect(item.recommendedAt == first)
        #expect(h.items.count == 1)
    }

    @Test func favoriteAndWatchedAreIndependentFlags() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        h.store.setWatched(title, true)
        h.store.setFavorite(title, false)

        let item = try #require(h.item(title.id))
        #expect(!item.isFavorite)
        #expect(item.isWatched)
    }

    @Test func removeFromHistoryKeepsTheItemExcluded() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.markShown(title)
        h.store.removeFromHistory(title)

        #expect(try #require(h.item(title.id)).inHistory == false)
        #expect(h.store.excludedIDs(for: .movie) == [1])
    }

    @Test func clearHistoryOnlyClearsTheHistoryFlag() throws {
        let h = try LibraryHarness()
        h.store.markShown(.sample(id: 1))
        h.store.markShown(.sample(id: 2))
        h.store.setFavorite(.sample(id: 2), true)
        h.store.clearHistory()

        #expect(h.items.allSatisfy { !$0.inHistory })
        #expect(h.items.count == 2)
        #expect(try #require(h.item("movie-2")).isFavorite)
    }

    @Test func upsertRefreshesTheSnapshotButKeepsFlags() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1, title: "Old"), true)
        h.store.recordRecommended([.sample(id: 1, title: "New")])

        let item = try #require(h.item("movie-1"))
        #expect(item.isFavorite)
        #expect(item.snapshot?.title == "New")
    }

    @Test func excludedIDsAreFilteredByMediaType() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 1, type: .movie), .sample(id: 2, type: .tv)])
        #expect(h.store.excludedIDs(for: .movie) == [1])
        #expect(h.store.excludedIDs(for: .tv) == [2])
    }

    @Test func excludedIDsAreCappedWithFavoritesAndWatchedFirst() throws {
        let h = try LibraryHarness()
        for i in 0..<205 {
            let item = h.store.upsert(.sample(id: 100 + i))
            item.recommendedAt = Date(timeIntervalSince1970: 1_000_000 + Double(i))
        }
        let pinned = h.store.upsert(.sample(id: 1))
        pinned.isFavorite = true
        pinned.recommendedAt = Date(timeIntervalSince1970: 1)
        h.store.save()

        let ids = h.store.excludedIDs(for: .movie)
        #expect(ids.count == LibraryStore.maxExcluded)
        #expect(ids.first == 1)
        #expect(ids[1] == 304)            // mais recente depois dos fixados
        #expect(!ids.contains(100))       // os mais antigos caem fora do teto
    }
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/LibraryStoreTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'LibraryStore' in scope`.

- [ ] **Step 4: Criar `FilmFinder/Data/LibraryItem.swift`**

```swift
import Foundation
import SwiftData

@Model
final class LibraryItem {
    var libraryKey: String = ""
    var tmdbId: Int = 0
    var mediaTypeRaw: String = MediaType.movie.rawValue
    var snapshotData: Data = Data()
    var isFavorite: Bool = false
    var isWatched: Bool = false
    var inHistory: Bool = false
    var recommendedAt: Date = Date()

    init(title: Title, recommendedAt: Date = Date()) {
        libraryKey = title.id
        tmdbId = title.tmdbId
        mediaTypeRaw = title.mediaType.rawValue
        snapshotData = (try? JSONEncoder().encode(title)) ?? Data()
        self.recommendedAt = recommendedAt
    }

    var mediaType: MediaType { MediaType(rawValue: mediaTypeRaw) ?? .movie }

    var snapshot: Title? { try? JSONDecoder().decode(Title.self, from: snapshotData) }

    func updateSnapshot(_ title: Title) {
        snapshotData = (try? JSONEncoder().encode(title)) ?? snapshotData
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Data/LibraryStore.swift`**

```swift
import Foundation
import SwiftData

@MainActor
final class LibraryStore {
    /// Teto de ids enviados ao backend (`excludeTmdbIds`).
    static let maxExcluded = 200

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func item(for title: Title) -> LibraryItem? {
        fetch(key: title.id)
    }

    @discardableResult
    func upsert(_ title: Title) -> LibraryItem {
        if let existing = fetch(key: title.id) {
            existing.updateSnapshot(title)
            return existing
        }
        let created = LibraryItem(title: title)
        context.insert(created)
        return created
    }

    /// Grava os títulos como "já recomendados" (para exclusão futura); não entram no Histórico.
    func recordRecommended(_ titles: [Title]) {
        titles.forEach { upsert($0) }
        save()
    }

    /// O título foi exibido ao usuário: entra no Histórico (uma vez).
    func markShown(_ title: Title) {
        let item = upsert(title)
        if !item.inHistory {
            item.inHistory = true
            item.recommendedAt = Date()
        }
        save()
    }

    func setFavorite(_ title: Title, _ value: Bool) {
        upsert(title).isFavorite = value
        save()
    }

    func setWatched(_ title: Title, _ value: Bool) {
        upsert(title).isWatched = value
        save()
    }

    func removeFromHistory(_ title: Title) {
        fetch(key: title.id)?.inHistory = false
        save()
    }

    func clearHistory() {
        let descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.inHistory })
        for item in (try? context.fetch(descriptor)) ?? [] { item.inHistory = false }
        save()
    }

    /// Ids do mesmo tipo de mídia: favoritos e assistidos primeiro, depois os mais recentes; máx. 200.
    func excludedIDs(for mediaType: MediaType) -> [Int] {
        let raw = mediaType.rawValue
        let descriptor = FetchDescriptor<LibraryItem>(
            predicate: #Predicate { $0.mediaTypeRaw == raw },
            sortBy: [SortDescriptor(\.recommendedAt, order: .reverse)]
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let pinned = items.filter { $0.isFavorite || $0.isWatched }
        let rest = items.filter { !($0.isFavorite || $0.isWatched) }
        return Array((pinned + rest).prefix(Self.maxExcluded)).map(\.tmdbId)
    }

    func save() {
        try? context.save()
    }

    private func fetch(key: String) -> LibraryItem? {
        var descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.libraryKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS.

- [ ] **Step 7: Commit**

```bash
git add FilmFinder/Data FilmFinderTests
git commit -m "feat(ios): add SwiftData library store for history, favorites, watched and exclusions"
```

---

### Task 5: Importador dos dados do app antigo (UserDefaults → SwiftData)

**Files:**
- Create: `FilmFinder/Data/LegacyImporter.swift`
- Test: `FilmFinderTests/LegacyImporterTests.swift`

**Interfaces:**
- Consumes: `LibraryStore`, `LibraryItem`, `Title`, `Providers`, `LocaleInfo` (Tasks 2 e 4)
- Produces: `@MainActor struct LegacyImporter { static let doneKey = "legacyImportDone.v1"; static let legacyKeys: [String]; init(defaults: UserDefaults, store: LibraryStore, region: String = LocaleInfo().region); @discardableResult func runIfNeeded() -> Int }` — devolve o número de itens importados.

Formato legado (de `Model/History.swift`, `FilmData.swift`, `SerieData.swift`): quatro chaves em `UserDefaults` (`allContent`, `favorites`, `watched`, `history`), cada uma um `[WatchedContent]` codificado em JSON; `WatchedContent = { id, date (segundos desde 2001), content: { "filme": FilmData } | { "serie": SerieData } }`; `FilmData/SerieData = { id, idFilme, title, image, releaseDate, originalTitle, duration, plot, rating, favorite, watched }`.

- [ ] **Step 1: Escrever os testes que falham — `FilmFinderTests/LegacyImporterTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LegacyImporterTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "legacy-\(UUID().uuidString)")!
    }

    private func movie(_ id: Int, title: String = "Avatar", favorite: Bool = false, watched: Bool = false, date: Double = 700_000_000) -> String {
        """
        {"id":"A1B2C3D4-0000-0000-0000-000000000001","date":\(date),"content":{"filme":{"id":"A1B2C3D4-0000-0000-0000-000000000002","idFilme":\(id),"title":"\(title)","image":"/abc.jpg","releaseDate":"2009-12-15","originalTitle":"2009-12-15","duration":162,"plot":"Plot","rating":7.5,"favorite":\(favorite),"watched":\(watched)}}}
        """
    }

    private func serie(_ id: Int, title: String = "Dark") -> String {
        """
        {"id":"A1B2C3D4-0000-0000-0000-000000000003","date":700000000,"content":{"serie":{"id":"A1B2C3D4-0000-0000-0000-000000000004","idFilme":\(id),"title":"\(title)","image":"","releaseDate":"2017-12-01","originalTitle":null,"duration":3,"plot":"Plot","rating":8.4,"favorite":false,"watched":false}}}
        """
    }

    private func set(_ defaults: UserDefaults, _ key: String, _ items: [String]) {
        defaults.set(Data("[\(items.joined(separator: ","))]".utf8), forKey: key)
    }

    @Test func importsAllContentWithFlagsFromListsAndItems() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1), movie(2), serie(3)])
        set(defaults, "favorites", [movie(1, favorite: true)])
        set(defaults, "watched", [movie(2, watched: true)])
        set(defaults, "history", [movie(1), serie(3)])

        let count = LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        #expect(count == 3)
        #expect(h.items.count == 3)
        let one = try #require(h.item("movie-1"))
        #expect(one.isFavorite && !one.isWatched && one.inHistory)
        let two = try #require(h.item("movie-2"))
        #expect(two.isWatched && !two.isFavorite && !two.inHistory)
        #expect(try #require(h.item("tv-3")).inHistory)
    }

    @Test func itemsOnlyPresentInFavoritesOrWatchedListsAreStillImported() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "favorites", [movie(7, favorite: true)])
        set(defaults, "watched", [movie(8, watched: true)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        #expect(try #require(h.item("movie-7")).isFavorite)
        #expect(try #require(h.item("movie-8")).isWatched)
    }

    @Test func mapsLegacyFieldsToTitle() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1), serie(3)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        let film = try #require(try #require(h.item("movie-1")).snapshot)
        #expect(film.title == "Avatar")
        #expect(film.originalTitle == "Avatar")        // o campo legado guardava a data de lançamento
        #expect(film.year == 2009)
        #expect(film.posterPath == "/abc.jpg")
        #expect(film.runtimeMinutes == 162)
        #expect(film.seasons == nil)
        #expect(film.providers == .empty(region: "BR"))

        let show = try #require(try #require(h.item("tv-3")).snapshot)
        #expect(show.seasons == 3)                      // `duration` de série era o nº de temporadas
        #expect(show.runtimeMinutes == nil)
        #expect(show.posterPath == nil)                 // imagem vazia
    }

    @Test func keepsTheLegacyDate() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1, date: 700_000_000)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        let date = try #require(h.item("movie-1")).recommendedAt
        #expect(date == Date(timeIntervalSinceReferenceDate: 700_000_000))
    }

    @Test func runsOnlyOnceAndRemovesLegacyKeys() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1)])

        let importer = LegacyImporter(defaults: defaults, store: h.store, region: "BR")
        #expect(importer.runIfNeeded() == 1)
        #expect(importer.runIfNeeded() == 0)
        #expect(h.items.count == 1)
        #expect(LegacyImporter.legacyKeys.allSatisfy { defaults.object(forKey: $0) == nil })
        #expect(defaults.bool(forKey: LegacyImporter.doneKey))
    }

    @Test func skipsCorruptElementsButImportsTheRest() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [#"{"nonsense":true}"#, movie(1)])

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 1)
    }

    @Test func noLegacyDataJustMarksDone() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 0)
        #expect(defaults.bool(forKey: LegacyImporter.doneKey))
    }

    @Test func undecodableDataIsKeptInsteadOfDeleted() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "allContent")

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 0)
        #expect(defaults.data(forKey: "allContent") != nil)
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/LegacyImporterTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'LegacyImporter' in scope`.

- [ ] **Step 3: Criar `FilmFinder/Data/LegacyImporter.swift`**

```swift
import Foundation

/// Converte os dados do app antigo (UserDefaults) para a biblioteca SwiftData, uma única vez.
@MainActor
struct LegacyImporter {
    static let doneKey = "legacyImportDone.v1"
    static let legacyKeys = ["allContent", "favorites", "watched", "history"]

    let defaults: UserDefaults
    let store: LibraryStore
    let region: String

    init(defaults: UserDefaults, store: LibraryStore, region: String = LocaleInfo().region) {
        self.defaults = defaults
        self.store = store
        self.region = region
    }

    @discardableResult
    func runIfNeeded() -> Int {
        guard !defaults.bool(forKey: Self.doneKey) else { return 0 }
        defaults.set(true, forKey: Self.doneKey)

        let hasLegacyData = Self.legacyKeys.contains { defaults.data(forKey: $0) != nil }
        guard hasLegacyData else { return 0 }

        var merged: [String: Merged] = [:]
        absorb(decodeList("allContent"), into: &merged)
        absorb(decodeList("favorites"), favorite: true, into: &merged)
        absorb(decodeList("watched"), watched: true, into: &merged)
        absorb(decodeList("history"), inHistory: true, into: &merged)

        for entry in merged.values {
            let item = store.upsert(entry.title)
            item.isFavorite = entry.favorite
            item.isWatched = entry.watched
            item.inHistory = entry.inHistory
            item.recommendedAt = entry.date
        }
        store.save()

        // Só apaga o legado se algo foi realmente importado.
        if !merged.isEmpty {
            Self.legacyKeys.forEach(defaults.removeObject(forKey:))
        }
        return merged.count
    }

    // MARK: - Mesclagem

    private struct Merged {
        var title: Title
        var date: Date
        var favorite: Bool
        var watched: Bool
        var inHistory: Bool
    }

    private func absorb(
        _ entries: [LegacyEntry],
        favorite: Bool = false,
        watched: Bool = false,
        inHistory: Bool = false,
        into merged: inout [String: Merged]
    ) {
        for entry in entries {
            let title = makeTitle(from: entry)
            let flags = entry.item
            if var existing = merged[title.id] {
                existing.favorite = existing.favorite || favorite || flags.favorite
                existing.watched = existing.watched || watched || flags.watched
                existing.inHistory = existing.inHistory || inHistory
                existing.date = max(existing.date, entry.date)
                merged[title.id] = existing
            } else {
                merged[title.id] = Merged(
                    title: title,
                    date: entry.date,
                    favorite: favorite || flags.favorite,
                    watched: watched || flags.watched,
                    inHistory: inHistory
                )
            }
        }
    }

    private func makeTitle(from entry: LegacyEntry) -> Title {
        let item = entry.item
        let type = entry.mediaType
        return Title(
            tmdbId: Int(item.idFilme),
            mediaType: type,
            title: item.title,
            originalTitle: item.title,
            year: Int(item.releaseDate.prefix(4)),
            overview: item.plot,
            posterPath: item.image.isEmpty ? nil : item.image,
            backdropPath: nil,
            rating: item.rating,
            runtimeMinutes: type == .movie && item.duration > 0 ? item.duration : nil,
            seasons: type == .tv ? item.duration : nil,
            genres: [],
            reason: "",
            providers: .empty(region: region)
        )
    }

    // MARK: - Decodificação do formato legado

    private func decodeList(_ key: String) -> [LegacyEntry] {
        guard let data = defaults.data(forKey: key),
              let lossy = try? JSONDecoder().decode([Lossy<LegacyEntry>].self, from: data)
        else { return [] }
        return lossy.compactMap(\.value)
    }

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    private struct LegacyItem: Decodable {
        let idFilme: Int32
        let title: String
        let image: String
        let releaseDate: String
        let duration: Int
        let plot: String
        let rating: Double
        let favorite: Bool
        let watched: Bool
    }

    private struct LegacyEntry: Decodable {
        let date: Date
        private let content: Content

        private struct Content: Decodable {
            let filme: LegacyItem?
            let serie: LegacyItem?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(Date.self, forKey: .date)
            content = try container.decode(Content.self, forKey: .content)
            guard content.filme != nil || content.serie != nil else {
                throw DecodingError.dataCorruptedError(forKey: .content, in: container, debugDescription: "Empty content")
            }
        }

        private enum CodingKeys: String, CodingKey { case date, content }

        var mediaType: MediaType { content.filme != nil ? .movie : .tv }
        var item: LegacyItem { content.filme ?? content.serie! }
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS.

- [ ] **Step 5: Commit**

```bash
git add FilmFinder/Data/LegacyImporter.swift FilmFinderTests
git commit -m "feat(ios): import legacy UserDefaults history/favorites/watched into SwiftData"
```

---

### Task 6: Montador de consulta por categorias e `ResultsModel` (buffer)

**Files:**
- Create: `FilmFinder/Features/Search/CategoryQueryBuilder.swift`, `FilmFinder/Features/Results/ResultsModel.swift`
- Test: `FilmFinderTests/CategoryQueryBuilderTests.swift`, `FilmFinderTests/ResultsModelTests.swift`

**Interfaces:**
- Consumes: `RecommendationService`, `RecommendationRequest`, `APIError` (Task 3); `LibraryStore` (Task 4); `LocaleInfo`, `Title`, `MediaType` (Task 2)
- Produces:
  - `enum CategoryQueryBuilder { static func query(mediaType: MediaType, moods: [String], genres: [String], themes: [String]) -> String? }` (máx. 500 caracteres; `nil` se nada selecionado)
  - `@MainActor @Observable final class ResultsModel { enum Phase: Equatable { idle, loading, loaded, empty, failed(APIError) }; static let visibleCount = 3; let mediaType; let query; private(set) var phase, visible, buffer, isSwapping, swapError: APIError?; init(mediaType:query:service:store:localeInfo:); func load() async; func retry() async; func swap(_ title: Title) async }`

- [ ] **Step 1: Escrever os testes do montador — `FilmFinderTests/CategoryQueryBuilderTests.swift`**

```swift
import Testing
@testable import FilmFinder

@Suite struct CategoryQueryBuilderTests {
    @Test func returnsNilWhenNothingIsSelected() {
        #expect(CategoryQueryBuilder.query(mediaType: .movie, moods: [], genres: [], themes: []) == nil)
    }

    @Test func buildsOnlyTheSelectedParts() {
        let q = CategoryQueryBuilder.query(mediaType: .movie, moods: [], genres: ["Drama", "Romance"], themes: [])
        #expect(q == "I want to watch a movie. Genres: Drama, Romance.")
    }

    @Test func buildsAllPartsForSeries() {
        let q = CategoryQueryBuilder.query(mediaType: .tv, moods: ["Relaxado"], genres: ["Suspense"], themes: ["Crime", "Enigmas"])
        #expect(q == "I want to watch a TV series. Mood: Relaxado. Genres: Suspense. Themes: Crime, Enigmas.")
    }

    @Test func neverExceedsTheBackendLimit() {
        let many = (0..<80).map { "Categoria número \($0)" }
        let q = CategoryQueryBuilder.query(mediaType: .movie, moods: many, genres: many, themes: many)
        #expect((q?.count ?? 0) <= 500)
    }
}
```

- [ ] **Step 2: Escrever os testes do modelo — `FilmFinderTests/ResultsModelTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

final class FakeService: RecommendationService, @unchecked Sendable {
    var results: [Result<[Title], APIError>]
    private(set) var requests: [RecommendationRequest] = []

    init(_ results: [Result<[Title], APIError>]) { self.results = results }

    func recommend(_ request: RecommendationRequest) async throws -> [Title] {
        requests.append(request)
        guard !results.isEmpty else { return [] }
        return try results.removeFirst().get()
    }
}

private func titles(_ ids: ClosedRange<Int>, type: MediaType = .movie) -> [Title] {
    ids.map { Title.sample(id: $0, type: type, title: "T\($0)") }
}

@MainActor
@Suite struct ResultsModelTests {
    private func makeModel(_ service: FakeService, harness: LibraryHarness, type: MediaType = .movie) -> ResultsModel {
        ResultsModel(
            mediaType: type, query: "algo leve", service: service, store: harness.store,
            localeInfo: LocaleInfo(locale: "pt-BR", region: "BR")
        )
    }

    @Test func loadShowsThreeAndBuffersTheRest() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])
        let model = makeModel(service, harness: h)

        await model.load()

        #expect(model.phase == .loaded)
        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.buffer.count == 9)
        #expect(service.requests.count == 1)
    }

    @Test func sendsLocaleRegionAndExclusionsOfTheSameMediaType() async throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 50, type: .movie), .sample(id: 60, type: .tv)])
        let service = FakeService([.success(titles(1...5))])

        await makeModel(service, harness: h).load()

        let sent = try #require(service.requests.first)
        #expect(sent.query == "algo leve")
        #expect(sent.mediaType == .movie)
        #expect(sent.locale == "pt-BR")
        #expect(sent.region == "BR")
        #expect(sent.excludeTmdbIds == [50])
    }

    @Test func recordsAllTitlesButOnlyShownOnesEnterHistory() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])

        await makeModel(service, harness: h).load()

        #expect(h.items.count == 12)
        #expect(h.items.filter(\.inHistory).count == 3)
        #expect(h.store.excludedIDs(for: .movie).count == 12)
    }

    @Test func swapUsesTheBufferWithoutANewRequest() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[1])

        #expect(model.visible.map(\.tmdbId) == [1, 4, 3])
        #expect(model.buffer.count == 8)
        #expect(service.requests.count == 1)
        #expect(try #require(h.item("movie-4")).inHistory)
    }

    @Test func swapWithEmptyBufferFetchesAgainExcludingRecordedTitles() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .success(titles(10...14))])
        let model = makeModel(service, harness: h)
        await model.load()
        #expect(model.buffer.isEmpty)

        await model.swap(model.visible[0])

        #expect(service.requests.count == 2)
        #expect(Set(service.requests[1].excludeTmdbIds) == [1, 2, 3])
        #expect(model.visible.map(\.tmdbId) == [10, 2, 3])
        #expect(model.buffer.map(\.tmdbId) == [11, 12, 13, 14])
    }

    @Test func swapFailureKeepsTheVisibleTitlesAndReportsTheError() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .failure(.offline)])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[0])

        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.swapError == .offline)
        #expect(model.phase == .loaded)
    }

    @Test func swapWithNothingNewLeavesTheCardInPlace() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .success([])])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[0])

        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.swapError == nil)
    }

    @Test func emptyResponseIsTheEmptyPhase() async throws {
        let h = try LibraryHarness()
        let model = makeModel(FakeService([.success([])]), harness: h)
        await model.load()
        #expect(model.phase == .empty)
    }

    @Test func failureThenRetrySucceeds() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.failure(.serviceUnavailable), .success(titles(1...4))])
        let model = makeModel(service, harness: h)

        await model.load()
        #expect(model.phase == .failed(.serviceUnavailable))

        await model.retry()
        #expect(model.phase == .loaded)
        #expect(model.visible.count == 3)
    }

    @Test func loadRunsOnlyOnce() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...5)), .success(titles(6...9))])
        let model = makeModel(service, harness: h)

        await model.load()
        await model.load()

        #expect(service.requests.count == 1)
    }
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/ResultsModelTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'ResultsModel' in scope`.

- [ ] **Step 4: Criar `FilmFinder/Features/Search/CategoryQueryBuilder.swift`**

```swift
import Foundation

enum CategoryQueryBuilder {
    private static let maxLength = 500

    /// Monta o pedido em linguagem natural a partir das categorias escolhidas.
    /// Os nomes das categorias vão como estão (o modelo entende português e inglês).
    static func query(mediaType: MediaType, moods: [String], genres: [String], themes: [String]) -> String? {
        guard !(moods.isEmpty && genres.isEmpty && themes.isEmpty) else { return nil }
        var parts = ["I want to watch \(mediaType == .movie ? "a movie" : "a TV series")."]
        if !moods.isEmpty { parts.append("Mood: \(moods.joined(separator: ", ")).") }
        if !genres.isEmpty { parts.append("Genres: \(genres.joined(separator: ", ")).") }
        if !themes.isEmpty { parts.append("Themes: \(themes.joined(separator: ", ")).") }
        return String(parts.joined(separator: " ").prefix(maxLength))
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Features/Results/ResultsModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ResultsModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(APIError)
    }

    static let visibleCount = 3

    let mediaType: MediaType
    let query: String

    private(set) var phase: Phase = .idle
    private(set) var visible: [Title] = []
    private(set) var buffer: [Title] = []
    private(set) var isSwapping = false
    private(set) var swapError: APIError?

    private let service: any RecommendationService
    private let store: LibraryStore
    private let localeInfo: LocaleInfo

    init(
        mediaType: MediaType,
        query: String,
        service: any RecommendationService,
        store: LibraryStore,
        localeInfo: LocaleInfo = LocaleInfo()
    ) {
        self.mediaType = mediaType
        self.query = query
        self.service = service
        self.store = store
        self.localeInfo = localeInfo
    }

    /// Busca inicial. Só age no estado `.idle` (a view pode chamar de novo ao reaparecer).
    func load() async {
        guard phase == .idle else { return }
        phase = .loading
        do {
            let titles = try await fetch()
            guard !titles.isEmpty else {
                phase = .empty
                return
            }
            visible = Array(titles.prefix(Self.visibleCount))
            buffer = Array(titles.dropFirst(Self.visibleCount))
            visible.forEach { store.markShown($0) }
            phase = .loaded
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(Self.apiError(from: error))
        }
    }

    func retry() async {
        phase = .idle
        await load()
    }

    /// Troca um card pelo próximo do buffer; sem buffer, faz uma nova busca (consome cota no servidor).
    func swap(_ title: Title) async {
        guard !isSwapping, let index = visible.firstIndex(of: title) else { return }
        isSwapping = true
        swapError = nil
        defer { isSwapping = false }

        if buffer.isEmpty {
            do {
                buffer = try await fetch()
            } catch is CancellationError {
                return
            } catch {
                swapError = Self.apiError(from: error)
                return
            }
        }
        guard !buffer.isEmpty else { return }
        let next = buffer.removeFirst()
        visible[index] = next
        store.markShown(next)
    }

    private func fetch() async throws -> [Title] {
        let request = RecommendationRequest(
            query: query,
            mediaType: mediaType,
            excludeTmdbIds: store.excludedIDs(for: mediaType),
            locale: localeInfo.locale,
            region: localeInfo.region
        )
        let titles = try await service.recommend(request)
        let onScreen = Set(visible.map(\.id))
        let fresh = titles.filter { !onScreen.contains($0.id) }
        store.recordRecommended(fresh)
        return fresh
    }

    private static func apiError(from error: Error) -> APIError {
        (error as? APIError) ?? .server(error.localizedDescription)
    }
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS.

- [ ] **Step 7: Commit**

```bash
git add FilmFinder/Features FilmFinderTests
git commit -m "feat(ios): add ResultsModel with 3-card buffer and category query builder"
```

---

### Task 7: Fundação da UI — ambiente, app e componentes compartilhados

A partir daqui as tarefas são de interface: a verificação é **compilar** e, nas Tasks 8–11, **ver no simulador**.

**Files:**
- Rename: `FilmFinder/CimemAIApp.swift` → `FilmFinder/App/FilmFinderApp.swift` (reescrito)
- Create: `FilmFinder/App/AppEnvironment.swift`
- Create: `FilmFinder/Features/Shared/PosterImage.swift`, `StarsView.swift`, `ProviderLogos.swift`, `ErrorStateView.swift`, `LoadingStateView.swift`, `CustomDivider.swift`, `MediaType+UI.swift`

**Interfaces:**
- Consumes: `APIClient`, `APIConfig`, `RecommendationService`, `APIError` (Task 3); `LibraryItem` (Task 4); `LegacyImporter`, `LibraryStore` (Tasks 4–5); `Title`, `StreamingProvider`, `TMDBImage` (Task 2)
- Produces:
  - `@MainActor @Observable final class AppEnvironment { let service: any RecommendationService; static func live() -> AppEnvironment }` (injetado com `.environment(_:)`; lido com `@Environment(AppEnvironment.self)`)
  - `PosterImage(path: String?)`, `StarsView(stars: Int, color: Color, size: CGFloat)`, `ProviderLogoView(provider:size:)`, `ProviderLogosRow(providers:)`
  - `enum ErrorKind { noResults, offline, serviceUnavailable, quotaExceeded, generic; init(_ error: APIError) }`, `ErrorStateView(kind: ErrorKind, onRetry: (() -> Void)?)`
  - `LoadingStateView()`, `CustomDivider(color:width:)`
  - `extension MediaType { var pluralName: LocalizedStringKey; var pluralNameString: String }`

- [ ] **Step 1: Mover o ponto de entrada**

Run: `mkdir -p FilmFinder/App && git mv FilmFinder/CimemAIApp.swift FilmFinder/App/FilmFinderApp.swift`

- [ ] **Step 2: Criar `FilmFinder/App/AppEnvironment.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let service: any RecommendationService

    init(service: any RecommendationService) {
        self.service = service
    }

    /// Serviço real; se a configuração estiver ausente, qualquer busca falha com erro explícito.
    static func live() -> AppEnvironment {
        do {
            return AppEnvironment(service: APIClient(config: try APIConfig.live()))
        } catch {
            return AppEnvironment(service: MisconfiguredService())
        }
    }
}

private struct MisconfiguredService: RecommendationService {
    func recommend(_ request: RecommendationRequest) async throws -> [Title] {
        throw APIError.server("Missing API configuration (APIBaseURL / DevAPIKey)")
    }
}
```

- [ ] **Step 3: Reescrever `FilmFinder/App/FilmFinderApp.swift`**

```swift
import SwiftData
import SwiftUI

@main
struct FilmFinderApp: App {
    @State private var environment = AppEnvironment.live()
    private let container: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: LibraryItem.self)
        } catch {
            fatalError("Could not create the library database: \(error)")
        }
        self.container = container
        LegacyImporter(defaults: .standard, store: LibraryStore(context: container.mainContext)).runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            InicialLoading()
                .preferredColorScheme(.dark)
                .environment(environment)
                .modelContainer(container)
        }
    }
}
```

- [ ] **Step 4: Criar `FilmFinder/Features/Shared/PosterImage.swift`**

```swift
import SwiftUI

struct PosterImage: View {
    let path: String?

    var body: some View {
        if let url = TMDBImage.poster(path) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                default:
                    ZStack {
                        Color.cinza2
                        ProgressView()
                    }
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.cinza2
            Image("error")
                .resizable()
                .scaledToFit()
                .padding(24)
        }
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Features/Shared/StarsView.swift`**

```swift
import SwiftUI

struct StarsView: View {
    let stars: Int
    var color: Color = .white
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) / 5")
    }
}
```

- [ ] **Step 6: Criar `FilmFinder/Features/Shared/ProviderLogos.swift`**

```swift
import SwiftUI

struct ProviderLogoView: View {
    let provider: StreamingProvider
    var size: CGFloat = 28

    var body: some View {
        AsyncImage(url: TMDBImage.logo(provider.logoPath)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Color.cinza2
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .accessibilityLabel(provider.name)
    }
}

struct ProviderLogosRow: View {
    let providers: [StreamingProvider]
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 6) {
            ForEach(providers) { provider in
                ProviderLogoView(provider: provider, size: size)
            }
        }
    }
}
```

- [ ] **Step 7: Criar `FilmFinder/Features/Shared/LoadingStateView.swift`** (extraído do `ChatGptView`)

```swift
import SwiftUI

struct LoadingStateView: View {
    var body: some View {
        VStack {
            (Text("Encontrando as opções mais")
                .foregroundColor(Color("branco"))
                + Text(" compatíveis ")
                .foregroundColor(Color("laranja"))
                + Text("com você")
                .foregroundColor(Color("branco")))
                .fontWidth(.expanded)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            LottieView(name: "pipocascertasmesmo", loopMode: .loop, animationSpeed: 2)
                .frame(width: 250, height: 112)
                .scaleEffect(0.8)
                .padding(.bottom, 60)
        }
    }
}
```

- [ ] **Step 8: Criar `FilmFinder/Features/Shared/ErrorStateView.swift`** (substitui o `ErrorView` antigo)

```swift
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
```

- [ ] **Step 9: Criar `FilmFinder/Features/Shared/CustomDivider.swift`** (movido do `HistoryView`)

```swift
import SwiftUI

struct CustomDivider: View {
    let color: Color
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: width)
            .edgesIgnoringSafeArea(.horizontal)
    }
}
```

- [ ] **Step 10: Remover a definição antiga de `CustomDivider` do `FilmFinder/View/HistoryView.swift`** (apagar o `struct CustomDivider: View { ... }` inteiro, linhas ~70–80 do arquivo antigo; a view antiga continua compilando usando o novo).

- [ ] **Step 11: Criar `FilmFinder/Features/Shared/MediaType+UI.swift`**

```swift
import SwiftUI

extension MediaType {
    var pluralName: LocalizedStringKey {
        switch self {
        case .movie: "Filmes"
        case .tv: "Séries"
        }
    }

    var pluralNameString: String {
        switch self {
        case .movie: String(localized: "Filmes")
        case .tv: String(localized: "Séries")
        }
    }
}
```

- [ ] **Step 12: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`. (O código antigo ainda existe e compila; `InicialLoading` continua sendo a raiz.)

- [ ] **Step 13: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): add app environment, SwiftData container wiring and shared UI components"
```

---

### Task 8: Resultados, card, detalhe e streaming

**Files:**
- Create: `FilmFinder/Features/Results/TitleCard.swift`, `FilmFinder/Features/Results/ResultsView.swift`
- Create: `FilmFinder/Features/Detail/TitleDetail.swift`, `FilmFinder/Features/Detail/StreamingSection.swift`

**Interfaces:**
- Consumes: `ResultsModel` (Task 6); `AppEnvironment` (Task 7); `LibraryStore`, `LibraryItem` (Task 4); componentes compartilhados (Task 7); `Title`, `Providers` (Task 2)
- Produces: `ResultsView(mediaType: MediaType, query: String)` (destino de navegação para a busca); `TitleCard(title:)`; `TitleDetail(title:)`; `StreamingSection(providers:)`

- [ ] **Step 1: Criar `FilmFinder/Features/Detail/StreamingSection.swift`**

```swift
import SwiftUI

struct StreamingSection: View {
    let providers: Providers

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Onde assistir")
                .font(.system(size: 18, weight: .semibold))
                .fontWidth(.expanded)
                .foregroundColor(.branco)

            if providers.isEmpty {
                Text("Não disponível em streaming na sua região")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                group("Assinatura", providers.flatrate)
                group("Grátis", providers.free)
                group("Aluguel", providers.rent)
                group("Compra", providers.buy)

                if let link = providers.link {
                    Link(destination: link) {
                        HStack {
                            Text("Ver onde assistir")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.preto)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.laranja)
                        .cornerRadius(14)
                    }
                }
            }

            Text("Dados de streaming: JustWatch")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func group(_ heading: LocalizedStringKey, _ list: [StreamingProvider]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(heading)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(list) { provider in
                            VStack(spacing: 4) {
                                ProviderLogoView(provider: provider, size: 44)
                                Text(provider.name)
                                    .font(.system(size: 10))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 60)
                            }
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Criar `FilmFinder/Features/Detail/TitleDetail.swift`**

```swift
import SwiftData
import SwiftUI

struct TitleDetail: View {
    let title: Title

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [LibraryItem]

    init(title: Title) {
        self.title = title
        let key = title.id
        _items = Query(filter: #Predicate<LibraryItem> { $0.libraryKey == key })
    }

    private var item: LibraryItem? { items.first }
    private var isFavorite: Bool { item?.isFavorite ?? false }
    private var isWatched: Bool { item?.isWatched ?? false }
    private var store: LibraryStore { LibraryStore(context: modelContext) }

    var body: some View {
        ScrollView {
            VStack(spacing: -25) {
                PosterImage(path: title.posterPath)
                    .frame(maxWidth: .infinity)
                    .frame(height: 560)
                    .clipped()

                VStack(alignment: .leading, spacing: 19) {
                    header
                    chips
                    if !title.genres.isEmpty { genres }
                    if !title.reason.isEmpty { reason }
                    Text(title.overview)
                        .font(.system(size: 16))
                        .padding(.horizontal, 30)
                    StreamingSection(providers: title.providers)
                        .padding(.horizontal, 30)
                    Spacer(minLength: 24)
                }
                .padding(.top, 8)
                .background(Color.preto, in: RoundedRectangle(cornerRadius: 28))
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { BackButton() }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.title)
                    .font(.system(size: 24))
                    .foregroundColor(.branco)
                    .fontWeight(.semibold)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StarsView(stars: title.stars, color: .laranja)
            }

            Button {
                store.setFavorite(title, !isFavorite)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 23))
                    .foregroundColor(isFavorite ? .laranja : .branco)
            }
            .accessibilityLabel(isFavorite ? "Remover dos favoritos" : "Favoritar")

            Button {
                store.setWatched(title, !isWatched)
            } label: {
                Image(isWatched ? "Olhozin" : "Olhozin.fill")
                    .resizable()
                    .frame(width: 40, height: 25)
                    .scaledToFit()
            }
            .accessibilityLabel(isWatched ? "Desmarcar como assistido" : "Marcar como assistido")
        }
        .padding(.horizontal, 30)
    }

    private var chips: some View {
        HStack(spacing: 10) {
            if let minutes = title.runtimeMinutes {
                chip { Label("\(minutes) min", systemImage: "clock") }
            }
            if let seasons = title.seasons {
                chip { Text("\(seasons) temporadas") }
            }
            if let year = title.year {
                chip { Text(String(year)) }
            }
            Spacer()
        }
        .padding(.leading, 30)
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(size: 14))
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .overlay(RoundedRectangle(cornerRadius: 10).inset(by: 0.5).stroke(Color.branco, lineWidth: 1))
    }

    private var genres: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(title.genres, id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 13))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.roxo.opacity(0.5), in: Capsule())
                }
            }
            .padding(.horizontal, 30)
        }
    }

    private var reason: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Por que combina")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title.reason)
                .font(.system(size: 16))
                .foregroundColor(.laranja)
        }
        .padding(.horizontal, 30)
    }
}
```

- [ ] **Step 3: Criar `FilmFinder/Features/Results/TitleCard.swift`**

```swift
import SwiftUI

struct TitleCard: View {
    let title: Title

    private let width: CGFloat = 265
    private let height: CGFloat = 400

    var body: some View {
        ZStack {
            PosterImage(path: title.posterPath)
                .frame(width: width, height: height)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.35),
                            .init(color: Color(red: 0.29, green: 0.01, blue: 0.46), location: 0.98),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 17))

            VStack {
                HStack {
                    Spacer()
                    NavigationLink {
                        TitleDetail(title: title)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .preto, radius: 5)
                    }
                }
                .padding()

                Spacer()

                Text(title.title)
                    .font(.system(size: 20))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                StarsView(stars: title.stars)
                    .padding(.bottom, 8)

                if !title.reason.isEmpty {
                    Text(title.reason)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                let highlighted = title.providers.highlighted()
                if !highlighted.isEmpty {
                    HStack(spacing: 8) {
                        Text("Disponível em")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                        ProviderLogosRow(providers: highlighted, size: 24)
                    }
                    .padding(.bottom, 16)
                } else {
                    Spacer().frame(height: 16)
                }
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }
}
```

- [ ] **Step 4: Criar `FilmFinder/Features/Results/ResultsView.swift`**

```swift
import SwiftData
import SwiftUI

struct ResultsView: View {
    let mediaType: MediaType
    let query: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var model: ResultsModel?
    @State private var currentIndex = 0
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingStateView()
            }
        }
        .task {
            if model == nil {
                model = ResultsModel(
                    mediaType: mediaType,
                    query: query,
                    service: environment.service,
                    store: LibraryStore(context: modelContext)
                )
            }
            // `load()` só age em `.idle`: reexecuta com segurança se a task foi cancelada ao navegar.
            await model?.load()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { BackButton() }
            }
        }
    }

    @ViewBuilder
    private func content(_ model: ResultsModel) -> some View {
        switch model.phase {
        case .idle, .loading:
            LoadingStateView()
        case .empty:
            ErrorStateView(kind: .noResults)
        case .failed(let error):
            ErrorStateView(kind: ErrorKind(error)) {
                Task { await model.retry() }
            }
        case .loaded:
            carousel(model)
        }
    }

    private func carousel(_ model: ResultsModel) -> some View {
        let titles = model.visible
        let index = min(currentIndex, max(titles.count - 1, 0))

        return VStack(alignment: .leading, spacing: 16) {
            heading
                .font(.system(size: 24))
                .fontWidth(.expanded)

            ZStack {
                ForEach(Array(titles.enumerated()), id: \.element.id) { position, title in
                    TitleCard(title: title)
                        .scaleEffect(0.9)
                        .opacity(index == position ? 1.0 : 0.5)
                        .scaleEffect(index == position ? 1.2 : 0.8)
                        .offset(x: CGFloat(position - index) * 260 + dragOffset, y: 0)
                }
            }
            .frame(maxWidth: .infinity)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in state = value.translation.width }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        withAnimation {
                            if value.translation.width > threshold {
                                currentIndex = max(0, index - 1)
                            } else if value.translation.width < -threshold {
                                currentIndex = min(titles.count - 1, index + 1)
                            }
                        }
                    }
            )
            .padding()
            .padding(.leading)

            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        guard titles.indices.contains(index) else { return }
                        Task { await model.swap(titles[index]) }
                    } label: {
                        Group {
                            if model.isSwapping {
                                ProgressView().tint(.branco)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .foregroundStyle(Color.branco)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 14).foregroundStyle(Color.laranja))
                    }
                    .disabled(model.isSwapping)
                    .accessibilityLabel("Trocar por outra opção")
                    Spacer()
                }

                if let error = model.swapError {
                    Text(ErrorKind(error).title)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 30)
    }

    private var heading: Text {
        let lead: LocalizedStringKey = mediaType == .movie ? "Estes são os filmes " : "Estas são as séries "
        return Text(lead).foregroundColor(.white).fontWeight(.semibold)
            + Text("mais compatíveis ").foregroundColor(.laranja).bold()
            + Text("com você agora:").foregroundColor(.white).fontWeight(.semibold)
    }
}
```

- [ ] **Step 5: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`. Corrija erros de tipo/sintaxe nestes arquivos sem mudar a estrutura (o código acima é o contrato; ajuste só o necessário para compilar no Xcode instalado).

- [ ] **Step 6: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): add results carousel, title card/detail and streaming availability section"
```

---

### Task 9: Busca e categorias ligadas ao `ResultsView`

**Files:**
- Modify (reescrever): `FilmFinder/View/SearchView.swift` → mover para `FilmFinder/Features/Search/SearchView.swift`
- Modify (editar): `FilmFinder/View/CategoriesView.swift` → mover para `FilmFinder/Features/Search/CategoriesView.swift`

**Interfaces:**
- Consumes: `ResultsView` (Task 8), `CategoryQueryBuilder` (Task 6), `MediaType` e `pluralName`/`pluralNameString` (Tasks 2 e 7)
- Produces: `SearchView()` e `CategoriesView(type: Binding<MediaType>)` (já usados por `MainView`)

- [ ] **Step 1: Mover os arquivos**

Run: `mkdir -p FilmFinder/Features/Search && git mv FilmFinder/View/SearchView.swift FilmFinder/Features/Search/SearchView.swift && git mv FilmFinder/View/CategoriesView.swift FilmFinder/Features/Search/CategoriesView.swift`

- [ ] **Step 2: Reescrever `FilmFinder/Features/Search/SearchView.swift`**

```swift
import SwiftUI

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

private enum SearchMethod: Hashable {
    case description
    case categories
}

struct SearchView: View {
    @State private var message = ""
    @State private var selectedType: MediaType = .movie
    @State private var selectedMethod: SearchMethod = .description

    private var trimmedMessage: String {
        String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
    }

    var body: some View {
        NavigationStack {
            VStack {
                Image("FilmFinder_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 35)
                    .padding(5)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading) {
                        Text("Selecione o tipo de conteúdo que você está procurando:")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .foregroundColor(Color("branco"))

                        Picker("Appearance", selection: $selectedType) {
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Text(type.pluralName).tag(type)
                            }
                        }
                        .colorMultiply(selectedType == .movie ? Color("laranja") : .purple)
                        .pickerStyle(.segmented)

                        Text("Escolha um método de busca:")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .foregroundColor(Color("branco"))

                        Picker("Appearance", selection: $selectedMethod) {
                            Text("Descrição").tag(SearchMethod.description)
                            Text("Selecionar categorias").tag(SearchMethod.categories)
                        }
                        .colorMultiply(selectedMethod == .description ? Color("laranja") : .purple)
                        .pickerStyle(.segmented)
                    }
                    .padding()

                    VStack(alignment: .center) {
                        if selectedMethod == .description {
                            TextField("", text: $message, axis: .vertical)
                                .placeholder(when: message.isEmpty) {
                                    VStack(alignment: .leading) {
                                        Text("Descreva o tipo de filme que você está a fim de assistir agora")
                                    }
                                    .foregroundColor(.white)
                                }
                                .lineLimit(5...10)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(width: 300, height: 300, alignment: .topLeading)
                                .background(Color("cinza2"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.cinza1, lineWidth: 1)
                                )

                            NavigationLink {
                                ResultsView(mediaType: selectedType, query: trimmedMessage)
                            } label: {
                                HStack {
                                    Text("Pesquisar \(selectedType.pluralNameString)")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 15))
                                .fontWeight(.bold)
                                .foregroundColor(Color("preto"))
                                .frame(width: 200, height: 40, alignment: .center)
                                .background(Color("laranja").opacity(trimmedMessage.isEmpty ? 0.4 : 1))
                                .cornerRadius(16)
                            }
                            .disabled(trimmedMessage.isEmpty)
                        } else {
                            CategoriesView(type: $selectedType)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .background(Color("cinza1"))
        }
    }
}

#Preview {
    SearchView()
        .environment(AppEnvironment.live())
}
```

- [ ] **Step 3: Editar `FilmFinder/Features/Search/CategoriesView.swift`** — quatro substituições exatas

(a) tipo do binding:
```swift
// de
    @Binding var type: String
// para
    @Binding var type: MediaType
```

(b) o `NavigationLink` final (do `NavigationLink {` até o `}` que fecha o label) passa a ser:
```swift
            NavigationLink {
                ResultsView(mediaType: type, query: builtQuery ?? "")
            } label: {
                HStack {
                    Text("Pesquisar \(type.pluralNameString)")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15))
                .fontWeight(.bold)
                .foregroundColor(Color("preto"))
                .frame(width: 200, height: 40, alignment: .center)
                .background(Color("laranja").opacity(builtQuery == nil ? 0.4 : 1))
                .cornerRadius(16)
            }
            .disabled(builtQuery == nil)
```

(c) acrescentar, logo antes de `func joinedNames(from categories: [Category]) -> String {`:
```swift
    private var builtQuery: String? {
        CategoryQueryBuilder.query(
            mediaType: type,
            moods: selectedMood.map(\.name),
            genres: selectedGenre.map(\.name),
            themes: selectedScript.map(\.name)
        )
    }

```

(d) o preview:
```swift
// de
        CategoriesView(type: Binding.constant("Filmes"))
// para
        CategoriesView(type: .constant(.movie))
```

- [ ] **Step 4: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`.

- [ ] **Step 5: Verificar no simulador, ponta a ponta contra o Worker `dev`**

Use o MCP do simulador (`mcp__Claude_Code_iOS_Simulator__control`): `attach` (antes de construir), construir com `xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build`, depois `launch` com `app_path` `build/Build/Products/Debug-iphonesimulator/FilmFinder.app`, passar o onboarding, escolher **Filmes**, escrever "ficção científica que mexe com o tempo" e tocar em Pesquisar.
Expected (screenshots): tela de carregamento com a animação; depois 3 cards com pôster, estrelas, **motivo em 1–2 linhas** e **logos "Disponível em"**; arrastar troca o card em foco; o botão de trocar substitui o card sem tela de carregamento; "+" abre o detalhe com a seção **Onde assistir** e o texto **Dados de streaming: JustWatch**. Registrar o que não bater e corrigir antes do commit.

- [ ] **Step 6: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): wire search and categories to the recommendations backend"
```

---

### Task 10: Telas de biblioteca (Histórico, Favoritos, Assistidos) e Perfil

**Files:**
- Create: `FilmFinder/Features/Library/LibraryListView.swift`, `LibraryRow.swift`, `HistoryView.swift`
- Create: `FilmFinder/Features/Profile/ProfileView.swift`, `LibraryPreviewRectangle.swift`
- Delete: `FilmFinder/View/HistoryView.swift`, `FilmFinder/View/Profile/` (todos os arquivos), `FilmFinder/View/CardListView.swift`

**Interfaces:**
- Consumes: `LibraryItem`, `LibraryStore` (Task 4); `TitleDetail` (Task 8); `PosterImage`, `CustomDivider` (Task 7)
- Produces: `LibraryListView(kind:showsBackButton:)`, `HistoryView()` (usado pelo `MainView`), `ProfileView()` (usado pelo `MainView`)

- [ ] **Step 1: Remover as telas antigas que dependem de `DataManager`**

Run: `git rm -r FilmFinder/View/HistoryView.swift FilmFinder/View/Profile FilmFinder/View/CardListView.swift && mkdir -p FilmFinder/Features/Library FilmFinder/Features/Profile`

- [ ] **Step 2: Criar `FilmFinder/Features/Library/LibraryRow.swift`**

```swift
import SwiftUI

struct LibraryRow: View {
    let title: Title
    let date: Date

    var body: some View {
        NavigationLink {
            TitleDetail(title: title)
        } label: {
            HStack {
                PosterImage(path: title.posterPath)
                    .frame(width: 70, height: 105)
                    .clipped()
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title.title)
                        .font(.system(size: 16))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.branco)
                    if let year = title.year {
                        Text(String(year))
                            .font(.system(size: 13))
                            .foregroundColor(.branco)
                    }
                    Text(date, style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(Color(uiColor: .gray))
                }
                .padding()
                Spacer()
            }
            .padding(.leading)
            .frame(maxWidth: .infinity)
        }
    }
}
```

- [ ] **Step 3: Criar `FilmFinder/Features/Library/LibraryListView.swift`**

```swift
import SwiftData
import SwiftUI

struct LibraryListView: View {
    enum Kind {
        case history
        case favorites
        case watched

        var heading: LocalizedStringKey {
            switch self {
            case .history: "Histórico"
            case .favorites: "Favoritos"
            case .watched: "Assistidos"
            }
        }
    }

    let kind: Kind
    let showsBackButton: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [LibraryItem]

    init(kind: Kind, showsBackButton: Bool = true) {
        self.kind = kind
        self.showsBackButton = showsBackButton
        switch kind {
        case .history:
            _items = Query(filter: #Predicate<LibraryItem> { $0.inHistory }, sort: \.recommendedAt, order: .reverse)
        case .favorites:
            _items = Query(filter: #Predicate<LibraryItem> { $0.isFavorite }, sort: \.recommendedAt, order: .reverse)
        case .watched:
            _items = Query(filter: #Predicate<LibraryItem> { $0.isWatched }, sort: \.recommendedAt, order: .reverse)
        }
    }

    var body: some View {
        VStack {
            Image("FilmFinder_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 25)
                .padding(5)

            VStack {
                HStack {
                    Text(kind.heading)
                        .fontWidth(.expanded)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.laranja)
                    Spacer()
                    EditButton()
                        .foregroundColor(.laranja)
                }
                CustomDivider(color: .laranja, width: 2)
            }
            .padding()

            List {
                ForEach(items) { item in
                    if let title = item.snapshot {
                        LibraryRow(title: title, date: item.recommendedAt)
                            .listRowBackground(Color.cinza1)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
        }
        .background(Color.cinza1)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if showsBackButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { BackButton() }
                }
            }
        }
        .toolbar(showsBackButton ? .automatic : .hidden, for: .navigationBar)
    }

    private func delete(at offsets: IndexSet) {
        let store = LibraryStore(context: modelContext)
        let titles = offsets.compactMap { items[$0].snapshot }
        withAnimation {
            for title in titles {
                switch kind {
                case .history: store.removeFromHistory(title)
                case .favorites: store.setFavorite(title, false)
                case .watched: store.setWatched(title, false)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Criar `FilmFinder/Features/Library/HistoryView.swift`**

```swift
import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            LibraryListView(kind: .history, showsBackButton: false)
        }
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Features/Profile/LibraryPreviewRectangle.swift`**

```swift
import SwiftUI

struct LibraryPreviewRectangle: View {
    let heading: LocalizedStringKey
    let items: [LibraryItem]

    var body: some View {
        VStack {
            Text(heading)
                .font(.system(size: 15))
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .foregroundStyle(Color.laranja)
                .padding(.top)
            CustomDivider(color: .laranja, width: 2)
                .padding(.horizontal)

            HStack {
                if items.isEmpty {
                    Color.clear.frame(width: 95, height: 142)
                } else {
                    ForEach(items.prefix(3)) { item in
                        PosterImage(path: item.snapshot?.posterPath)
                            .frame(width: 95, height: 142)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }
        }
        .frame(width: 341, height: 207.3125)
        .background(Color(red: 0.2, green: 0.2, blue: 0.2), in: RoundedRectangle(cornerRadius: 15.5))
    }
}
```

- [ ] **Step 6: Criar `FilmFinder/Features/Profile/ProfileView.swift`**

```swift
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query(filter: #Predicate<LibraryItem> { $0.isFavorite }, sort: \.recommendedAt, order: .reverse)
    private var favorites: [LibraryItem]

    @Query(filter: #Predicate<LibraryItem> { $0.isWatched }, sort: \.recommendedAt, order: .reverse)
    private var watched: [LibraryItem]

    var body: some View {
        NavigationStack {
            VStack(alignment: .center) {
                Image("FilmFinder_logoPB")
                    .resizable()
                    .frame(width: 54, height: 29)

                Image("perfil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94)
                    .padding(.top, 20)

                Text("Meu Perfil")
                    .font(.system(size: 20))
                    .fontWidth(.expanded)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                    .foregroundColor(.laranja)

                Text("\(watched.count) assistidos | \(favorites.count) favoritos")
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundColor(.branco)

                VStack {
                    NavigationLink {
                        LibraryListView(kind: .favorites)
                    } label: {
                        LibraryPreviewRectangle(heading: "Favoritos", items: favorites)
                    }
                    NavigationLink {
                        LibraryListView(kind: .watched)
                    } label: {
                        LibraryPreviewRectangle(heading: "Assistidos", items: watched)
                    }
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cinza1)
        }
    }
}
```

- [ ] **Step 7: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`. Se houver referência restante a `DataManager`/`WatchedContent` em arquivo **que ainda será apagado na Task 11** (ex.: `FilmView`, `SerieView`, `ChatGptView`), é esperado e aceitável; o erro deve ser só nesses arquivos legados. Nesse caso, siga direto para a Task 11 e faça o build lá (os dois passos são commitados juntos).

- [ ] **Step 8: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): add library list screens and profile backed by SwiftData"
```

---

### Task 11: Limpeza do código legado, Swift 6, traduções e verificação final

**Files:**
- Delete: `FilmFinder/Model/` (tudo, **exceto** `Cores.swift`), `FilmFinder/View/ChatGptView.swift`, `FilmFinder/View/FilmsViews/`, `FilmFinder/View/SeriesView/`, `FilmFinder/View/ErrorView.swift`, `FilmFinder/Secrets.swift` (o temporário da Task 1), `FilmFinder/Source/FlexStack.swift` (se não referenciado)
- Move: onboarding/loading/main/back para `Features/`
- Modify: `project.yml` (Swift 6), `FilmFinder/Localizable.xcstrings`, `README.md` (raiz)

**Interfaces:**
- Consumes: tudo das Tasks 2–10
- Produces: app sem referências ao código legado, em Swift 6, com strings em PT/EN e verificado ponta a ponta.

- [ ] **Step 1: Confirmar que nada novo referencia o legado e checar o que é seguro apagar**

Run:
```bash
grep -rnE "DataManager|WatchedContent|FilmData|SerieData|ChatGptView|FilmView|SerieView|ErrorView\b|FlexStack|ImageProvider|Secrets\." FilmFinder --include='*.swift' | grep -vE "^FilmFinder/(Model|View/(ChatGptView|FilmsViews|SeriesView|ErrorView)|Source/FlexStack)" 
```
Expected: sem linhas (só o próprio legado, filtrado, referencia o legado). Se algo de `Features/` ou `App/` aparecer, corrija antes de apagar.

- [ ] **Step 2: Apagar o legado**

Run:
```bash
git rm -r FilmFinder/Model/ChatGptModel.swift FilmFinder/Model/ChatGptResponseModel.swift FilmFinder/Model/ChatGptFilterModel.swift FilmFinder/Model/FilmData.swift FilmFinder/Model/FilmResponseModel.swift FilmFinder/Model/SerieData.swift FilmFinder/Model/SerieResponseModel.swift FilmFinder/Model/History.swift FilmFinder/Model/UserDefaultsManenger.swift FilmFinder/View/ChatGptView.swift FilmFinder/View/FilmsViews FilmFinder/View/SeriesView FilmFinder/View/ErrorView.swift
rm -f FilmFinder/Secrets.swift
grep -rn "FlexStack" FilmFinder --include='*.swift' | grep -v "Source/FlexStack.swift" || git rm FilmFinder/Source/FlexStack.swift
```
Expected: `Model/` fica só com `Cores.swift`.

- [ ] **Step 3: Reorganizar as telas mantidas**

Run:
```bash
mkdir -p FilmFinder/Features/Onboarding FilmFinder/Features/Shared FilmFinder/Features/Home
git mv FilmFinder/View/Onboarding/*.swift FilmFinder/Features/Onboarding/
git mv FilmFinder/View/InitialLoading.swift FilmFinder/Features/Home/InitialLoading.swift
git mv FilmFinder/View/MainView.swift FilmFinder/Features/Home/MainView.swift
git mv FilmFinder/View/BackButton.swift FilmFinder/Features/Shared/BackButton.swift
git mv FilmFinder/Model/Cores.swift FilmFinder/Features/Shared/Cores.swift
rmdir FilmFinder/View/Onboarding FilmFinder/View FilmFinder/Model 2>/dev/null; ls FilmFinder
```
Expected: `ls` mostra `Animation`, `App`, `Assets.xcassets`, `Core`, `Data`, `Domain`, `Features`, `Images`, `Info.plist`, `Localizable.xcstrings`, `Preview Content`, `Source` (se ainda existir). Remover de `Features/Shared/BackButton.swift` o `protocol ImageProvider { ... }` do final do arquivo, se estiver lá (era usado só pelo legado).

- [ ] **Step 4: Compilar com tudo limpo (ainda em Swift 5)**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`.

- [ ] **Step 5: Ligar o Swift 6** — em `project.yml`, trocar `SWIFT_VERSION: '5.0'` por `SWIFT_VERSION: '6.0'`

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E "error:" | head -20`
Expected: pode haver erros de concorrência. Corrija-os arquivo a arquivo, nesta ordem de preferência: (1) `@MainActor` no tipo/propriedade que toca UI ou SwiftData; (2) `Sendable` em structs de valor; (3) `nonisolated(unsafe)` só em estado global de teste. Candidatos prováveis: `LottieView.swift` (`UIViewRepresentable` já é MainActor), `Cores.swift` (`Color` estáticos: ok), `MockURLProtocol` (já usa `nonisolated(unsafe)`), onboarding. **Não** silencie com `@preconcurrency` sem necessidade. Repita até zero `error:`.

- [ ] **Step 6: Rodar toda a suíte em Swift 6**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Test run|passed|failed" | tail -6`
Expected: todos PASS (≈ 40 testes).

- [ ] **Step 7: Adicionar as traduções em inglês** (as chaves em português já funcionam como texto-fonte; falta o inglês)

Run:
```bash
python3 - <<'EOF'
import json
p = 'FilmFinder/Localizable.xcstrings'
d = json.load(open(p))
new = {
  "Disponível em": "Available on",
  "Por que combina": "Why it fits",
  "Onde assistir": "Where to watch",
  "Assinatura": "Subscription",
  "Grátis": "Free",
  "Aluguel": "Rent",
  "Compra": "Buy",
  "Não disponível em streaming na sua região": "Not available to stream in your region",
  "Ver onde assistir": "See where to watch",
  "Dados de streaming: JustWatch": "Streaming data: JustWatch",
  "%lld min": "%lld min",
  "%lld temporadas": "%lld seasons",
  "%lld assistidos | %lld favoritos": "%lld watched | %lld favorites",
  "Sem conexão": "No connection",
  "Verifique sua internet e tente novamente": "Check your internet and try again",
  "Serviço indisponível no momento": "Service unavailable right now",
  "Estamos com instabilidade. Tente novamente em instantes": "We're having issues. Please try again shortly",
  "Suas buscas de hoje acabaram": "You're out of searches for today",
  "Volte amanhã para novas recomendações": "Come back tomorrow for new recommendations",
  "Algo deu errado": "Something went wrong",
  "Tente novamente": "Try again",
  "Tentar de novo": "Try again",
  "Trocar por outra opção": "Swap for another option",
  "Favoritar": "Add to favorites",
  "Remover dos favoritos": "Remove from favorites",
  "Marcar como assistido": "Mark as watched",
  "Desmarcar como assistido": "Unmark as watched",
  "Estes são os filmes ": "These are the movies ",
  "Estas são as séries ": "These are the series ",
}
added = 0
for key, en in new.items():
    entry = d["strings"].setdefault(key, {})
    locs = entry.setdefault("localizations", {})
    if "en" not in locs:
        locs["en"] = {"stringUnit": {"state": "translated", "value": en}}
        added += 1
    locs.setdefault("pt-BR", {"stringUnit": {"state": "translated", "value": key}})
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
print("traduções adicionadas:", added)
EOF
```
Expected: `traduções adicionadas: N` (N ≤ 28; chaves que já existiam no catálogo são preservadas).

- [ ] **Step 8: Atualizar o `README.md` da raiz** — acrescentar ao final

```markdown

## Desenvolvimento

O app depende de um backend (Cloudflare Worker em `backend/`).

    brew install xcodegen
    xcodegen generate
    open FilmFinder.xcodeproj

A URL da API vem de `Config/*.xcconfig` (`API_BASE_URL`). A chave de desenvolvimento fica em `Config/Local.xcconfig`
(não versionado): `DEV_API_KEY = <valor do DEV_API_KEY do backend>`.

Testes: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17'`
```

- [ ] **Step 9: Verificação final no simulador** (mesmo fluxo da Task 9, Step 5, agora no app limpo)

Construir, instalar e abrir no iPhone 17. Roteiro, com screenshot em cada passo:
1. Abrir o app → onboarding (ou Home) aparece normalmente.
2. **Filmes** + descrição → 3 cards com motivo e logos; trocar um card (sem tela de carregamento); abrir o detalhe (seção **Onde assistir** + **Dados de streaming: JustWatch**); favoritar e marcar assistido.
3. Voltar e fazer uma **nova busca igual**: os títulos favoritos/assistidos/já mostrados **não** reaparecem.
4. Aba **Histórico**: lista os títulos exibidos (e só eles); apagar um item; aba **Perfil**: contadores e prévias de Favoritos/Assistidos corretos.
5. **Séries** + categorias (selecionar 1 humor, 1 gênero, 1 tema) → resultados de séries, detalhe mostra "N temporadas".
6. Modo avião ligado → buscar → tela "Sem conexão" com **Tentar de novo**; desligar o modo avião e tocar em tentar de novo → resultados.
Expected: tudo acima funciona; registrar qualquer divergência e corrigir antes de commitar.

- [ ] **Step 10: Teste da migração com dados reais do formato antigo** (SwiftData + UserDefaults no simulador)

Run (com o app fechado):
```bash
APPID=$(xcrun simctl get_app_container booted com.andre.filmfinder data); echo "$APPID"
xcrun simctl spawn booted defaults write com.andre.filmfinder allContent -data "$(printf '%s' '[{"id":"A1B2C3D4-0000-0000-0000-000000000001","date":700000000,"content":{"filme":{"id":"A1B2C3D4-0000-0000-0000-000000000002","idFilme":19995,"title":"Avatar","image":"/iNMP8uzaV2Ing6ZCw0IICgEFVNfC.jpg","releaseDate":"2009-12-15","originalTitle":"2009-12-15","duration":162,"plot":"Plot","rating":7.5,"favorite":false,"watched":false}}}]' | xxd -p | tr -d '\n')"
xcrun simctl spawn booted defaults delete com.andre.filmfinder legacyImportDone.v1 2>/dev/null; true
```
Depois abrir o app e fazer uma busca de **filmes** que provavelmente sugeriria Avatar (ex.: "ficção científica épica com alienígenas"). Expected: **Avatar (id 19995) não aparece** nos resultados, porque o importador o registrou como já recomendado. Conferir também que as chaves antigas sumiram: `xcrun simctl spawn booted defaults read com.andre.filmfinder allContent` deve falhar com "does not exist". A cobertura completa do importador (flags, séries, datas, idempotência, dados corrompidos) está nos testes da Task 5.

- [ ] **Step 11: Commit final**

```bash
git add -A FilmFinder project.yml README.md Config .gitignore
git commit -m "refactor(ios): remove legacy ChatGPT/UserDefaults code, enable Swift 6, add English strings"
```

---

## Próximos planos

3. **Identidade e cota** (App Attest, Sign in with Apple, refresh, `/v1/me`, exclusão de conta; remove `x-dev-key` e a chave embutida; mostra "N buscas restantes").
4. **Monetização** (StoreKit 2, webhooks, paywall; trata `APIError.quotaExceeded` abrindo o paywall).
5. **Lançamento** (CI, alertas, produção, App Store Connect, Analytics Engine, token do AI Gateway só com Run).
