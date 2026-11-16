# PARTE II — Unreal Engine 5

*Projeto 1: Playground — "Pátio da Usina"*

---

# Capítulo 7 — Conhecendo a Engine

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que uma engine é — e por que ela não é "um framework" no sentido de Spring;
- instalar a Unreal Engine 5 e a toolchain C++ de forma adequada para estudo;
- criar o projeto `Vigilia` e entender cada pasta e arquivo que aparece no disco;
- entender módulos, `Build.cs`, `Target.cs`, configurações de build, a hierarquia de arquivos `.ini` e quando usar Live Coding;
- navegar no editor com fluência: viewport, Outliner, Details, Content Browser, modos de execução;
- entender **assets**, referências, redirectors e por que nunca se move um `.uasset` pelo explorador de arquivos;
- configurar controle de versão com Git + LFS (e entender por que a indústria usa Perforce);
- começar o **Projeto 1** com um *grey-box* do Pátio da Usina.

---

## Contexto

Até aqui, a Unreal foi citada como referência. Agora ela vira ferramenta de trabalho, e a primeira coisa a ajustar é a expectativa.

Quando você abre um projeto Spring Boot, o centro do universo é o **código**: o framework é uma biblioteca grande, o IDE é um editor de texto sofisticado, e "o produto" é um artefato gerado a partir do código-fonte. Quando você abre um projeto Unreal, o centro do universo é o **editor**: um programa enorme que é, ao mesmo tempo, o ambiente de autoria de conteúdo, o runtime do jogo, o depurador visual, o gerenciador de assets e a interface de dezenas de ferramentas especializadas. O seu código C++ é **carregado dentro** desse programa, como um módulo.

Essa inversão — o código vive dentro da ferramenta, e não a ferramenta em volta do código — explica boa parte do estranhamento inicial de programadores experientes com a Unreal. Este capítulo é sobre fazer as pazes com ela.

---

## 7.1 O que é uma engine

Uma engine de jogos moderna é a combinação de cinco coisas:

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                            UNREAL ENGINE                                 │
├───────────────┬───────────────┬───────────────┬───────────────┬──────────┤
│   RUNTIME     │    EDITOR     │   PIPELINE    │  FERRAMENTAS  │  BUILD   │
│               │               │  DE CONTEÚDO  │ ESPECIALIZADAS│          │
├───────────────┼───────────────┼───────────────┼───────────────┼──────────┤
│ game loop,    │ viewport,     │ importação    │ Blueprint,    │ UBT, UHT,│
│ render, física│ níveis,       │ (FBX, WAV,    │ Sequencer,    │ cooking, │
│ áudio, IA,    │ propriedades, │ PNG...),      │ Niagara,      │ packaging│
│ rede, UI,     │ Play In       │ assets,       │ Animation BP, │ por      │
│ Gameplay      │ Editor,       │ referências,  │ MetaSounds,   │ plataforma│
│ Framework     │ debug visual  │ cooking       │ UMG, Material │          │
│               │               │               │ Editor...     │          │
└───────────────┴───────────────┴───────────────┴───────────────┴──────────┘
```

> 🌉 **Ponte:** se você precisasse de um equivalente no seu mundo, seria algo como **framework + servidor de aplicação + IDE + sistema de build + banco de dados de artefatos + ferramentas low-code**, tudo num único produto, fortemente integrado.
>
> 🧱 **Onde a ponte cai:** no seu ecossistema, esses componentes são independentes e substituíveis (troca-se o IDE, o build, o servidor). Na Unreal, eles são **um só sistema**. O editor depende do runtime; o runtime é configurado pelo editor; o build gera código que o editor lê. Você não "usa a Unreal como biblioteca" — você trabalha **dentro** dela.

Uma consequência prática importante: **o editor executa o seu código de gameplay**. Quando você aperta *Play*, o jogo roda dentro do processo do editor (*Play In Editor*, PIE). Quando o seu código C++ trava, o editor trava junto. Quando ele vaza memória, o editor vaza memória. Isso torna a iteração extremamente rápida — e torna a estabilidade do seu código importante desde o primeiro dia.

---

## 7.2 Instalação

### Engine: launcher ou código-fonte?

Há duas formas de obter a Unreal:

- **Epic Games Launcher (build binária).** Instala uma versão pré-compilada. É a forma recomendada para este livro: rápida de instalar, estável e suficiente para quase tudo.
- **Código-fonte (GitHub).** O código da Unreal é acessível para quem aceita a licença e vincula a conta Epic ao GitHub. Compilar a engine leva horas e ocupa muito disco. Ela é necessária em situações específicas — notadamente, para **compilar servidores dedicados** (Parte IX) e para modificar a engine.

Decisão do livro: **use a build do launcher** até a Parte IX. Lá, discutiremos se vale compilar a engine para o experimento de servidor dedicado.

Na instalação pelo launcher, nas opções da versão, habilite **"Editor symbols for debugging"**. Sem os símbolos, os *call stacks* de crashes dentro da engine aparecem incompletos, e você vai precisar deles no primeiro crash difícil.

### Toolchain C++

No Windows, o caminho padrão é o **Visual Studio 2022** com a carga de trabalho **"Game development with C++"** (que inclui os componentes recomendados para Unreal) e um Windows SDK compatível. A documentação oficial da Unreal mantém, para cada versão da engine, a lista de versões de compilador e SDK suportadas — **confira-a para a sua versão**; incompatibilidade de toolchain é a causa número um de "o projeto não compila na primeira vez".

**JetBrains Rider** é uma alternativa muito popular para Unreal, com boa integração com reflexão, Blueprints e o sistema de build. Ainda assim, o compilador continua sendo o do Visual Studio (MSVC) — Rider é o editor, não a toolchain.

---

## 7.3 Criando o projeto Vigília

No Unreal Project Browser:

1. Categoria **Games** → template **Blank**.
2. **Project Defaults:** **C++** (não Blueprint), plataforma **Desktop**, preset de qualidade **Maximum** (ou **Scalable**, se a máquina sofrer), **Starter Content desmarcado**, ray tracing desligado.
3. Nome: **`Vigilia`**. Local: fora de pastas sincronizadas (OneDrive, Dropbox) — sincronizadores de arquivos e a Unreal brigam por arquivos temporários enormes.

**Por que Blank e não o template First Person?** O template First Person entrega um personagem, uma arma e um input prontos — e, com eles, um conjunto de decisões que não são suas e que você não entende ainda. Vamos construir essas peças nos Capítulos 10, 14, 16–18 e 25–26.

Mas há valor em ler o template. Crie **um segundo projeto, descartável**, a partir do template **First Person** (também C++), chamado `RefFirstPerson`. Ele serve como **referência de leitura**: quando um capítulo falar de Enhanced Input ou de um personagem em primeira pessoa, você pode comparar com o que a Epic fez. Não copie código dele para a Vigília sem entender cada linha.

**Por que sem Starter Content?** O pacote traz dezenas de assets genéricos que inflam o projeto e o repositório. Para *grey-box*, as formas básicas da engine (`/Engine/BasicShapes/`) e alguns materiais simples são suficientes. Se precisar de algo do Starter Content mais tarde, ele pode ser adicionado ao projeto pelo Content Browser.

---

## 7.4 Anatomia do projeto no disco

Depois de criado e compilado, o projeto tem esta estrutura:

```text
Vigilia/
├── Vigilia.uproject            descritor do projeto (JSON)
├── Config/                     configuração (.ini), versionada
│   ├── DefaultEngine.ini
│   ├── DefaultGame.ini
│   ├── DefaultInput.ini
│   └── DefaultEditor.ini
├── Content/                    assets (.uasset) e níveis (.umap), versionados
├── Source/                     código C++, versionado
│   ├── Vigilia.Target.cs           alvo "jogo"
│   ├── VigiliaEditor.Target.cs     alvo "editor"
│   └── Vigilia/                    o módulo de gameplay
│       ├── Vigilia.Build.cs            dependências e regras do módulo
│       ├── Vigilia.h / Vigilia.cpp     registro do módulo
│       └── ...                         seu código (Core/, Player/, ...)
│
├── Binaries/                   GERADO: DLLs/executáveis compilados
├── Intermediate/               GERADO: arquivos intermediários do build, código gerado pelo UHT
├── Saved/                      GERADO: logs, autosaves, crashes, configurações do usuário
├── DerivedDataCache/           GERADO: cache de dados derivados (shaders, texturas processadas)
└── Vigilia.sln                 GERADO: solução do IDE
```

### O que cada parte é

**`Vigilia.uproject`** — um JSON pequeno que diz qual versão da engine o projeto usa (`EngineAssociation`), quais módulos C++ ele tem e quais plugins estão habilitados. Clicar com o botão direito nele no Explorer oferece **"Generate Visual Studio project files"** — o comando que você vai usar sempre que adicionar arquivos `.cpp`/`.h` fora do IDE ou quando a solução se perder.

**`Config/`** — configuração em arquivos `.ini`. A Unreal usa uma **hierarquia de configuração**: valores da engine (`Base*.ini`, dentro da instalação), sobrescritos pelos `Default*.ini` do projeto, sobrescritos por configurações de plataforma, sobrescritos pelas configurações locais do usuário em `Saved/Config/`. Quando você altera algo em *Project Settings* no editor, é um desses `Default*.ini` que muda.

> 🌉 **Ponte:** a hierarquia de `.ini` é muito parecida com perfis do Spring (`application.yml` sobrescrito por `application-dev.yml`, sobrescrito por variáveis de ambiente). A regra é a mesma: **o que é do projeto vai no `Default*.ini` versionado; o que é preferência pessoal fica em `Saved/` e não é versionado.**

**`Content/`** — todos os assets e níveis, em formato binário (`.uasset`, `.umap`). É a maior parte do projeto em tamanho, e a parte que mais exige cuidado (seção 7.7).

**`Source/`** — o código. Os dois arquivos `.Target.cs` definem **alvos de build** (o jogo e o editor; mais tarde, possivelmente o servidor). O `Vigilia.Build.cs` define o **módulo** `Vigilia`: de que outros módulos da engine ele depende.

**Pastas geradas** — `Binaries`, `Intermediate`, `Saved`, `DerivedDataCache` e os arquivos de solução do IDE são **regenerados** e não devem ir para o controle de versão. Apagar `Binaries` e `Intermediate` (com o editor fechado) e regenerar os arquivos de projeto é o "limpar e recompilar" da Unreal, e resolve uma quantidade surpreendente de problemas estranhos de build.

---

## 7.5 Módulos e build

### Módulos

O código C++ da Unreal é organizado em **módulos**: unidades de compilação com dependências explícitas. A própria engine é composta por centenas deles (`Core`, `CoreUObject`, `Engine`, `InputCore`, `EnhancedInput`, `AIModule`, `UMG`...). O seu projeto começa com um, `Vigilia`.

O `Vigilia.Build.cs` gerado se parece com isto:

```csharp
// Source/Vigilia/Vigilia.Build.cs
using UnrealBuildTool;

public class Vigilia : ModuleRules
{
    public Vigilia(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[]
        {
            "Core",
            "CoreUObject",
            "Engine",
            "InputCore"
        });

        PrivateDependencyModuleNames.AddRange(new string[] { });
    }
}
```

Note três coisas:

- É **C#**, não C++. O sistema de build da Unreal (**Unreal Build Tool**, UBT) é um programa em C# que lê esses arquivos e orquestra o compilador.
- `PublicDependencyModuleNames` vs. `PrivateDependencyModuleNames`: dependências públicas são "transitivas" para quem depender do seu módulo (porque aparecem nos seus headers públicos); privadas são usadas só na implementação. Para um módulo de jogo que ninguém mais usa, a distinção importa pouco; em plugins, importa muito.
- Ao longo do livro, este arquivo vai crescer: `EnhancedInput` (Capítulo 14), `AIModule`, `NavigationSystem` e `GameplayTasks` (Parte V), `UMG` e `Slate` (Capítulo 55), `GameplayTags` (Capítulo 23). **Sempre que um include de outro módulo não compilar com erro de "símbolo não resolvido" no linker, a primeira suspeita é uma dependência faltando aqui.**

> 🌉 **Ponte:** o `Build.cs` é o `pom.xml`/`build.gradle` do módulo. A diferença é que ele não baixa nada: todos os módulos já estão na engine instalada.

### Unreal Header Tool

Antes de compilar, o UBT executa o **Unreal Header Tool** (UHT), que lê os seus headers procurando as macros de reflexão (`UCLASS`, `UPROPERTY`, `UFUNCTION`, `USTRUCT`, `UENUM`) e **gera código C++** — os arquivos `*.generated.h` e `*.gen.cpp` em `Intermediate/`. É assim que o editor sabe que a sua classe existe, quais propriedades ela tem e como chamar suas funções a partir de Blueprint. O Capítulo 11 explica o mecanismo; por ora, saiba que é por isso que todo header de classe reflexiva inclui `NomeDaClasse.generated.h` **como o último include**.

### Configurações de build

| Configuração | Otimização | Uso |
|---|---|---|
| **DebugGame Editor** | Seu código sem otimização, engine otimizada | Depurar o seu código passo a passo no editor |
| **Development Editor** | Otimizado, com ferramentas de debug | **O dia a dia** no editor |
| **Development** | Jogo standalone otimizado, com console e stats | Testar o jogo fora do editor |
| **Test** | Quase Shipping, mantém alguns recursos de profiling | Testes de performance próximos do final |
| **Shipping** | Máxima otimização, sem console, sem debug | O que vai para o jogador |

Use **Development Editor** no dia a dia. Quando precisar depurar uma função sua com breakpoints e inspecionar variáveis (que em código otimizado aparecem como "optimized away"), troque para **DebugGame Editor**.

### Live Coding

O **Live Coding** permite recompilar e aplicar mudanças em arquivos `.cpp` **com o editor aberto** (no editor, `Ctrl+Alt+F11`, ou pelo botão de compilação). É excelente para iterar em corpos de funções. Ele é menos confiável para mudanças estruturais: adicionar ou remover `UPROPERTY`/`UFUNCTION`, mudar o layout de uma classe reflexiva, adicionar classes novas.

Regra prática do livro:

- **Mudou só o corpo de funções em `.cpp`?** Live Coding.
- **Mudou um header de classe reflexiva, adicionou uma classe ou mexeu no `Build.cs`?** Feche o editor, compile pelo IDE, abra de novo.

Isso parece lento no começo. É muito mais rápido do que perder uma tarde com um Blueprint corrompido por uma recompilação estrutural com o editor aberto.

---

## 7.6 O editor

### As áreas principais

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ Menu │ Toolbar: Modos · Adicionar · Blueprints · Cinemáticas · ▶ Play  ⋮     │
├──────────────────────────────────────────────────────────┬───────────────────┤
│                                                          │    OUTLINER       │
│                                                          │ todos os atores   │
│                      VIEWPORT                            │ do nível atual    │
│              o nível, editado em 3D                      ├───────────────────┤
│                                                          │    DETAILS        │
│                                                          │ propriedades do   │
│                                                          │ que está          │
│                                                          │ selecionado       │
├──────────────────────────────────────────────────────────┴───────────────────┤
│ CONTENT BROWSER (assets do projeto)   │  OUTPUT LOG / CONSOLE                │
└──────────────────────────────────────────────────────────────────────────────┘
```

- **Viewport** — o nível em 3D. Navegação essencial: segurar o botão direito + `WASD`/`QE` para voar; `F` para focar no objeto selecionado; `G` para alternar a visão de jogo (esconde ícones e gizmos); `W`/`E`/`R` para mover/rotacionar/escalar; `Alt` + arrastar para duplicar; `End` para "soltar" o objeto no chão.
- **Outliner** — a lista de todos os atores no nível. É a sua visão "de inventário" do mundo; organize em pastas.
- **Details** — as propriedades do objeto selecionado. É aqui que as `UPROPERTY(EditAnywhere)` do seu código aparecem.
- **Content Browser** — os assets do projeto, como um explorador de arquivos — mas com consciência de referências (seção 7.7). Uma *drawer* rápida abre com `Ctrl+Espaço`.
- **Output Log** — logs (`UE_LOG`) e o **console** (também acessível com a tecla `~` durante o jogo), onde se digitam comandos como `stat unit`, `t.MaxFPS 30` e `slomo 0.2` dos capítulos anteriores.

### Modos de execução

| Modo | O que faz | Uso |
|---|---|---|
| **PIE (Selected Viewport)** | Roda o jogo dentro do viewport do editor | Iteração diária |
| **PIE (New Editor Window)** | Roda o jogo numa janela separada, no mesmo processo | Testar resolução e input; vários clientes em multiplayer |
| **Simulate** | Roda a simulação sem possuir um jogador; você continua com a câmera do editor | Observar IA e física "de fora" |
| **Standalone Game** | Abre o jogo em um processo separado | Aproximar o comportamento do jogo real |

Durante o PIE, `F8` **ejeta** você do jogador: o jogo continua rodando e você volta a voar com a câmera do editor, podendo selecionar atores e ver suas propriedades **ao vivo** no Details. É uma das ferramentas de depuração mais poderosas da engine — o equivalente a pausar um sistema em produção e inspecionar o estado de qualquer objeto, sem parar o sistema.

Um detalhe importante: **mudanças feitas em atores durante o PIE são descartadas ao parar**. Isso é proposital (você está mexendo no mundo de jogo, não no nível salvo). Se quiser manter uma alteração feita em PIE, há a opção *Keep Simulation Changes* no menu de contexto do ator, ou a tecla `K`.

### Project Settings vs. Editor Preferences vs. World Settings

- **Project Settings** — configurações do **projeto**, versionadas nos `Default*.ini`: mapas padrão, GameMode padrão, input, física, renderização.
- **Editor Preferences** — preferências **suas**, do editor, em `Saved/`: atalhos, aparência, comportamento do viewport.
- **World Settings** — configurações **de um nível específico**, salvas no `.umap`: GameMode deste nível, limites, opções de mundo.

Confundir os três é comum no início ("mudei a configuração e o meu colega não viu" → era Editor Preferences).

---

## 7.7 Assets e referências

Um **asset** é qualquer coisa que o editor gerencia como conteúdo: malhas, texturas, materiais, sons, Blueprints, Data Assets, níveis. Cada asset é um arquivo binário `.uasset` (níveis são `.umap`) dentro de `Content/`, e é identificado por um **caminho de objeto**, como `/Game/Vigilia/Maps/L_Patio` (`/Game/` corresponde à pasta `Content/` do projeto; `/Engine/` aos assets da engine).

### Referências

Assets referenciam outros assets: um Blueprint referencia uma malha, que referencia materiais, que referenciam texturas. Essas referências são **gravadas dentro do arquivo binário**, pelo caminho do asset referenciado. Há dois tipos fundamentais:

- **Referência forte (*hard reference*):** carregar o asset A **carrega automaticamente** B. Simples, e perigosa: uma cadeia de referências fortes pode fazer um único Blueprint arrastar centenas de megabytes de assets para a memória. É a causa mais comum de tempos de carregamento e uso de memória inexplicáveis (Capítulos 12 e 57).
- **Referência fraca (*soft reference*):** A guarda o **caminho** de B, mas B só é carregado quando alguém pedir. Usada para conteúdo opcional ou carregado sob demanda.

O editor tem duas ferramentas para enxergar isso: o **Reference Viewer** (quem referencia quem) e o **Size Map** (quanto de memória um asset arrasta consigo). Use as duas cedo, para criar o hábito.

### A regra de ouro: mova e renomeie pelo editor

Como as referências estão gravadas dentro dos binários, **mover ou renomear um `.uasset` pelo explorador de arquivos quebra todas as referências a ele**, silenciosamente. O editor só descobre quando tenta carregar.

Quando você move ou renomeia **pelo Content Browser**, o editor faz duas coisas: atualiza as referências dos assets carregados e deixa no lugar antigo um **redirector** — um pequeno asset que diz "o que estava aqui agora está ali". Redirectors evitam quebras, mas acumulam. Periodicamente, use **Fix Up Redirectors** (clique direito numa pasta do Content Browser) para atualizar todas as referências e remover os redirectors.

Para apagar um asset que ainda é referenciado, o editor oferece substituir as referências por outro asset — use isso em vez de apagar e torcer.

> 🌉 **Ponte:** referências entre assets são **chaves estrangeiras** num banco de dados binário. Mover um arquivo pelo Explorer é como alterar a chave primária de uma linha por fora do banco, sem atualizar as chaves estrangeiras. O Content Browser é o "refactor seguro" do IDE; o Explorer é o `mv` no terminal.

### Convenções de nome e pastas

As convenções da Introdução (seção 6.3) valem a partir de agora. Para níveis, o projeto usa o prefixo `L_`:

```text
/Game/Vigilia/
├── Maps/          L_Patio, L_CasaDeForca, ...
├── Blueprints/    BP_...
├── Data/          DA_...
├── Materials/     M_..., MI_...
├── Meshes/        SM_...
└── ...
/Game/Developers/  experimentos pessoais (nunca referenciados por conteúdo de produção)
```

---

## 7.8 Do editor ao jogo: cooking e packaging

O jogo que roda no editor **não é** o jogo que o jogador recebe. Para gerar o jogo distribuível, a engine faz:

1. **Compilação** do código para a configuração de destino (Development ou Shipping).
2. **Cooking:** converte os assets do formato do editor para o formato otimizado da plataforma de destino (texturas comprimidas, shaders compilados, dados de editor removidos) — **e inclui apenas os assets alcançáveis** a partir dos níveis e das referências configuradas.
3. **Packaging:** agrupa tudo em arquivos de pacote e gera o executável.

Duas consequências que vão aparecer mais cedo do que você imagina:

- **"Funciona no editor, quebra no jogo empacotado."** Um asset carregado por caminho em texto (e não por referência) pode não ser incluído no cooking. Código dentro de `#if WITH_EDITOR` não existe no jogo. Diferenças de *timing* entre PIE e standalone revelam dependências de ordem.
- **Empacote cedo e com frequência.** O Capítulo 62 trata disso em detalhe, mas a recomendação começa agora: ao final de cada projeto, gere uma build Development e jogue fora do editor.

---

## 7.9 Controle de versão

Projetos Unreal têm um problema que você raramente encontra em sistemas corporativos: **a maior parte dos arquivos é binária e não pode ser mesclada**. Se duas pessoas editarem o mesmo `.umap` ao mesmo tempo, uma das alterações será perdida — não há `merge` possível.

As respostas da indústria são:

- **Perforce (P4, antigo Helix Core)** — o padrão em estúdios: lida bem com repositórios enormes e arquivos binários, e tem **bloqueio exclusivo de arquivos** (*exclusive checkout*): quem está editando um nível o "tranca". A própria Epic usa Perforce, e a Unreal tem integração nativa. Há licenciamento gratuito para equipes pequenas (verifique as condições atuais).
- **Git + Git LFS** — Git para código e texto; **Large File Storage** para binários, que ficam fora do histórico principal e são baixados sob demanda. Com **LFS locking**, é possível trancar arquivos binários de forma parecida com o Perforce.

Para um projeto individual de estudo, **Git + LFS é suficiente e é o que o livro usa.** O bloqueio de arquivos importa pouco quando você é o único autor — mas configure-o mesmo assim, para aprender o fluxo.

### Configuração

Na raiz do repositório:

```gitignore
# .gitignore — projeto Unreal
Binaries/
Intermediate/
Saved/
DerivedDataCache/
.vs/
.idea/
*.sln
*.suo
*.VC.db
*.opensdf
*.sdf
Plugins/**/Binaries/
Plugins/**/Intermediate/
```

```gitattributes
# .gitattributes — binários da Unreal e de conteúdo no LFS, com locking
*.uasset   filter=lfs diff=lfs merge=lfs -text lockable
*.umap     filter=lfs diff=lfs merge=lfs -text lockable
*.fbx      filter=lfs diff=lfs merge=lfs -text
*.png      filter=lfs diff=lfs merge=lfs -text
*.tga      filter=lfs diff=lfs merge=lfs -text
*.wav      filter=lfs diff=lfs merge=lfs -text
*.psd      filter=lfs diff=lfs merge=lfs -text
```

E, uma única vez na máquina:

```bash
git lfs install
```

Fluxo de trabalho:

- **Commit pequeno e frequente**, sempre com o projeto compilando e o jogo executável (Introdução, seção 9.2).
- **Feche o editor antes de operações grandes de Git** (troca de branch, rebase, pull com muitos assets): o editor mantém arquivos abertos e não "percebe" assets trocados por baixo dele.
- **Nunca resolva conflito em `.uasset` como texto.** Escolha uma versão inteira (`ours`/`theirs`) e refaça a alteração perdida.
- Para conteúdo no repositório remoto, verifique a **cota de armazenamento LFS** do provedor (GitHub, Azure DevOps, GitLab têm políticas diferentes). Você já usa Azure no trabalho; o Azure Repos suporta Git LFS e é uma opção natural.

O editor tem integração com controle de versão (*Revision Control*), com suporte a Perforce e a Git (este último por plugin). Para Git, muitos desenvolvedores preferem usar o cliente de Git fora do editor e manter a integração desligada — escolha o que funcionar melhor para você, mas não misture os dois de forma descuidada.

> **Nota sobre níveis:** o recurso **One File Per Actor**, associado ao World Partition (Capítulo 60), salva cada ator de um nível em um arquivo próprio, reduzindo drasticamente conflitos em níveis editados por várias pessoas. Para a Vigília, com níveis pequenos e um único autor, não é necessário agora.

---

## 7.10 Performance do editor

O editor da Unreal 5 é exigente, especialmente com **Lumen** (iluminação global dinâmica) e **Nanite** ativos. Se a máquina sofrer:

- **Settings → Engine Scalability Settings** no viewport: reduza para *Medium* ou *Low* enquanto faz grey-box. (Isso afeta só o editor, não o projeto.)
- Desligue o modo **Realtime** do viewport quando não estiver olhando para ele.
- Em *Editor Preferences*, mantenha habilitado **"Use Less CPU when in Background"** — o editor reduz o consumo quando a janela não está em foco.
- Limite a taxa do editor com `t.MaxFPS 60` no console.

Para o Projeto 1, a qualidade visual não importa: importam escala, espaço e fluxo.

---

## Comparação com o desenvolvimento tradicional

| Conceito Unreal | Equivalente que você conhece | Diferença essencial |
|---|---|---|
| Editor + runtime | IDE + servidor de aplicação | O jogo roda **dentro** do editor; crash do código = crash do editor |
| `.uproject` | `pom.xml` / `settings.gradle` | Também declara plugins e a versão da engine |
| `Build.cs` | Dependências de módulo (Maven/Gradle) | Não baixa nada; módulos já estão na engine |
| UHT (código gerado) | Annotation processors (Lombok, MapStruct) | Gera a camada de reflexão que alimenta editor, Blueprint, GC e rede |
| Hierarquia de `.ini` | Perfis Spring / configuração em camadas | Editor escreve nos `.ini`; projeto vs. usuário |
| Assets e referências | Artefatos com dependências / FKs | Referências dentro de binários; mover pelo Explorer quebra |
| Cooking | Build de produção / tree-shaking | Só entra o que é alcançável; formato por plataforma |
| Git LFS + locking | Git | Binários não mesclam; bloqueio substitui merge |

---

## Projeto 1 — Pátio da Usina: começo

### O que é o Projeto 1

O Projeto 1 atravessa toda a Parte II (Capítulos 7 a 15). Ao final dele, você terá **uma cena 3D explorável em primeira pessoa**: o pátio externo da Usina de Serra Funda, à noite, com escala humana correta, iluminação básica, alguns objetos com comportamento, colisão e um personagem que anda, pula e interage com o mundo.

Cada capítulo da Parte II adiciona uma camada:

| Capítulo | O que o Pátio ganha |
|---|---|
| 7 | Projeto, repositório, nível grey-box com escala humana |
| 8 | Atores com ciclo de vida (spawn, destruição) |
| 9 | Componentes: lâmpadas com falha, objetos compostos |
| 10 | GameMode, PlayerController e Character do projeto |
| 11–13 | Código C++ da Vigília exposto ao Blueprint, com a regra de camadas |
| 14 | Enhanced Input: andar, olhar, pular, interagir |
| 15 | Colisão, triggers e física: o pátio fica "sólido" e reativo |

### Entregáveis deste capítulo

1. O projeto `Vigilia` criado (C++, Blank, sem Starter Content), compilando em **Development Editor**.
2. Repositório Git com o `.gitignore` e o `.gitattributes` acima, LFS habilitado, primeiro commit.
3. As pastas de código da Introdução criadas em `Source/Vigilia/` (mesmo vazias), e as classes dos Capítulos 2–6 (`AVGTickProbe`, `AVGSmoothingProbe`, `VGMathUtils.h`, `UVGBatteryComponent`, `UVGTimeDilationSubsystem` e os testes), se você ainda não as criou.
4. O nível **`L_Patio`** em `/Game/Vigilia/Maps/`, configurado como mapa padrão do editor e do jogo (*Project Settings → Maps & Modes*).
5. Um `DEVLOG.md` na raiz com a primeira entrada.

### Escala: a primeira regra de grey-box

Na Unreal, **1 unidade = 1 centímetro**. A primeira coisa que um grey-box precisa acertar é a escala humana — erros de escala são percebidos instantaneamente em primeira pessoa (tudo parece "de brinquedo" ou "de gigante"), e corrigi-los depois de construir o nível é caro.

Métricas de partida (serão refinadas no Capítulo 50):

```text
Altura dos olhos de um personagem adulto ......... ~160–170 cm
Cápsula de um personagem (altura total) .......... ~180 cm
Porta padrão ...................................... 100 × 220 cm
Porta industrial / portão de veículo .............. 400 × 450 cm
Corredor confortável .............................. ≥ 200 cm de largura
Pé-direito de corredor ............................ 300 cm
Degrau ............................................ ~18 cm de altura, ~28 cm de piso
Muro baixo (cobertura agachado) ................... ~100 cm
Muro alto (bloqueia visão) ........................ ≥ 250 cm
```

### O layout do Pátio

Um primeiro esboço, visto de cima. Não é um design final; é um espaço para testar movimento, visão e escala. Use cubos e cilindros de `/Engine/BasicShapes/` escalados.

```text
                                 N
          ┌────────────────────────────────────────────────────┐
          │                                                    │
          │   ┌──────────┐                ┌───────────────┐   │
          │   │ CAIXA    │                │   CASA DE     │   │
          │   │ D'ÁGUA   │                │   FORÇA       │   │
          │   │ (cilindro│                │ (porta grande,│   │
          │   │  alto)   │                │  fechada)     │   │
          │   └──────────┘                └───────┬───────┘   │
          │                                       │ escada    │
          │        ┌──────────────────┐           │           │
          │        │   SUBESTAÇÃO     │       ○ poste         │
          │        │ (área cercada,   │                       │
          │        │  "transformadores")           ┌──────┐  │
          │        └──────────────────┘            │GALPÃO│  │
          │                                        └──────┘  │
          │   ○ poste          estrada interna                │
          │   ════════════════════════════════════════        │
          │                     ┌────────┐                    │
          │                     │GUARITA │   ○ poste          │
          ├──────── PORTÃO ─────┴────────┴────────────────────┤
          │   (ponto de início do jogador)                    │
          └───────────────────────────────────────────────────┘
                     ~ 80 m × 60 m (8.000 × 6.000 unidades)
```

Requisitos do grey-box:

- **Piso** de 80 × 60 m e um **muro perimetral** alto (impede o jogador de sair e define o espaço).
- **Guarita** com porta e interior pequeno (um cômodo de 3 × 3 m) — teste de escala de interior.
- **Subestação** cercada (cerca = cubos finos e altos) com alguns "transformadores" (cubos).
- **Casa de Força** como um bloco grande com uma porta de 4 m e uma escada de acesso — ela será o cenário do Projeto 4.
- **Caixa d'água** (cilindro alto) como **marco visual**: um elemento visível de qualquer ponto, para orientação.
- **Galpão** (o futuro "Galpão de Testes" do Projeto 2).
- Três ou quatro **postes** (cilindro fino + uma Point Light ou Spot Light no topo).
- **Luz:** uma *Directional Light* fraca e azulada (lua), uma *Sky Light* de baixa intensidade e as luzes dos postes. O objetivo é **noite legível**, não escuridão total.
- **Ponto de início** (*Player Start*) no portão.

Para testar o espaço antes de existir um personagem: o template Blank usa um pawn padrão que **voa**. Isso basta para avaliar escala e composição. Desça com a câmera até a altura dos olhos (~165 cm) e caminhe mentalmente pelo pátio. No Capítulo 10, você terá um personagem de verdade.

> **Ferramenta opcional:** o modo **Modeling** do editor permite criar e editar geometria simples (caixas, extrusões, cortes) diretamente no nível, útil para grey-box. Para o Projeto 1, formas básicas escaladas são suficientes.

---

## Decisões arquiteturais

1. **Engine pelo launcher**, com símbolos de debug; código-fonte só se a Parte IX exigir.
2. **Projeto Blank em C++**, sem Starter Content. Template First Person apenas como referência de leitura em projeto separado.
3. **Development Editor** no dia a dia; **DebugGame Editor** para depurar o próprio código.
4. **Live Coding só para corpos de função.** Mudanças em headers reflexivos: fechar o editor e compilar pelo IDE.
5. **Assets só se movem e renomeiam pelo Content Browser**, com *Fix Up Redirectors* periódico.
6. **Git + LFS com locking**, commits pequenos com o projeto sempre executável, editor fechado em operações grandes.
7. **`/Game/Developers/` para experimentos**, `/Game/Vigilia/` para produção; níveis com prefixo `L_`.
8. **Escala humana documentada** no grey-box desde o primeiro dia.

---

## Armadilhas

- **Projeto em pasta sincronizada** (OneDrive, Dropbox).
- **Toolchain incompatível** com a versão da engine.
- **Mover assets pelo Explorer.**
- **Versionar `Binaries/`, `Intermediate/`, `Saved/` ou `DerivedDataCache/`.**
- **Esquecer o LFS** e versionar binários direto no Git — o repositório incha permanentemente.
- **Live Coding para mudanças estruturais** com o editor aberto.
- **Confundir Project Settings, Editor Preferences e World Settings.**
- **Perder mudanças feitas em PIE** achando que estavam salvas.
- **Grey-box sem escala** — começar a "decorar" antes de acertar dimensões.
- **Só testar no editor.** Empacote ao final de cada projeto.

---

## Exercício

**Parte 1 — instalação e projeto (2 h).** Instale a engine e a toolchain, crie o projeto `Vigilia` e o projeto de referência `RefFirstPerson`. Configure o repositório (`.gitignore`, `.gitattributes`, `git lfs install`) e faça o primeiro commit. Confirme com `git lfs ls-files` que um `.umap` salvo foi para o LFS.

**Parte 2 — anatomia (45 min).** Abra o `Vigilia.uproject` num editor de texto e explique cada campo. Altere uma configuração em *Project Settings* (por exemplo, o mapa padrão) e descubra qual `Default*.ini` mudou com `git diff`. Feche o editor, apague `Binaries/` e `Intermediate/`, regenere os arquivos de projeto e compile novamente.

**Parte 3 — editor (1 h).** No nível vazio, pratique: voar, focar (`F`), duplicar com `Alt`, alinhar ao chão (`End`), organizar o Outliner em pastas, entrar em PIE, ejetar (`F8`), selecionar um ator durante o jogo e alterar uma propriedade ao vivo; parar e verificar que a alteração sumiu.

**Parte 4 — assets (30 min).** Crie um material simples em `/Game/Developers/`, aplique-o a um cubo no nível, depois mova o material para `/Game/Vigilia/Materials/` pelo Content Browser. Observe o redirector criado; rode *Fix Up Redirectors*. Abra o Reference Viewer do material.

**Parte 5 — Pátio (2–3 h).** Construa o grey-box do Pátio com as métricas e o layout deste capítulo. Coloque um `AVGSmoothingProbe` do Capítulo 3 no pátio como teste de que o código C++ está vivo dentro do nível.

---

## Desafio — o primeiro empacotamento

Empacote o projeto em **Development** para Windows (*Platforms → Windows → Package Project*, ou o caminho equivalente na sua versão) e rode o executável fora do editor. Responda no `DEVLOG.md`:

1. Quanto tempo levou o primeiro cooking? E o segundo, sem mudanças? Por quê?
2. Qual o tamanho do pacote? Abra o log de cooking e descubra quais assets da engine foram incluídos sem você ter pedido.
3. O console (`~`) funciona no build Development? Teste `stat unit` fora do editor e compare com os números do PIE. Por que são diferentes?

---

## Uso de IA

1. **Para decifrar erros de build:**
   > "Estou compilando um projeto Unreal Engine 5 [versão] com Visual Studio 2022 e recebi este erro: [erro completo]. Explique a causa provável, em que etapa (UHT, compilação, linker) ele acontece, e uma lista ordenada de verificações — começando pelas mais prováveis (dependência faltando no Build.cs, include errado, arquivos de projeto desatualizados, toolchain incompatível)."

2. **Para entender configuração:**
   > "Explique a hierarquia de arquivos de configuração .ini da Unreal Engine 5 (Base, Default, plataforma, Saved). Para cada camada, diga quem escreve nela, se deve ser versionada e dê um exemplo de configuração que pertence a ela. Indique quando não tiver certeza de um detalhe para a minha versão."

3. **Para revisar o grey-box:**
   > "Vou descrever o layout de um nível grey-box em primeira pessoa para um jogo de terror [descrição e medidas]. Revise como um level designer: problemas de escala, falta de marcos visuais para orientação, áreas sem propósito, linhas de visão longas demais ou curtas demais para um jogo de tensão."

**Cuidado específico:** caminhos de menu, nomes de janelas e opções do editor mudam entre versões do UE5. Se a IA indicar um menu que não existe na sua versão, use a busca das *Project Settings* e do *Editor Preferences* (ambas têm campo de pesquisa) em vez de seguir o caminho literal.

---

## Checklist

- [ ] Sei explicar por que uma engine é mais que um framework, e por que o editor executa o meu código.
- [ ] O projeto `Vigilia` compila em Development Editor, e eu sei regenerar os arquivos de projeto.
- [ ] Sei o que é cada pasta do projeto e quais são versionadas.
- [ ] Entendo `Build.cs`, `Target.cs`, UHT e as configurações de build.
- [ ] Sei quando usar Live Coding e quando fechar o editor e compilar.
- [ ] Navego no editor com fluência e sei usar PIE, Simulate e ejetar (`F8`).
- [ ] Sei a diferença entre Project Settings, Editor Preferences e World Settings.
- [ ] Entendo referências fortes e fracas, redirectors e por que nunca mover assets pelo Explorer.
- [ ] Configurei Git + LFS com locking.
- [ ] O grey-box do Pátio existe, com escala humana, e é o mapa padrão.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — seções sobre a interface do editor, estrutura de diretórios de projetos, Unreal Build Tool, arquivos de configuração e configuração do Visual Studio para Unreal.
- **Git LFS** (git-lfs.com) — documentação oficial, incluindo *file locking*.
- **UE5 Style Guide** (Allar, no GitHub) — convenções de nomes e organização de assets amplamente adotadas pela comunidade.

---

➡️ **Próximo:** [Capítulo 8 — Actors](cap-08-actors.md)
