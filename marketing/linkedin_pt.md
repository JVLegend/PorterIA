Toda vez que aparecia `Error: listen EADDRINUSE :3000`, eu perdia 2 minutos no terminal pra descobrir qual processo estava segurando a porta.

Cansei. Resolvi resolver de uma vez.

**PorterIA** é um pequeno utilitário de menu bar pro macOS que lista as portas TCP em estado LISTEN com o processo dono, e deixa você matar o processo com um clique. Só isso. Não tenta ser plataforma, não tenta ser dashboard. Resolve um problema específico, bem.

Por baixo dos panos: SwiftPM (sem projeto Xcode), SwiftUI MenuBarExtra, lê via `lsof` + `ps`, roda em macOS 14+. Não faz telemetria, não pede privilégio elevado, é assinado e notarizado pela Apple. Código aberto sob MIT, inspirado no Portpourri (também MIT) — que eu uso há anos mas queria reescrever no meu estilo e entender cada linha.

Como nasceu: construí o app inteiro numa sessão usando Claude Code, do `swift package init` até o `.dmg` notarizado e o Homebrew Cask publicado. Sou médico de formação e construo ferramentas de IA pra saúde no dia a dia — esse foi um projeto de fim de semana pra coçar uma coceira própria de dev. Foi bom lembrar que ferramentas pequenas e focadas ainda têm espaço.

Instalar:

```
brew tap jvlegend/porteria
brew install --cask porteria
```

Ou baixar direto: https://github.com/JVLegend/PorterIA/releases/latest

Repo (issues e PRs são bem-vindos): https://github.com/JVLegend/PorterIA

Próximas versões: binário universal (Intel + Apple Silicon) e mapeamento porta → projeto, pra dar contexto de qual repo subiu aquele servidor esquecido.

#macOS #DevTools #OpenSource #Swift #Homebrew #ClaudeCode
