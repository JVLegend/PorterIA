<!-- cover: imagem do menu bar do macOS com o ícone do PorterIA aberto, listando portas (3000, 5173, 8080) com nomes de processos. Fundo escuro do macOS Sonoma. -->

---
title: "Como publiquei meu primeiro app macOS no Homebrew em uma sessão de Claude Code"
published: false
tags: macos, swift, opensource, devtools
---

## O problema

Todo dev web já viu isso:

```
Error: listen EADDRINUSE: address already in use :::3000
```

Algum processo zumbi de uma sessão anterior está segurando a porta. A solução é mecânica: `lsof -i :3000`, copiar o PID, `kill -9`, repetir. Faço isso há anos. Há anos também uso o [Portpourri](https://github.com/inket/Portpourri) — um menu bar utility MIT que mostra as portas listening e mata o processo num clique.

Resolvi reescrever do zero, no meu estilo, e usar isso como desculpa pra aprender o pipeline completo de distribuição de app macOS: SwiftPM → `.app` bundle → assinatura → notarização → `.dmg` → Homebrew Cask. Sem projeto Xcode. Em uma sessão de tarde, usando Claude Code como par de programação.

O resultado é o [PorterIA](https://github.com/JVLegend/PorterIA), MIT, instalável com `brew install --cask porteria`. Este post é o passo a passo do que aprendi.

## Por que SwiftPM em vez de projeto Xcode

A maioria dos tutoriais de macOS app começa com "abra o Xcode, File → New Project". Pra um app pequeno, isso vem com peso:

- `project.pbxproj` é um arquivo binário-ish em formato proprietário. Diffs ilegíveis, conflitos de merge dolorosos.
- UUIDs gerados pelo Xcode mudam em cenários estranhos. Já vi gente passar uma manhã debugando um build que só falhava na máquina dela.
- CI fica acoplada ao Xcode (`xcodebuild`), que é lento e verboso.

SwiftPM resolve isso com um `Package.swift` de 20 linhas:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PorterIA",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PorterIA",
            resources: [.process("Resources")]
        )
    ]
)
```

`swift build -c release` produz um binário em `.build/release/PorterIA`. O custo: você precisa montar o `.app` bundle na mão. Veremos que é trivial.

## O parser do lsof

A fonte de verdade pra "quem está escutando na porta X" no macOS é `lsof -nP -iTCP -sTCP:LISTEN -F`. A flag `-F` faz o lsof imprimir um formato delimitado por campos prefixados com letras, fácil de parsear:

```
p1234
cnode
fn123
PTCP
n*:3000
```

Cada linha começa com uma letra que identifica o campo: `p` = PID, `c` = command, `n` = nome (IP:porta), `P` = protocolo. O parser em Swift fica direto:

```swift
for line in output.split(separator: "\n") {
    guard let key = line.first else { continue }
    let value = String(line.dropFirst())
    switch key {
    case "p": currentPID = Int(value)
    case "c": currentCommand = value
    case "n":
        if let port = parsePort(value) {
            entries.append(.init(pid: currentPID, command: currentCommand, port: port))
        }
    default: break
    }
}
```

Pra obter o caminho completo do executável (que `lsof` não dá), faço um `ps -o comm= -p <PID>` complementar. Combinados, dá pra exibir "node — /Users/jv/repos/x/server.js" em vez de só "node".

## UI com MenuBarExtra

SwiftUI a partir do macOS 13 tem `MenuBarExtra`, que é o jeito moderno de fazer app de menu bar sem mexer com `NSStatusItem`. O `App` inteiro do PorterIA é basicamente:

```swift
@main
struct PorterIAApp: App {
    var body: some Scene {
        MenuBarExtra("PorterIA", systemImage: "network") {
            PortListView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

`.window` em vez de `.menu` porque eu queria uma view SwiftUI com listas e botões, não um `NSMenu`. Pra esconder do Dock, basta `LSUIElement=true` no `Info.plist`.

## Code signing: o cert que faltou

Aqui é onde perdi mais tempo. O macOS tem vários tipos de certificado da Apple Developer Program, e eles **não** são intercambiáveis:

- **Apple Distribution** → submissão na App Store. Não funciona pra distribuição direta.
- **Mac Installer Distribution** → assinar `.pkg`. Outra coisa.
- **Developer ID Application** → este. É o cert pra apps distribuídos fora da App Store, com notarização.

Se você assinar com Apple Distribution e tentar notarizar, recebe um erro genérico de "invalid signature" que não diz qual cert deveria ter usado. Perdi 40 minutos nisso.

Comando correto:

```sh
codesign --force --options runtime \
  --entitlements Resources/PorterIA.entitlements \
  --sign "Developer ID Application: João Victor Dias (XXXXXXXXXX)" \
  build/PorterIA.app
```

`--options runtime` é obrigatório (hardened runtime). Sem isso, notarização recusa.

O arquivo de entitlements pro PorterIA é minimal — só o necessário pra rodar como app não-sandbox que invoca subprocessos:

```xml
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<false/>
<key>com.apple.security.cs.disable-library-validation</key>
<false/>
```

Quanto menos entitlements, melhor — Apple analisa isso.

## Notarização com notarytool e profile no Keychain

A primeira regra: **nunca** ponha sua app-specific password num shell script. O `notarytool` permite guardar as credenciais no Keychain uma vez:

```sh
xcrun notarytool store-credentials "PorterIA-Notary" \
  --apple-id "voce@exemplo.com" \
  --team-id "XXXXXXXXXX" \
  --password "app-specific-password-aqui"
```

Depois, o release script só referencia o profile:

```sh
xcrun notarytool submit build/PorterIA.dmg \
  --keychain-profile "PorterIA-Notary" \
  --wait
```

A flag `--wait` bloqueia até a Apple terminar (geralmente 1-3 minutos pra um app pequeno). Se passar, faço o `stapler`:

```sh
xcrun stapler staple build/PorterIA.dmg
```

Isso anexa o "ticket" de notarização ao DMG, pra que o Gatekeeper aprove o app offline.

## Empacotando o .dmg

`hdiutil` é o utilitário do macOS pra criar imagens de disco. Receita mínima pra um DMG de aplicação com symlink pra `/Applications`:

```sh
mkdir -p build/dmg
cp -R build/PorterIA.app build/dmg/
ln -s /Applications build/dmg/Applications

hdiutil create -volname "PorterIA" \
  -srcfolder build/dmg \
  -ov -format UDZO \
  build/PorterIA.dmg
```

O symlink é o detalhe que faz o usuário ver "arraste pra cá" sem que você precise customizar o background da imagem. Suficiente pra v0.1.

## Publicação no Homebrew Cask

Tem dois caminhos:

1. **homebrew/cask oficial.** Requer histórico de releases estável (geralmente 30+ dias e algumas versões), repo público notável, e passa por review. Pra um app v0.1, não rola.
2. **Tap pessoal.** Você cria um repo chamado `homebrew-<algumacoisa>`, e usuários fazem `brew tap seu-user/algumacoisa` antes de instalar.

Optei pelo tap. Repo: `JVLegend/homebrew-porteria`. O Cask fica em `Casks/porteria.rb`:

```ruby
cask "porteria" do
  version "0.1.0"
  sha256 "..."

  url "https://github.com/JVLegend/PorterIA/releases/download/v#{version}/PorterIA.dmg"
  name "PorterIA"
  desc "Menu bar utility to list listening TCP ports and kill processes"
  homepage "https://github.com/JVLegend/PorterIA"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "PorterIA.app"

  zap trash: [
    "~/Library/Preferences/com.jvlegend.PorterIA.plist",
  ]
end
```

O bloco `livecheck` com `strategy :github_latest` é o que faz `brew upgrade` seguir releases novos automaticamente — sem ele, todo bump de versão exige editar o Cask manualmente.

Instalar fica:

```sh
brew tap jvlegend/porteria
brew install --cask porteria
```

## Lições aprendidas

- **SwiftPM puro escala pra um app menu bar.** Não senti falta do Xcode em nenhum momento. Editar no VS Code com o sourcekit-lsp foi rápido.
- **Code signing falha de jeitos vagos.** O erro nunca diz "você usou o cert errado". Vale sempre conferir o tipo de certificado **antes** de gastar tempo.
- **Notarytool + keychain profile é o padrão atual.** Tutoriais antigos com `altool` e senha em variável de ambiente são obsoletos e perigosos.
- **Homebrew tap pessoal é o caminho realista pra v0.x.** Vá pro cask oficial só quando o projeto estiver maduro.
- **Construir com Claude Code numa sessão não é mágica, é alavancagem.** O que mudou foi a velocidade de iteração no boilerplate (shell scripts de release, parser de `lsof`, entitlements). As decisões de arquitetura e o debug do certificado errado continuaram sendo eu pensando — só que eu não digito mais cada linha. É uma ferramenta normal, com a curva de uso normal.

Código completo, scripts de release e o Cask estão em [github.com/JVLegend/PorterIA](https://github.com/JVLegend/PorterIA). MIT. Issues e PRs são bem-vindos.
