# Film Finder

**App that suggests the best films and series for you, in a personalized way and with the help of AI.**


The FilmFinder app has **two ways to search**: **select** from the various **predefined categories**, or **write** - in your own words - the type of movie/series you are looking for. You'll be given **three options** that best suit you, and if you don't like any of them, you can click on the **download** button for new suggestions!

All the movies you've recommended will be recorded in your **History**, so you can always check them out again later.

The app also has a **Favorites** function, where you can save suggested films so you don't forget them. What's more, if FilmFinder suggests a movie you've already watched, select it as "Watched" and the app won't recommend it again!




## Desenvolvimento

O app depende do backend em https://github.com/AndreWozniack/filmfinder-api (repositório separado; roda em Docker/Dokploy ou como Cloudflare Worker).

    brew install xcodegen
    cp Config/Local.xcconfig.example Config/Local.xcconfig   # ou crie o arquivo com DEVELOPMENT_TEAM = <seu Team ID>
    xcodegen generate
    open FilmFinder.xcodeproj

A URL da API vem de `Config/*.xcconfig` (`API_BASE_URL`). Não há chave de API no app: o dispositivo se registra no
backend (App Attest em aparelho real; sem atestação no simulador, aceito só pelo ambiente `dev`) e usa tokens de sessão.
Sign in with Apple é opcional (Ajustes). Testes:

    xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17'
