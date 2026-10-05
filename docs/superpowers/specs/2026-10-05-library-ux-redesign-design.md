# Redesign de usabilidade: Biblioteca unificada e Ajustes

Data: 2026-10-05

## Objetivo

Melhorar a usabilidade das telas de Favoritos, Assistidos, Histórico, Perfil e Ajustes. Hoje as três listas são a mesma `LibraryListView` simples, o Perfil é um beco sem saída (avatar genérico, dois contadores e dois cards) e os Ajustes são uma `List` crua.

## Escopo

Dentro:
- Estrutura de abas.
- Nova tela Biblioteca (Favoritos / Assistidos / Histórico).
- Melhorias nas listas: grade de pôsteres, busca e filtro, ações por swipe, estados vazios.
- Redesenho do topo dos Ajustes.

Fora: Recomendações/Resultados, onboarding, detalhe do título, backend, modelo de dados (`LibraryItem` e `LibraryStore` não mudam de esquema).

## Estrutura de abas

`MainView` passa de 4 para 3 abas: **Recomendações**, **Biblioteca**, **Ajustes**.

Removidos: `HistoryView`, `ProfileView`, `LibraryListView`, `LibraryPreviewRectangle`.
O Histórico vira um segmento da Biblioteca. Os contadores do Perfil passam para o cabeçalho da Biblioteca.

## Biblioteca

Nova `Features/Library/LibraryView.swift`, dentro de uma `NavigationStack`.

Elementos:
1. Cabeçalho: título "Biblioteca" e contadores ("N assistidos · M favoritos").
2. Seletor segmentado: Favoritos | Assistidos | Histórico.
3. Busca (`.searchable`) por título.
4. Filtro de tipo: Todos | Filmes | Séries.
5. Toggle lista/grade, preferência persistida com `@AppStorage`.
6. Conteúdo: lista (`LibraryRow`) ou grade (`LibraryGridCell`); toque abre `TitleDetail`.

### Dados e filtro

Uma única `@Query` com os `LibraryItem` que tenham `isFavorite || isWatched || inHistory`, ordenados por `recommendedAt` decrescente.

O título fica dentro de `snapshotData` (JSON), então a busca não pode ser feita em `#Predicate`. Segmento, texto e tipo são filtrados em memória.

A lógica fica num tipo puro, `LibraryFilter` (`Features/Library/LibraryFilter.swift`), sem dependência de SwiftUI:
- entrada: itens, segmento, texto de busca, tipo de mídia;
- saída: itens do segmento, que casam com o texto e o tipo, na ordem recebida;
- busca ignora caixa e acentos e casa com `title` e `originalTitle`;
- itens cujo `snapshot` não decodifica são ignorados.

### Ações

Swipe à direita: alterna Favorito e Assistido (`LibraryStore.setFavorite` / `setWatched`).
Swipe à esquerda: remove do segmento atual:
- Favoritos: `setFavorite(false)`
- Assistidos: `setWatched(false)`
- Histórico: `removeFromHistory` (não mexe em favoritos nem assistidos)

Na grade, as mesmas ações ficam num menu de contexto (pressionar e segurar).

Remoção mostra um aviso curto com "Desfazer", que reaplica o estado anterior.

Menu do segmento Histórico: "Limpar histórico" (`LibraryStore.clearHistory`), com confirmação.

### Estados vazios

Por segmento, com mensagem própria (ex.: "Nada favoritado ainda") e botão que leva à aba Recomendações. Busca ou filtro sem resultado mostram uma mensagem distinta ("Nenhum resultado"), sem o botão.

Para o botão trocar de aba, `MainView` expõe a seleção de aba por binding/ambiente.

### Linha e célula

`LibraryRow` mantém pôster, título, ano e data, e ganha nota e gênero principal. `LibraryGridCell` mostra pôster, e título/ano abaixo, com selo de favorito/assistido.

## Ajustes

Mantém Conta (Sign in with Apple, sair, excluir) e Sobre sem mudança de fluxo. O topo ganha:
- card de cota com barra de progresso ("X de Y buscas hoje"), a partir de `account.quota`;
- card de estado da conta.

Substitui a seção "Buscas" atual. Fundo e tipografia seguem o padrão do app (`Color.cinza1`, `.laranja`).

## Testes

- `LibraryFilterTests`: segmentos, busca sem acento e sem caixa, filtro de tipo, ordenação, snapshot inválido.
- Testes de remoção por segmento contra `LibraryStore` (o Histórico não afeta favoritos/assistidos) e de desfazer, via `LibraryHarness`.
- Verificação visual no simulador: lista, grade, vazio, busca sem resultado, swipe, Ajustes.

## Riscos

- Filtro em memória decodifica o JSON de cada item a cada render. Para bibliotecas pessoais (centenas de itens) é aceitável; se pesar, memoizar o `snapshot` ou guardar `title` em campo próprio (mudança de esquema, fora deste escopo).
- Textos novos precisam entrar em `Localizable.xcstrings`.
