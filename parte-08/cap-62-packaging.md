# Capítulo 62 — Packaging

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que muda entre o jogo no editor e o jogo empacotado: alvos, configurações de build, assets cozidos;
- escolher a configuração certa para cada uso (Debug, DebugGame, Development, Test, Shipping);
- entender o *cooking*: o que entra no build, o que fica fora, e por que algo "funciona no PIE e some no build";
- conhecer o formato do build: arquivos *pak*, IoStore, compressão, *chunks*, a pasta empacotada;
- listar o que o Shipping remove (console, cheats, *stats*, logs, asserções, ferramentas de depuração) e os bugs que só aparecem ali;
- empacotar a Vigília com um *script* reproduzível, com testes antes, símbolos arquivados e versão gravada;
- validar um build numa máquina limpa.

---

## Contexto

O Capítulo 7 deixou uma recomendação: "empacote cedo e com frequência". Ela ficou para trás enquanto a Vigília crescia, e o custo de ignorá-la aparece agora, de uma vez: um jogo que só rodou no editor tem, quase com certeza, assets que não vão para o build, código que depende do editor e configurações que só existem na máquina de quem o fez.

As peças estão espalhadas pelo livro:

- o **Capítulo 76** definiu o Milestone 10 ("um executável que outra pessoa roda", com o critério "o build roda numa máquina limpa") e decidiu que "mapas e conteúdo de estudo (Galpão, Arena, protótipos da Parte X) ficam fora do build de lançamento pelas regras de *cook*";
- o **Capítulo 48** listou documentos pelo Asset Manager (tipo `VGDocument`), e o **Capítulo 46** apontou as regras de fatos por uma configuração de projeto;
- o **Capítulo 56** gravou `BuildVersion` em cada save e deixou para cá o caminho dos saves no build;
- os **Capítulos 58 e 59** pediram números numa configuração próxima da final;
- o **Capítulo 59** deixou a hipótese H3: o *hitch* de compilação de PSO na primeira aparição da Presença;
- o **Capítulo 61** pôs todas as ferramentas de depuração atrás das macros da engine e prometeu conferir que elas somem do Shipping, além de arquivar símbolos para ler *crashes*;
- o **Capítulo 11** criou `vg.Flicker.Enabled` como opção de acessibilidade, e ela precisa existir num jogo sem console.

Este capítulo produz o primeiro build da Vigília que outra pessoa consegue rodar, e encerra a Parte VIII.

---

## 62.1 Do editor ao executável

No editor, o jogo roda com o código do editor carregado, lê os assets no formato de edição (que inclui dados que só o editor usa), compila *shaders* sob demanda e tem acesso a todo o conteúdo do projeto. Um build empacotado não tem nada disso: ele roda o código do jogo, lê assets **cozidos** para a plataforma, traz *shaders* pré-compilados e só contém o conteúdo que o processo de *cook* decidiu incluir.

### Alvos

O `.Target.cs` define **o que** se compila. Um projeto tem, tipicamente, um alvo `Game` (o jogo autônomo) e um `Editor` (o editor com o seu módulo). Projetos com rede podem ter `Client` e `Server` separados (Interlúdio III).

### Configurações

| Configuração | Otimização | Console e cheats | *Stats* e *trace* | Logs | `check`/`ensure` | Para quê |
|---|---|---|---|---|---|---|
| **Debug** | Nenhuma (engine e jogo) | Sim | Sim | Sim | Sim | Depurar a engine; exige engine compilada do código-fonte |
| **DebugGame** | Engine otimizada, seu módulo não | Sim | Sim | Sim | Sim | Depurar **o seu** código com desempenho aceitável (Cap. 61) |
| **Development** | Sim | Sim | Sim | Sim | Sim | O dia a dia: editor, playtests internos |
| **Test** | Sim | Console sim | Sim | Configurável | Como Shipping | **Medir** e testar algo próximo do produto final |
| **Shipping** | Máxima | **Não** | **Não** | **Não** (padrão) | **Não** (padrão) | O que a jogadora recebe |

(⚠️ Os detalhes de Test variam entre versões e regras de *target*; a ideia constante é "Shipping com as ferramentas de medição".)

A coluna mais importante é a de Test. Ela responde a uma pergunta dos Capítulos 58 e 59: "medi em Development; quanto disso é custo de ferramenta?". Números de orçamento finais vêm de Test.

---

## 62.2 *Cooking*

***Cook*** é o processo que transforma o conteúdo do projeto no formato que o jogo empacotado lê: assets convertidos para a plataforma (texturas comprimidas no formato da GPU-alvo, áudio no formato do dispositivo), dados de editor removidos, *shaders* compilados para cada combinação de material e plataforma, referências resolvidas. A maior parte do tempo de *cook* costuma ser compilação de *shaders*, e o *Derived Data Cache* (DDC) é o que torna os *cooks* seguintes mais rápidos.

### O que entra no build

O *cook* parte de raízes e segue referências:

1. **Os mapas** da lista *Maps to Include in a Packaged Build* (ou **todos** os mapas, se a lista estiver vazia), além dos mapas padrão configurados em *Maps & Modes*.
2. **Tudo o que esses mapas referenciam**, transitivamente: Blueprints, malhas, materiais, Data Assets, sons.
3. **Os *primary assets*** do Asset Manager, conforme a regra de *cook* de cada tipo (sempre cozinhar, nunca, ou só se referenciado).
4. **Os diretórios** de *Additional Asset Directories to Cook*.
5. Referências *soft* encontradas nos pacotes cozidos são seguidas (⚠️ o comportamento exato para referências que só existem em arquivos de configuração varia; não dependa dele).

E **fica fora**: os diretórios de *Directories to Never Cook*, o que nada referencia, e os dados de editor.

> 🌉 **Ponte:** é o empacotador de um *front-end* com *tree shaking*: parte das entradas, segue os `import` e descarta o que ninguém alcança.
>
> 🧱 **Onde a ponte cai:** o empacotador de *front-end* reclama na hora de um `import` quebrado. O *cook* não sabe de um asset que o seu código carrega por um **caminho montado em execução** (`"/Game/Data/" + Nome`), nem, com segurança, de um asset apontado só por uma configuração. Ele simplesmente não inclui, e o erro aparece **no build**, na máquina de outra pessoa, como "nada acontece". O equivalente de "funciona no meu *dev server*, quebra em produção" é, aqui, a frase "funciona no PIE".

### Os suspeitos de "funciona no PIE" na Vigília

| Asset | Como é alcançado | Risco | Proteção |
|---|---|---|---|
| `DA_FatosDoJogo` (Cap. 46) | Só pela configuração de projeto (`UVGNarrativeSettings`) | Alto | Diretório sempre cozido |
| Documentos `DA_Doc_*` (Cap. 48) | Pelos `AVGReadable` no nível **e** pela lista do Asset Manager (arquivo) | Médio: um documento lido em outro lugar sem ator | Tipo `VGDocument` registrado com regra "sempre cozinhar" |
| Quests e conversas | Pelo nível e pelos registros de quest (`TSoftObjectPtr`) | Baixo | Primary assets registrados |
| Mapas de estudo (Galpão, Arena, laboratório do Interlúdio II) | Pela lista de mapas | Inverso: entrar sem querer | Lista explícita de mapas; `/Game/Developers` nunca cozido |

O último item é o caso inverso, e ele também importa: **tudo o que o *cook* inclui vai para a jogadora**, inclusive o que nenhum menu alcança. O estudo de caso deste capítulo mostra o que isso pode custar.

---

## 62.3 Pak, IoStore e o formato do build

Depois do *cook*, os arquivos são organizados em contêineres:

- **`.pak`**: o contêiner clássico da Unreal, um arquivo que agrupa muitos pacotes, com índice e compressão.
- **IoStore** (`.utoc` + `.ucas`): o contêiner otimizado do carregador da Unreal 5 (*Zen loader*), ativado por padrão no empacotamento do UE5 (*Use Io Store*). Ele organiza os dados para carregamento mais rápido. O `.pak` continua existindo ao lado dele, com o que não é pacote.
- **Compressão**: os contêineres são comprimidos (a engine usa Oodle por padrão nas versões recentes; ⚠️ confira as opções de compressão na sua versão).
- ***Chunks***: o conteúdo pode ser dividido em vários contêineres (regras do Asset Manager e *Primary Asset Labels*) para *downloads* parciais, DLC e *patches* menores. A Vigília cabe num só.
- **Criptografia e assinatura**: *Project Settings → Crypto* permite criptografar os contêineres e assinar os arquivos, o que dificulta extração e modificação. Não impede quem estiver determinado; para a Vigília, não é necessário.

A pasta de um build Windows empacotado tem, aproximadamente, esta forma:

```text
Windows/
├── Vigilia.exe                         ← lançador pequeno, que chama o executável real
├── Vigilia/
│   ├── Binaries/Win64/
│   │   └── Vigilia-Win64-Shipping.exe  ← o jogo
│   └── Content/Paks/
│       ├── pakchunk0-Windows.pak
│       ├── pakchunk0-Windows.utoc
│       └── pakchunk0-Windows.ucas
└── Engine/                             ← o mínimo da engine que o jogo usa
```

Com a opção de pré-requisitos ligada, o build traz o instalador das bibliotecas de execução de que a engine precisa no Windows. Uma máquina limpa sem elas não abre o jogo, e o erro não diz por quê; o teste de máquina limpa existe para pegar exatamente isso.

---

## 62.4 O que muda em Shipping

O Shipping não é "Development mais rápido". É outro programa, com partes inteiras ausentes:

| O que | Em Shipping (padrão) | Consequência para a Vigília |
|---|---|---|
| Console (`~`) | Não existe | Nenhuma CVar e nenhum comando digitado; **`vg.Flicker.Enabled` precisa estar no menu de opções** |
| Cheat manager | Não é compilado (`UE_WITH_CHEAT_MANAGER` é falso) | `VGSave`, `VGGod`, `VGPerfHunt` e os outros não existem |
| *Stats* | Removidos | `stat Vigilia` e os `SCOPE_CYCLE_COUNTER` somem; custo zero |
| Logs | Removidos | Nenhum `UE_LOG`; nenhum arquivo de log |
| `check` e `ensure` | Removidos (as expressões de `verify` e `ensure` continuam avaliadas) | Código dentro de `check` **não roda** |
| *Draw debug*, Visual Logger, Gameplay Debugger | Removidos | As categorias do Cap. 61 somem com o módulo |
| Testes de automação | Removidos | Os testes rodam **antes** de empacotar |
| Código e dados de editor (`WITH_EDITOR`) | Removidos | `IsDataValid` não existe; validação acontece no editor |
| Pasta `Saved` | Na pasta do usuário (no Windows, sob `%LOCALAPPDATA%`; ⚠️ confira no seu build) | Os saves do Cap. 56 vão para lá |
| Arquivos `.ini` de desenvolvimento | Parte deles não é lida (⚠️ por exemplo, o `ConsoleVariables.ini` da engine) | Valores que você ajustou "no console da sua máquina" não existem |

É possível manter logs ou asserções em Shipping pelas regras do *target* (`bUseLoggingInShipping`, `bUseChecksInShipping`), mas essas opções mudam definições globais de compilação. ⚠️ Numa engine instalada pelo *launcher*, isso costuma exigir um ambiente de build próprio que a engine instalada não suporta; com a engine compilada do código-fonte, funciona. A Vigília fica com o padrão.

Uma consequência que o projeto inteiro precisa absorver: **num build Shipping, a versão não aparece em log nenhum.** Ela aparece onde a jogadora vê: num canto do menu principal (Capítulo 55) e no `BuildVersion` de cada save (Capítulo 56). Um relato de bug sem a versão é um relato que você não consegue reproduzir.

### Bugs que só existem em Shipping

| Sintoma | Causa provável |
|---|---|
| "Nada acontece" ao interagir com X | Asset não cozido; carregamento por caminho em texto |
| Comportamento diferente de Development | Código com efeito dentro de `check`; variável não inicializada que o otimizador expôs |
| Opção de acessibilidade sem efeito | Ela só existia como CVar no console |
| Save que não aparece no "continuar" | Caminho de save procurado na pasta do projeto, e não na do usuário |
| *Crash* sem log | Shipping não loga: o *minidump* e os símbolos são a única pista (Cap. 61) |

A primeira defesa é empacotar **cedo e com frequência**, como o Capítulo 7 pediu; a segunda é uma lista de verificação de máquina limpa, na seção Projeto.

---

## 62.5 PSO: a primeira vez, de novo

A H3 do Capítulo 59 (o *hitch* de compilação de PSO na primeira aparição da Presença) é um problema de build: depende da plataforma, do RHI e de como os *shaders* foram preparados. As ferramentas da engine para ele mudaram ao longo das versões 5.x, e a descrição abaixo é deliberadamente geral (⚠️ leia a página de PSO da sua versão antes de configurar):

- **Pré-compilação em execução (*PSO precaching*)**: em versões recentes, a engine tenta compilar os PSOs de que um objeto vai precisar quando ele é **carregado**, antes de ser desenhado.
- **Cache empacotado (*bundled PSO cache*)**: você grava, jogando um build, os PSOs que o jogo usou, e inclui esse registro no próximo build, que os compila na inicialização ou numa tela de carregamento.

**Decisão para a Vigília:** medir a passagem fria **no build Test**, com o mecanismo padrão da versão. Se o *hitch* da Presença continuar acima de 33 ms (o limite do Capítulo 58), gravar o cache empacotado com uma passagem completa pelo setor 1. Em qualquer caso, o carregamento do nível acontece atrás de um fade, e é ali que compilações devem acontecer.

---

## Estudos de caso

### GTA: San Andreas e o conteúdo que "não estava lá"

**[FATO PÚBLICO]** Em 2005, uma modificação feita por jogadores para *GTA: San Andreas* (2004), conhecida como *Hot Coffee*, desbloqueou um minijogo de conteúdo sexual que existia nos arquivos do jogo, mas estava inacessível pelo jogo normal. O caso levou a ESRB, a entidade de classificação indicativa dos Estados Unidos, a reclassificar o jogo como "Adults Only", e a Rockstar lançou uma versão sem o conteúdo. O episódio foi amplamente noticiado e teve repercussões legais e comerciais.

**[INFERÊNCIA]** O conteúdo estava desativado, mas **presente no build**. Para quem distribui o jogo, para quem o classifica e para quem o extrai, "presente nos arquivos" é o que conta, e não "alcançável pelo menu".

**Lição para a Vigília:** tudo o que o *cook* inclui é distribuído. É por isso que o Capítulo 76 decidiu que mapas de estudo ficam **fora** do build de lançamento pelas regras de *cook*, e que o `/Game/Developers` nunca é cozido. Uma lista explícita de mapas é mais segura que uma lista de exclusões: o que ninguém pôs na lista não vai.

### Battlefield 4: o build de lançamento é o produto

**[FATO PÚBLICO]** *Battlefield 4* (DICE, 2013) foi lançado com problemas de estabilidade e de rede amplamente relatados pelos jogadores e pela imprensa, e foi noticiado que o estúdio priorizou as correções do jogo antes de avançar em outros projetos.

**[INFERÊNCIA]** Não sabemos as causas internas, e elas certamente vão além de empacotamento. Mas o padrão é conhecido em qualquer engenharia: o que a jogadora recebe é o **build de lançamento**, numa máquina que não é a do estúdio, e qualquer diferença entre o que foi testado e o que foi entregue é paga depois, com juros.

**Lição para a Vigília:** teste o build Shipping como produto, numa máquina limpa, e não o editor. O Milestone 10 do Capítulo 76 diz exatamente isso no critério de conclusão.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Configurações de build | *Debug*/*Release* | Shipping remove ferramentas inteiras, não só otimiza |
| *Cook* | Empacotador com *tree shaking* | Não vê caminhos montados em texto; não reclama, só omite |
| Pak/IoStore | Imagem de contêiner, artefato de *build* | O formato é otimizado para carregamento em disco do jogador |
| Lista de mapas | Pontos de entrada do *bundle* | Lista vazia significa **todos** os mapas |
| Símbolos arquivados | *Source maps* guardados por versão | Sem eles, o *crash* da jogadora é ilegível |
| Teste em máquina limpa | Teste num contêiner novo | A "imagem" é o PC de alguém, com outro driver e outra GPU |

---

## Unreal Engine: o que existe

- ***Project Settings → Packaging***: configuração de build, diretório de *staging*, *Full Rebuild*, *For Distribution*, *Include Debug Files*, *Use Pak File*, *Use Io Store*, *Generate Chunks*, pré-requisitos, *Crash Reporter*, lista de mapas, diretórios sempre e nunca cozidos.
- **Asset Manager** (*Project Settings → Asset Manager*): tipos de *primary asset*, diretórios, regras de *cook*, *chunks*.
- ***Platforms → Package Project*** no editor: o caminho manual.
- **Project Launcher**: perfis de *build*, *cook* e implantação, salvos e reutilizáveis.
- **Unreal Automation Tool (UAT)** e o comando `BuildCookRun`: o mesmo processo, pela linha de comando, para *scripts* e integração contínua.
- **`.Target.cs`**: o alvo e as definições globais de compilação.
- ***Project Settings → Crypto***: criptografia e assinatura de contêineres.
- ***Project Settings → Description***: `ProjectVersion`.

O que **não** existe: a sua lista de verificação de máquina limpa, a política de versão e o arquivo de símbolos. São processo, e a seção de implementação os escreve.

---

## Abordagens

| Critério | A. *Package Project* pelo menu | B. Project Launcher | **C. *Script* com `BuildCookRun` no repositório** |
|---|---|---|---|
| **Complexidade** | Nenhuma | Baixa | Baixa: um arquivo |
| **Reprodutibilidade** | Depende de lembrar as opções | Perfis salvos na máquina | O comando **é** o registro |
| **Testes antes** | Manual | Manual | No *script* |
| **Símbolos e versão** | Manual | Manual | No *script* |
| **Integração contínua** | Não | Parcial | Sim |
| **Adequação à Vigília** | Para o primeiro build, para aprender | Opcional | **Sim** |

**Decisão: C**, depois de fazer o primeiro build com A para ver cada opção na tela. O *script* fica em `Tools/`, versionado com o projeto.

---

## Implementação

### 1. O alvo do jogo

```csharp
// Source/Vigilia.Target.cs
using UnrealBuildTool;

public class VigiliaTarget : TargetRules
{
    public VigiliaTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.Latest;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("Vigilia");

        // Simplificação: Shipping padrão (sem logs, sem checks, sem console).
        // bUseLoggingInShipping/bUseChecksInShipping mudam definições globais e, numa engine
        // instalada pelo launcher, costumam não compilar. ⚠️ Confira na sua versão.
    }
}
```

O alvo do editor (`VigiliaEditor.Target.cs`) não muda.

### 2. As regras de *cook*

Configure pelo editor (*Project Settings*) e versione o resultado. O que importa no `Config/DefaultGame.ini`:

```ini
[/Script/EngineSettings.GeneralProjectSettings]
ProjectVersion=0.8.0

[/Script/EngineSettings.GameMapsSettings]
GameDefaultMap=/Game/Vigilia/Maps/L_MenuPrincipal.L_MenuPrincipal

[/Script/UnrealEd.ProjectPackagingSettings]
BuildConfiguration=PPBC_Shipping
UsePakFile=True
bUseIoStore=True
IncludePrerequisites=True
IncludeDebugFiles=False
; Lista EXPLÍCITA: o que não está aqui não vai (lista vazia = todos os mapas).
+MapsToCook=(FilePath="/Game/Vigilia/Maps/L_MenuPrincipal")
+MapsToCook=(FilePath="/Game/Vigilia/Maps/L_Patio")
+MapsToCook=(FilePath="/Game/Vigilia/Maps/L_CasaDeForca")
; Referenciado só por configuração (Cap. 46): precisa de garantia.
+DirectoriesToAlwaysCook=(Path="/Game/Vigilia/Data")
; Experimentos nunca vão para a jogadora (Cap. 7, Cap. 76, Interlúdio II).
+DirectoriesToNeverCook=(Path="/Game/Developers")

[/Script/Engine.AssetManagerSettings]
+PrimaryAssetTypesToScan=(PrimaryAssetType="VGDocument",AssetBaseClass="/Script/Vigilia.VGDocumentData",bHasBlueprintClasses=False,bIsEditorOnly=False,Directories=((Path="/Game/Vigilia/Narrative/Documents")),Rules=(CookRule=AlwaysCook))
```

(⚠️ Os nomes das chaves e a sintaxe das estruturas seguem o que o editor escreve nas versões 5.x que conheço; a forma mais segura é configurar pela interface e conferir o arquivo.)

Os mapas `L_Subestacao`, `L_Turbinas` e `L_Final` entram na lista quando existirem. O mapa do Galpão, a Arena da Parte IX e o laboratório do Interlúdio II **não** entram: ficam fora por omissão, como o Capítulo 76 decidiu. Quests e conversas seguem o mesmo padrão do documento, com o tipo de *primary asset* que cada classe declara.

### 3. Um teste para as regras de *cook*

As regras acima são exatamente o tipo de configuração que alguém muda sem perceber. Um teste de editor as confere:

```cpp
// Source/Vigilia/Tests/VGBuildContentTest.cpp
#include "Misc/AutomationTest.h"

#if WITH_DEV_AUTOMATION_TESTS && WITH_EDITOR

#include "Engine/AssetManager.h"
#include "Narrative/VGFactRuleSet.h"
#include "Settings/ProjectPackagingSettings.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGBuildContentTest, "Vigilia.Build.Content.CookRules",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGBuildContentTest::RunTest(const FString& Parameters)
{
    const UProjectPackagingSettings* Packaging = GetDefault<UProjectPackagingSettings>();

    // 1. O arquivo de documentos (Cap. 48) depende de o Asset Manager conhecer o tipo.
    TArray<FPrimaryAssetId> Documents;
    UAssetManager::Get().GetPrimaryAssetIdList(FPrimaryAssetType(TEXT("VGDocument")), Documents);
    TestTrue(TEXT("Documentos registrados no Asset Manager"), Documents.Num() > 0);

    // 2. As regras de fatos (Cap. 46) só são alcançadas pela configuração: precisam de diretório sempre cozido.
    const FString RulesPackage = GetDefault<UVGNarrativeSettings>()->FactRules.ToSoftObjectPath().GetLongPackageName();
    const bool bRulesCooked = Packaging->DirectoriesToAlwaysCook.ContainsByPredicate(
        [&RulesPackage](const FDirectoryPath& Dir) { return RulesPackage.StartsWith(Dir.Path); });
    TestTrue(TEXT("DA_FatosDoJogo num diretório sempre cozido"), bRulesCooked);

    // 3. Lista explícita de mapas, sem nada de laboratório.
    TestTrue(TEXT("Lista de mapas não vazia (vazia = todos)"), Packaging->MapsToCook.Num() > 0);
    for (const FFilePath& Map : Packaging->MapsToCook)
    {
        TestFalse(*FString::Printf(TEXT("Mapa de laboratório na lista: %s"), *Map.FilePath),
                  Map.FilePath.Contains(TEXT("/Developers/")));
    }
    return true;
}

#endif
```

`Build.cs`: o teste usa as configurações de empacotamento, que moram no módulo `UnrealEd`, só disponível no editor:

```csharp
// Vigilia.Build.cs (adição)
if (Target.bBuildEditor)
{
    PrivateDependencyModuleNames.Add("UnrealEd");
}
```

### 4. O *script* de build

```bat
@echo off
rem Tools/BuildVigilia.bat  —  uso: BuildVigilia.bat [Shipping|Test|Development]
setlocal
set UE=C:\Program Files\Epic Games\UE_5.x\Engine
set ROOT=%~dp0..
set PROJ=%ROOT%\Vigilia.uproject
set CFG=%1
if "%CFG%"=="" set CFG=Shipping

rem 1. Testes antes de empacotar: um build que não passa nos testes não é candidato.
rem    ⚠️ O código de saída do editor em modo de comando reflete falhas de teste conforme a versão;
rem    se não refletir, leia o relatório em Builds\TestReport.
"%UE%\Binaries\Win64\UnrealEditor-Cmd.exe" "%PROJ%" -ExecCmds="Automation RunTests Vigilia" ^
    -TestExit="Automation Test Queue Empty" -ReportExportPath="%ROOT%\Builds\TestReport" ^
    -unattended -nullrhi -nosplash -log
if errorlevel 1 exit /b 1

rem 2. Compilar, cozinhar, empacotar (pak + IoStore), incluir pré-requisitos, arquivar.
call "%UE%\Build\BatchFiles\RunUAT.bat" BuildCookRun -project="%PROJ%" -platform=Win64 ^
    -clientconfig=%CFG% -build -cook -stage -pak -iostore -prereqs ^
    -archive -archivedirectory="%ROOT%\Builds\%CFG%" -utf8output
if errorlevel 1 exit /b 1

rem 3. Símbolos do MESMO build, guardados fora da pasta distribuída (Cap. 61).
xcopy "%ROOT%\Binaries\Win64\*.pdb" "%ROOT%\Builds\%CFG%-Symbols\" /Y /I >nul
echo Build %CFG% pronto em Builds\%CFG%. Símbolos em Builds\%CFG%-Symbols.
```

Ajuste o caminho da engine (`UE_5.x`) para a sua instalação. Os parâmetros de `BuildCookRun` acima são os usuais (⚠️ confira a lista completa com `RunUAT.bat BuildCookRun -help` na sua versão). A pasta `Builds/` entra no `.gitignore`; o *script*, não.

### Explicação das decisões

- **Lista explícita de mapas.** O que não está na lista não vai. O caso inverso, uma lista de exclusões, falha em silêncio no dia em que alguém cria um mapa de teste com outro nome.
- **Diretório sempre cozido só onde é preciso.** Cozinhar `/Game/Vigilia` inteiro "por segurança" levaria lixo e experimentos para o build. A regra é mínima e coberta por teste.
- **Testes antes do *cook*.** O *cook* é a etapa cara; um build com teste vermelho não deveria custar meia hora.
- **Símbolos fora do pacote, arquivados por build.** A jogadora não precisa deles, e você precisa deles para sempre (Cap. 61).
- **Versão onde a jogadora vê**, porque o Shipping não tem log: menu principal e save.

---

## Projeto Vigília — o primeiro build

### 1. Antes de empacotar: a higiene do Shipping

Percorra o código e o conteúdo com a tabela da seção 62.4 em mãos:

- Todo *draw debug* está dentro de `#if ENABLE_DRAW_DEBUG`; todo *snapshot* do Visual Logger, dentro de `#if ENABLE_VISUAL_LOG`; as categorias do Gameplay Debugger, dentro de `#if WITH_GAMEPLAY_DEBUGGER` (Cap. 61). Compile em Shipping: o que não estiver protegido não compila ou custa.
- Nenhum `check` com efeito colateral. Procure por `check(` seguido de chamadas que mudam estado.
- **`vg.Flicker.Enabled` no menu de opções.** Sem console, a opção de acessibilidade do Capítulo 11 só existe se a UI (Capítulo 55) a expuser e a gravar com as opções do jogador (`UGameUserSettings`). O mesmo vale para o conforto de câmera (`vg.Camera.Motion`, Capítulo 18). Este é o item que **não pode** faltar: é uma questão de saúde, não de conveniência.
- A versão (`0.8.0`) aparece num canto do menu principal.

### 2. O primeiro build, pelo menu

Configure *Project Settings → Packaging* e o Asset Manager como na seção de implementação, rode o teste `Vigilia.Build.Content.CookRules`, e empacote **Development** pelo menu *Platforms → Windows → Package Project*. Leia o log de *cook* procurando avisos de pacotes não encontrados e referências quebradas. Corrija até o log ficar limpo.

### 3. Os builds pelo *script*

`Tools\BuildVigilia.bat Test` e depois `Tools\BuildVigilia.bat Shipping`. O primeiro é para medir; o segundo é o produto.

### 4. A máquina limpa

Numa máquina sem a Unreal instalada (outro computador, ou uma máquina virtual com GPU funcionando), copie a pasta `Builds\Shipping` e confira:

| # | Verificação | Esperado |
|---|---|---|
| 1 | Instalar os pré-requisitos e abrir o jogo | Abre no menu principal, com a versão no canto |
| 2 | Opções: desligar o *flicker* | Nenhuma luz pisca no setor 1 |
| 3 | Novo jogo; atravessar `CP_S1_Corredor` | O ícone de "salvando" aparece (Cap. 55) |
| 4 | Fechar e abrir; "Continuar" | Volta ao corredor, com fatos, jogadora e mundo certos (Caps. 56–57) |
| 5 | Conferir a pasta de saves | O `.sav` está na pasta do usuário, não na do jogo |
| 6 | Apertar `~` | Nada acontece: não há console |
| 7 | Abrir o arquivo de documentos (Cap. 48) depois de ler o livro | O livro está lá (o tipo `VGDocument` foi cozido) |
| 8 | Jogar o setor 1 inteiro | Sem *crash*, sem objeto "que não faz nada" |

Cada falha vira uma linha no `DEVLOG.md`, com a causa da tabela "bugs que só existem em Shipping".

### 5. Os números finais

No build **Test** (Shipping não tem `VGPerfCapture`), refaça a captura do Capítulo 59 na caçada, fria e quente. Compare com as de Development: a diferença é o custo das ferramentas. Se o *hitch* frio da Presença (H3) ainda passar de 33 ms, grave o cache de PSO (seção 62.5) e meça de novo.

### 6. O registro

Guarde a pasta de símbolos, crie uma *tag* no repositório (`v0.8.0`) e escreva no `DEVLOG.md`: tamanho do build, tempo de *cook*, resultado da máquina limpa e números do Test. É a primeira linha de uma série que vai continuar até o Capítulo 84.

---

## Decisões arquiteturais

1. **Configurações com papéis fixos**: Development para o dia a dia, Test para medir, Shipping para a jogadora, DebugGame para depurar o próprio código.
2. **Lista explícita de mapas** e `/Game/Developers` nunca cozido; conteúdo de estudo fica fora por omissão.
3. **Garantias explícitas para o que só é alcançado por configuração** (`/Game/Vigilia/Data`) e para o que é listado pelo Asset Manager (`VGDocument` com "sempre cozinhar"), cobertas por teste.
4. **Shipping padrão** (sem logs, *checks*, console e cheats); a versão aparece no menu e no save.
5. **Build por *script* versionado**: testes antes, `BuildCookRun` com pak e IoStore, pré-requisitos, símbolos arquivados fora do pacote.
6. **Máquina limpa como critério de pronto**, com uma lista de verificação.
7. **Opções de acessibilidade são opções de jogo**, nunca só CVars.

---

## Armadilhas

- **Empacotar pela primeira vez no fim do projeto.** Cada problema desta lista aparece de uma vez, na semana errada.
- **Lista de mapas vazia.** Todo mapa do projeto vai para o build, inclusive os de teste.
- **Carregar assets por caminho montado em texto.** O *cook* não os vê.
- **Confiar que referências de configuração serão cozidas.** Garanta com diretório ou *primary asset*, e teste.
- **Opção de acessibilidade só no console.** No Shipping, ela some, e a jogadora com fotossensibilidade não tem como desligar o *flicker*.
- **Código com efeito dentro de `check`.** Some no Shipping.
- **Perder os símbolos do build distribuído.** O *crash* da jogadora fica ilegível para sempre.
- **Medir em Development e chamar de final.** O número de produto vem de Test.
- **Testar só na máquina de desenvolvimento.** Ela tem as bibliotecas, os drivers e os *caches* que a máquina da jogadora não tem.

---

## Exercício

**Parte 1 — configuração (1 h).** Configure *Packaging* e o Asset Manager pelo editor, confira o `DefaultGame.ini`, implemente o teste `Vigilia.Build.Content.CookRules` e faça-o falhar de propósito (esvazie a lista de mapas) antes de deixá-lo verde.

**Parte 2 — o primeiro build (1,5 h).** Empacote Development pelo menu. Leia o log de *cook* inteiro uma vez. Liste no `DEVLOG.md` cada aviso e o que você fez com ele.

**Parte 3 — o *script* (1 h).** Escreva o `Tools\BuildVigilia.bat`, gere Test e Shipping e compare: tamanho, tempo, o que existe em um e não no outro (console, `stat`, cheats).

**Parte 4 — a máquina limpa (1,5 h).** Faça a lista de verificação completa. Para cada falha, a causa e a correção.

---

## Desafio — o build que se verifica sozinho

A lista da máquina limpa é manual. Automatize metade dela:

1. Um teste de automação que abre `L_CasaDeForca` **no build Test empacotado** (não no editor) e confere que os atores com `UVGPersistenceComponent` têm GUIDs únicos, que os `AVGCheckpoint` têm `PlayerStartTag` preenchido e que o `UVGNarrativeSettings` resolve o `DA_FatosDoJogo` (⚠️ rodar testes num build empacotado depende da configuração Test e de opções de linha de comando; confira na sua versão).
2. Um passo no *script* que roda esse teste depois do `BuildCookRun` e falha o build se ele falhar.
3. Responda no `DEVLOG.md`: quais itens da lista manual nenhuma automação substitui, e por quê?

---

## Uso de IA

1. **Para auditar as regras de *cook*:**
   > "Num projeto Unreal Engine 5, estes são os meus assets carregados por caminho, por referência *soft*, por configuração (`UDeveloperSettings`) e pelo Asset Manager: [lista]. Esta é a minha configuração de empacotamento: [ini]. Quais desses assets correm o risco de não ir para o build cozido? Para cada um, diga a proteção mais simples."

2. **Para revisar a higiene do Shipping:**
   > "Revise este código C++ da Unreal para um build Shipping: procure código de depuração fora de `ENABLE_DRAW_DEBUG`/`ENABLE_VISUAL_LOG`/`WITH_GAMEPLAY_DEBUGGER`, efeitos colaterais dentro de `check`, dependências de `WITH_EDITOR` em código de jogo, e opções que só existem como CVar. [código]"

3. **Para montar o *script*:**
   > "Escreva um script de build para Windows que roda os testes de automação de um projeto Unreal Engine [versão] pela linha de comando, depois chama `RunUAT BuildCookRun` para Win64 em Shipping com pak, IoStore e pré-requisitos, arquiva o build e copia os símbolos para outra pasta. Marque cada parâmetro de que você não tem certeza nessa versão."

**Cuidado específico:** parâmetros de `BuildCookRun`, chaves de `.ini` e nomes de opções de empacotamento mudam entre versões, e a IA mistura versões com facilidade, inclusive com opções da Unreal 4 que não existem mais. Peça que ela marque o que não sabe, confira com `-help` e com a interface do editor, e rode o *script* numa cópia do projeto antes de confiar nele.

---

## Checklist

- [ ] Sei o que cada configuração de build remove e para que uso cada uma.
- [ ] Sei o que o *cook* inclui, o que exclui e por que algo "funciona no PIE e some no build".
- [ ] Minha lista de mapas é explícita, `/Game/Developers` nunca é cozido, e um teste confere as regras.
- [ ] Sei o formato do build (pak, IoStore, a pasta) e o que os pré-requisitos resolvem.
- [ ] Minhas ferramentas de depuração somem em Shipping, e a acessibilidade está no menu.
- [ ] Tenho um *script* de build com testes antes e símbolos arquivados.
- [ ] Meu build Shipping passou na lista da máquina limpa.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Packaging Your Project**, **Build Configurations Reference**, **Cooking Content**, **Asset Management** (*primary assets*, regras de *cook*, *chunks*), **Zen Loader** (que trata do IoStore), **Build Operations** (o `BuildCookRun` da Unreal Automation Tool), e as páginas de **PSO caching** e **PSO precaching** da sua versão.
- ***Game Engine Architecture***, de Jason Gregory: o capítulo sobre o *pipeline* de assets e o sistema de recursos explica, fora da Unreal, o que o *cook* faz e por quê.
- **GDC Vault** (gdcvault.com): palestras sobre *pipelines* de build, integração contínua e lançamento de jogos (procure por "build pipeline" e "shipping"; confira os títulos lá).

---

## Estado do Livro (fim da Parte VIII)

- **Capítulos concluídos:** Introdução; Caps. 1–62 (Partes I–VIII); Interlúdio I.
- **Projetos:** 1 (Pátio), 2 (Galpão), 3 (Interação), 4 (Turno da Noite, ingênuo), 5 (IA) e 6 (sistema narrativo) concluídos; a Vigília ganhou, na Parte VIII, checkpoints versionados, persistência de mundo, orçamento de frame, ferramentas de profiling e de depuração, e o primeiro build Shipping (`v0.8.0`). **As doze dores do Interlúdio I estão resolvidas.**
- **Conceitos consolidados na Parte VIII:**
  - save como descrição, checkpoints em momentos seguros, versionamento e migração;
  - mundo como conteúdo mais diferença, identidade estável, restaurar sem reencenar, persistência através de *streaming*;
  - tempo de frame, estágios, CPU-bound × GPU-bound, orçamento por sistema e por cenário;
  - método de profiling, `stat`, Unreal Insights, *hitches*;
  - ordem do ataque, *culling*, LOD/HLOD, tick por relevância, Significance Manager, URO;
  - camadas de depuração, Visual Logger, Gameplay Debugger, cheats como ferramentas, asserções;
  - configurações de build, *cook*, pak/IoStore, o que o Shipping remove, máquina limpa.
- **Ponto de continuação:** Interlúdio II — Decompondo um mundo aberto.

---

➡️ **Próximo:** [Interlúdio II — Decompondo um mundo aberto](../interludio-2/decompondo-mundo-aberto.md)
