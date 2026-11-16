# Capítulo 77 — Arquitetura

## Objetivo

Ao final deste capítulo você deve conseguir:

- desenhar a **arquitetura do jogo inteiro** numa figura: camadas, subsistemas, atores e dados;
- escrever **regras de dependência** entre partes do código e **verificá-las automaticamente**;
- montar a **tabela de donos de estado** do jogo, com o que é salvo e o relógio de cada um;
- revisar as decisões dos projetos anteriores: o que se manteve, o que mudou e por quê;
- registrar decisões como **ADRs** (*Architecture Decision Records*) e manter um índice;
- fechar as decisões técnicas que a produção ainda deixava abertas, em especial a do Salão das Turbinas.

---

## Contexto

A Vigília foi construída por acréscimo, como quase todo jogo. Cada capítulo resolveu um problema, e cada solução trouxe uma classe, um subsistema ou uma regra. Ao longo de 75 capítulos isso deu, contando por alto:

- mais de 15 subsistemas;
- dezenas de componentes e atores;
- uma família de Data Assets;
- duas dúzias de testes;
- um barramento, um catálogo de fatos e uma pilha de modos de input.

O Capítulo 6 propôs a arquitetura **antes** de existir código. Este capítulo olha a arquitetura **depois**, com três perguntas:

1. **O que existe, e como se conecta?** Uma figura que caiba numa parede.
2. **As regras do Capítulo 6 sobreviveram?** E onde foram violadas, por pressa ou por boa razão.
3. **O que ainda precisa ser decidido** antes de produzir os setores 2 e 3?

A pergunta 2 é a mais delicada. Uma arquitetura que ninguém verifica erode em silêncio: cada inclusão "só desta vez" é razoável sozinha, e a soma delas é um projeto em que tudo depende de tudo. Este capítulo transforma as regras em um **teste**.

---

## 77.1 O jogo inteiro numa figura

```text
 ┌─────────────────────────────────────────── UGameInstance (sessão) ──────────────────────────────────────────┐
 │  UVGNarrativeSubsystem (46) ── fatos, contadores, memória de diálogo, registros de quest, snapshot           │
 │  UVGSaveSubsystem (56–57) ──── checkpoints, slot, registros de mundo (FGuid), migração                      │
 │  UVGGameUserSettings (55) ──── opções e acessibilidade (.ini, fora do save)                                 │
 └─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 ┌─────────────────────────────────────────── UWorld (um nível = um setor) ─────────────────────────────────────┐
 │  BARRAMENTO  UVGGameplayEventSubsystem (24) ── Event.* (tags)                                                │
 │     ▲ publicam: pickups, portas, setores, gatilhos, puzzles, armas/vida, documentos, quests, cenas           │
 │     ▼ ouvem:   UVGFactRulesSubsystem (46) → fatos     UVGObjectiveSubsystem (31) → objetivos                 │
 │                UVGQuestSubsystem (45) (via objetivos)  cenas (49)   telemetria (78)   IA (barks, 42)         │
 │                                                                                                              │
 │  NARRATIVA   UVGDialogueSubsystem (44: canal de rádio)   UVGDocumentReaderSubsystem (48: leitura)           │
 │              UVGQuestSubsystem (45: etapas, fila de trabalho)   UVGCinematicSubsystem (49: cena atual)       │
 │  IA          UVGDirectorSubsystem (42)  UVGThreatSubsystem (36)  UVGTokenSubsystem (42)                      │
 │  APRESENTAÇÃO UVGAudioMixSubsystem (52)   UVGTimeDilationSubsystem (6)   Significance (60)                   │
 └─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 ATORES E COMPONENTES
   Jogadora: AVGCharacter (17) + CMC/perfil (25) + UVGFlashlightComponent (51) + UVGBatteryComponent (4)
             + UVGInteractionComponent (19) + UVGWeaponComponent (26) + UVGRecoilComponent (29)
             + UVGHealthComponent (22) + UVGStatusTagsComponent (23) + UVGFootstepComponent (17)
   Controle: AVGPlayerController (16: pilha de modos; HUD 55) + AVGPlayerCameraManager (18)
   IA:       AVGAIController (33) + BT/BB/EQS (37–39) + UVGAwarenessComponent (36) + Utility (40)
             Presença: AVGEnemyCharacter + UVGPresenceReactionComponent (37)   Vigias: + armas (30)
   Mundo:    AVGDoor, AVGBreakerSwitch, AVGSector, AVGSequencePuzzle (19, 24, 50) · AVGLightFixture (51)
             AVGSafeZone (23) · AVGEventTrigger (15, 45) · AVGReadable (48) · AVGCheckpoint (56)
             AVGCinematicActor (49) · UVGFactGateComponent (47) · UVGPersistenceComponent (57)
 DADOS (Data Assets, String Tables)
   quests, objetivos, conversas, falantes, documentos, regras de fatos, perfis (movimento, Diretor, armas)
 LABORATÓRIO (fora do jogo)
   Galpão, Arena (IX), Quarteirão Vivo (Interlúdio II), protótipo GenAI (X, atrás de VG_WITH_GENAI)
```

Três propriedades da figura merecem atenção, porque são as escolhas que deixaram o resto possível.

- **Dois andares de vida útil.** O que pertence à **história** (fatos, save, opções) vive no `UGameInstance`, e o que pertence a **um lugar** vive no `UWorld`. Os sistemas de mundo se reconstroem a partir dos de sessão a cada nível. É a decisão que tornou a troca de nível e o load corriqueiros (Caps. 46, 56).
- **Um barramento no meio.** Quase nenhum sistema conhece quem publica os eventos que ele ouve. Os puzzles não sabem que existe narrativa, e os documentos não sabem que existem quests. É por isso que o Interlúdio I pôde ser refatorado sem tocar nos sistemas das Partes II–IV.
- **Fatos como língua franca.** Diálogo, quests, gatilhos, luzes, atores condicionados e o epílogo leem a mesma coisa: tags sob `Narrative.Fact.*`. Nenhum desses sistemas conhece os outros; todos conhecem o catálogo.

---

## 77.2 Regras de dependência

O Capítulo 6 enunciou camadas (engine → framework → sistemas → conteúdo). Em código, isso vira uma pergunta concreta: **quem pode incluir quem?** As pastas de `Source/Vigilia` são as unidades.

| Pasta | Pode incluir | Não pode incluir | Por quê |
|---|---|---|---|
| `Core` | `Core` | todo o resto | É a base: barramento, tags, log, utilitários, *stats*. Se a base conhece o topo, não é base |
| `Player`, `Interaction`, `Combat`, `World`, `AI`, `Narrative` (**gameplay**) | `Core` e umas às outras | `Save` (exceção: o GameMode, em `World`), `Debug`, `GenAI`, `Tests`; `UI` (exceção: `Player`) | O jogo é integrado: uma cena empilha um modo de input e trava o Diretor. Mas gameplay não sabe que é salvo, depurado ou desenhado |
| `Player` → `UI` | sim, só o controller | — | O controller é dono da HUD (Cap. 55): ele cria o layout e o alimenta |
| `UI` | `Core`, gameplay, `Save` | `Debug`, `GenAI` | A interface lê o jogo e pede coisas ao dono (Continuar, Novo jogo) |
| `Save` | `Core`, gameplay | `UI`, `Debug`, `GenAI` | O save captura e restaura o gameplay; não desenha nada |
| `GenAI` | `Core`, `Narrative` | todo o resto | O protótipo fica isolado (ADR-0010): **ninguém** depende dele |
| `Debug`, `Tests` | tudo | — | Ferramentas olham para tudo, e ninguém olha para elas |

Duas regras escondidas na tabela fazem a maior parte do trabalho:

1. **Ninguém depende de `GenAI` nem de `Debug`.** Por isso dá para tirá-los do build de release com uma definição ou uma regra de *cook*, sem que nada quebre.
2. **Gameplay não depende de `Save`.** Por isso a persistência pôde ser escrita **depois** dos sistemas (Caps. 56–57): os atores expõem estado com `UPROPERTY(SaveGame)` e um componente, e o save vai buscá-lo. Quem é restaurado puxa o estado quando está pronto.

> 🌉 **Ponte:** é a verificação de arquitetura por teste, como o ArchUnit no Java: regras de dependência entre pacotes, executadas a cada build.
>
> 🧱 **Onde a ponte cai:** num jogo, as "camadas" de gameplay são deliberadamente **permeáveis entre si**. Uma cena precisa travar o Diretor, e uma luz precisa ler fatos. Forçar uma pirâmide estrita entre `Narrative`, `AI` e `World` produziria interfaces artificiais para cada uma dessas ligações ("um ERP para uma porta", na expressão da spec). As regras protegem as **bordas** (base, persistência, ferramentas, protótipo), não o miolo.

### O verificador

Um script de cinquenta linhas faz a verificação. Ele é uma ferramenta de projeto, fora do jogo, e roda antes dos testes no `Tools/BuildVigilia.bat` (Cap. 62).

```python
#!/usr/bin/env python3
"""Regras de dependência entre pastas do módulo Vigilia (Cap. 77).
Uso: python Tools/check_layers.py Source/Vigilia   → código de saída 1 se houver violação."""
import re
import sys
from pathlib import Path

GAMEPLAY = {"Player", "Interaction", "Combat", "World", "AI", "Narrative"}
ALLOWED = {
    "Core": {"Core"},
    **{layer: {"Core"} | GAMEPLAY for layer in GAMEPLAY},
    "UI": {"Core", "UI", "Save"} | GAMEPLAY,
    "Save": {"Core", "Save"} | GAMEPLAY,
    "GenAI": {"Core", "Narrative", "GenAI"},
    "Debug": None,  # None = pode tudo
    "Tests": None,
}
EXCEPTIONS = {
    ("Player", "UI"),   # o controller é dono da HUD (Cap. 55)
    ("World", "Save"),  # o GameMode aplica o load pendente no InitGame: a ordem importa (Cap. 57)
}
INCLUDE = re.compile(r'^\s*#include\s+"(\w+)/')


def violations(root: Path):
    found = []
    for path in sorted(root.rglob("*")):
        if path.suffix not in (".h", ".cpp"):
            continue
        layer = path.relative_to(root).parts[0]
        allowed = ALLOWED.get(layer, None)
        if layer not in ALLOWED or allowed is None:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            match = INCLUDE.match(line)
            if not match:
                continue
            target = match.group(1)
            if target in ALLOWED and target not in allowed and (layer, target) not in EXCEPTIONS:
                found.append(f"{path.relative_to(root)}:{number}: {layer} -> {target}")
    return found


def _self_test():
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "Core").mkdir()
        (root / "Narrative").mkdir()
        (root / "Core" / "Bad.cpp").write_text('#include "Narrative/VGQuestData.h"\n')
        (root / "Narrative" / "Ok.cpp").write_text('#include "Core/VGLog.h"\n#include "AI/VGDirectorSubsystem.h"\n')
        result = violations(root)
        assert result == ["Core/Bad.cpp:1: Core -> Narrative"] or result == ["Core\\Bad.cpp:1: Core -> Narrative"], result


if __name__ == "__main__":
    _self_test()
    problems = violations(Path(sys.argv[1] if len(sys.argv) > 1 else "Source/Vigilia"))
    print("\n".join(problems) or "Camadas OK.")
    sys.exit(1 if problems else 0)
```

O script tem um auto-teste mínimo (`_self_test`): uma pasta temporária com uma violação plantada e uma inclusão permitida. Ele roda toda vez, antes da verificação real. Um verificador que nunca falha não verifica nada.

### O que a primeira execução encontra

Se o seu código seguiu os capítulos, a primeira execução deve apontar duas violações **reais**, que nasceram de decisões razoáveis em contexto:

| Violação | Origem | Correção 🔁 |
|---|---|---|
| `Core → Save` | `AVGGameMode` mora em `Core` (Cap. 7) e, no Cap. 56, passou a chamar `ApplyPendingLoad` | O GameMode não é base, é o **orquestrador do nível**: muda para `World/`. Nada que esteja em `Core` o inclui. A chamada ao save continua, porque o momento do `InitGame` importa (Cap. 57), e vira a segunda exceção declarada: `("World", "Save")` |
| `Core → Player` | `UVGAudioMixSubsystem` (Cap. 52) mora em `Core` e lê o modo de input do controller | O mix é **apresentação derivada de gameplay**: muda para `World/`, ao lado das luminárias que também leem o jogo |

As duas correções são **mudanças de pasta**, não de código. É o sintoma típico de uma arquitetura saudável que erodiu um pouco: o código estava certo, o endereço é que estava errado. Sem o verificador, essas duas inclusões teriam sido o precedente para a terceira, a décima e a vigésima.

---

## 77.3 Os fluxos

Quatro fluxos atravessam o jogo inteiro. Desenhá-los é a melhor revisão de arquitetura que existe: um fluxo que precisa de muitas setas para ser explicado é um fluxo que vai quebrar.

### Mundo → história

```text
 ator do mundo ──Publish──► barramento ──► UVGFactRulesSubsystem ──AddFact──► UVGNarrativeSubsystem
 (ex.: setor energizado)              └──► UVGObjectiveSubsystem ──► UVGQuestSubsystem (fila; tick seguinte)
                                                                        │
          OnFactChanged ◄───────────────────────────────────────────────┤
              ├──► UVGQuestSubsystem: CheckStage (enfileirado)           │
              ├──► UVGFactGateComponent: aparece/some (quando não visto) ▼
              ├──► AVGLightFixture: acende pelos fatos                 ações: conversa, fato, sinal, quest
              └──► (leitores por consulta: diálogo, gatilhos, documentos, epílogo)
```

### Checkpoint e load

```text
 jogadora entra no volume ──► UVGSaveSubsystem::RequestCheckpoint ──► trava de momento (viva, sem caçada,
                                                                    sem pico, sem cena) ──► espera a calma
     ──► WriteCheckpoint: narrativa (snapshot) + jogadora + mundo (registros por FGuid) ──► AsyncSaveGameToSlot
 morte ──► ReloadLastCheckpoint ──► abre o nível ──► InitGame: RestoreSnapshot ──► ChoosePlayerStart: checkpoint
     ──► atores: PostInitializeComponents → RestoreOwner (silencioso) ──► BeginPlay da jogadora: registro
```

### Leitura

```text
 interação ──► AVGReadable ──► UVGDocumentReaderSubsystem::Open ──► PushInputMode(Reading)
     ──► UI (camada Reading) ──► Close ──► "leu?" (regra pura) ──► AddFact(ReadFact) + Event.Document.Read
     enquanto lê: Diretor não sobe a fase; rádio só Critical; mix de leitura (−6 dB, passa-baixa)
```

### Cena

```text
 gatilho/painel ──► AVGCinematicActor::PlayCinematic ──► PushInputMode(Cinematic) + trava do Diretor
     ──► Sequencer (apresentação; eventos só para sincronizar) ──► fim | pular | cancelar
     ──► Finish único: libera na ordem inversa; efeitos de estado só em fim/pular
```

---

## 77.4 Os donos do estado

A regra do dono único (Capítulo 4) foi o fio condutor do livro. Esta é a tabela completa da Vigília:

| Estado | Dono | Salvo? | Relógio | Cap. |
|---|---|---|---|---|
| Fatos, contadores, memória de diálogo, registros de quest | `UVGNarrativeSubsystem` | Sim (snapshot) | — (discreto) | 46 |
| Checkpoint atual, registros de mundo | `UVGSaveSubsystem` | É o próprio save | Real (gravação assíncrona) | 56–57 |
| Opções | `UVGGameUserSettings` | `.ini` | — | 55 |
| Modo de input efetivo | `AVGPlayerController` (pilha) | Não | — | 16 |
| Fala atual, fila do rádio | `UVGDialogueSubsystem` | Não (a memória sim, no dono narrativo) | **Áudio** | 44 |
| Documento aberto | `UVGDocumentReaderSubsystem` | Não | **Real** | 48 |
| Etapa e progresso de quest | `UVGQuestSubsystem` (espelha no dono narrativo) | Etapa sim, progresso parcial não | — | 45–46 |
| Objetivos ativos | `UVGObjectiveSubsystem` | Não (reconstruídos pela etapa) | Jogo | 31 |
| Cena atual | `UVGCinematicSubsystem` / ator | Não (save travado durante cena) | Sequência | 49 |
| Fase e tensão do Diretor | `UVGDirectorSubsystem` | Não | Jogo | 42 |
| Consciência de cada agente | `UVGAwarenessComponent` | Não | Jogo | 36 |
| Bateria, lanterna | `UVGBatteryComponent`, `UVGFlashlightComponent` | Carga sim; lanterna volta `Off` | Jogo | 4, 51 |
| Vida | `UVGHealthComponent` | **Não** (revisto no Cap. 56) | Jogo | 22 |
| Portas, disjuntores, gatilhos, puzzles | Os próprios atores | Sim (`SaveGame` + `FGuid`) | Jogo | 57 |
| Setor energizado | **Derivado** do disjuntor | Não (deriva) | — | 57 |
| Documentos levados | **Derivado** dos fatos | Não (deriva) | — | 57 |
| Dilatação do tempo | `UVGTimeDilationSubsystem` | Não | Real | 6 |

A coluna **"salvo?"** e a coluna **"relógio"** são as duas que mais custaram para acertar ao longo do livro. Elas explicam bugs que, sem a tabela, apareceriam como mistérios: a legenda que desalinha no hitstop (relógio errado), o setor que aparece energizado sem o disjuntor ligado (estado salvo em dois lugares), a vida que volta cheia ao carregar (revisão consciente, não bug).

---

## 77.5 O que a arquitetura aprendeu

A spec pediu, desde o começo, que cada solução substituída fosse explicada: o que havia, o problema, a mudança, o que se aprendeu. Juntas, as revisões contam a história da arquitetura melhor que qualquer diagrama:

| Antes | Depois | Por quê | Cap. |
|---|---|---|---|
| Cola narrativa no Level Blueprint | Dados (diálogo, quests, fatos, documentos, cenas) | As 12 dores do Interlúdio I | 44–49 |
| Fatos no subsistema de diálogo | Dono próprio no `UGameInstance` | Terceiro leitor; troca de nível | 46 |
| HFSM genérica "para dois usos" | Material de estudo, sem cliente | Os usos previstos não chegaram (YAGNI) | 34, 42 |
| Cérebro ingênuo do inimigo em `switch` | BT + Utility + tokens + Diretor | Dívida declarada no Cap. 30 | 33–42 |
| `AimAt` manual | Foco do `AIController` | O controller reescreve a rotação | 30, 37 |
| `bSustoArmado` no nível | Gatilho condicionado a fatos | "Nem tudo é quest" | 45 |
| Widgets provisórios por capítulo | Um layout com cinco camadas derivadas do modo | Widgets não empilham modos | 55 |
| Setor ativa zonas seguras | A luminária é dona da zona que protege | "Só é seguro onde há luz", por construção | 51 |
| `AVGAlarm` filho fazendo a usina respirar | `MS_Usina_Respira` | A ferramenta certa para o trabalho | 52 |
| Vida salva | Vida não salva | Regeneração + trava de momento a tornaram redundante | 56 |
| Persistir tudo | Persistir a diferença; derivar o resto | Uma fonte da verdade por estado | 57 |
| Fala gerada por modelo em runtime | Fora do release; protótipo atrás de uma definição | Pilares e preservação (o jogo completo sem o serviço) | 73–75 |

Duas lições atravessam a tabela.

1. **A maior parte das mudanças foi de dono, não de algoritmo.** Quase nenhuma linha difícil foi reescrita; o que mudou foi **quem é responsável por quê**. É a mesma previsão que o Interlúdio III fez para o multiplayer, e ela vale para o projeto inteiro.
2. **As abstrações que sobreviveram nasceram de dor; as que morreram nasceram de previsão.** O barramento (Cap. 24) resolveu ligações muitos-para-muitos que já existiam, e sobreviveu. A HFSM genérica (Cap. 34) resolveu usos previstos, e morreu.

---

## 77.6 ADRs

Um ADR (*Architecture Decision Record*) é um documento curto que registra **uma** decisão: o contexto, a decisão, as alternativas e as consequências. Para um projeto individual, ele é a memória que impede você de reabrir, em seis meses, uma decisão cujas razões esqueceu.

```text
docs/adr/ADR-0008-save-por-checkpoint.md

# ADR-0008 — Save por checkpoint, um slot, sem vida
Status: aceita (Cap. 56)
Contexto: jogo de terror de 15 minutos; morte frequente; tensão depende de não poder "salvar antes".
Decisão: checkpoints automáticos com trava de momento; um slot; morte recarrega o último; vida não salva.
Alternativas: save livre (quebra a tensão); dois slots com rotação (desafio do Cap. 56, sem demanda).
Consequências: o save é simples e testável; quem quer rejogar um trecho começa um novo jogo;
              checkpoints precisam ser bem colocados (Cap. 50).
```

O índice da Vigília, consolidando as decisões do livro:

| ADR | Decisão | Cap. |
|---|---|---|
| 0001 | C++ define sistemas, regras e tipos; Blueprint, conteúdo e ajuste; Data Assets, números | 13 |
| 0002 | Barramento de eventos por Gameplay Tags para relações muitos-para-muitos | 24 |
| 0003 | Gameplay Tags como linguagem de estado (status) e de história (fatos) | 23, 46 |
| 0004 | Pilha de modos de input; quem empilha é dono do nível | 16 |
| 0005 | IA: BT + Blackboard + EQS + Utility; Diretor controla frequência, nunca regras | 37–42 |
| 0006 | Diálogo, quests, documentos e cenas como dados; nenhum texto em grafo | 44–49 |
| 0007 | Estado narrativo com dono único no `UGameInstance`; snapshot versionada | 46 |
| 0008 | Save por checkpoint, um slot, sem vida | 56 |
| 0009 | Persistência: conteúdo + diferença; `FGuid` estável; atores spawnados não persistem | 57 |
| 0010 | Release sem IA generativa em runtime | 73–75 |
| 0011 | Um nível por setor, sem *World Partition* | 50, 77 |
| 0012 | Multiplayer só como ramo experimental (`exp/coop-s1`) | Int. III, 84 |

> 🌉 **Ponte:** ADRs vêm da engenharia de software corporativa e funcionam aqui sem adaptação. A diferença está no que costuma virar ADR: num jogo, muitas decisões importantes são de **experiência** ("sem marcadores de objetivo no mundo", Cap. 55), e merecem o mesmo registro que as técnicas.
>
> 🧱 **Onde a ponte cai:** num time, ADRs coordenam pessoas. Sozinho, eles coordenam **você** com você mesmo daqui a seis meses. O formato pode ser ainda mais curto, mas o hábito é o mesmo.

---

## 77.7 As decisões que faltavam

### O Salão das Turbinas

O Capítulo 60 deixou critérios para decidir *World Partition*, HLOD e Nanite no maior espaço do jogo, e o Capítulo 50 já tinha firmado "um nível por setor". Aplicando os critérios:

| Critério (Cap. 60) | Salão das Turbinas | Conclusão |
|---|---|---|
| O espaço cabe na memória de uma vez? | Sim: quatro áreas, um único setor | *World Partition* não é necessário |
| Há linhas de visão longas para longe? | Sim: da galeria superior se vê o poço | Malhas grandes e distantes pedem LOD; HLOD só se o profiling mostrar *draw calls* demais |
| As malhas são estáticas, densas e grandes? | Sim: turbinas, estruturas, passarelas | Candidatas a **Nanite**, se a máquina-alvo (Cap. 58) suportar |
| Há áreas que só se veem depois de entrar? | Sim: o poço da turbina 3 | Um subnível com carga por proximidade é opção barata |

**Decisão (ADR-0011, confirmado):** um nível, `L_Turbinas`, sem *World Partition*. Nanite nas malhas estáticas grandes, condicionado à máquina-alvo. O poço como subnível (`L_Turbinas_Poco`), carregado ao entrar nas passarelas, porque a persistência do Capítulo 57 já trata atores que saem do mundo (`RemovedFromWorld`). HLOD só se o Capítulo 83 medir necessidade. A decisão é **provisória até a medição**: ela diz o que fazer primeiro e o que medir para revê-la.

### `Build.cs` final

```csharp
// Source/Vigilia/Vigilia.Build.cs (dependências ao fim do livro)
PublicDependencyModuleNames.AddRange(new[] {
    "Core", "CoreUObject", "Engine", "InputCore",
    "EnhancedInput", "GameplayTags", "PhysicsCore", "Niagara",            // Partes II–IV
    "AIModule", "GameplayTasks", "NavigationSystem",                       // Parte V
    "DeveloperSettings", "LevelSequence", "MovieScene",                   // Parte VI
    "UMG", "Slate", "SlateCore", "AudioExtensions",                       // Parte VII
    "EngineSettings", "RHI", "SignificanceManager",                       // Parte VIII
    "NetCore",                                                            // Parte IX (⚠️ conforme o uso)
    "AssetRegistry"                                                       // Cap. 71
});
if (Target.bUseGameplayDebugger) { PrivateDependencyModuleNames.Add("GameplayDebugger"); }
if (Target.bBuildEditor)         { PrivateDependencyModuleNames.Add("UnrealEd"); }

// Protótipo de IA generativa (ADR-0010): só fora do Shipping. Mudar a constante exige revisar o ADR (Cap. 75).
const bool bAllowGenAIInShipping = false;
bool bWithGenAI = Target.Configuration != UnrealTargetConfiguration.Shipping || bAllowGenAIInShipping;
PublicDefinitions.Add("VG_WITH_GENAI=" + (bWithGenAI ? "1" : "0"));
if (bWithGenAI) { PrivateDependencyModuleNames.AddRange(new[] { "HTTP", "Json", "JsonUtilities" }); }
// ⚠️ Código fora de GenAI/ que use Json (o export do desafio do Cap. 46, por exemplo) precisa da guarda
// #if !UE_BUILD_SHIPPING ou de Json/JsonUtilities fora do if; senão o Shipping não linka (Cap. 84).
```

Cada linha tem um capítulo de origem, e o comentário diz qual. Uma dependência sem origem conhecida é a primeira candidata a sair. ⚠️ A forma de cada módulo (público ou privado) e alguns nomes variam entre versões; ajuste ao que a sua engine compila.

---

## Estudo de caso: a arquitetura dos estúdios

**[INFERÊNCIA]** Estúdios que fazem jogos grandes com equipes grandes tendem a ter motores próprios, ou extensões pesadas de motores comerciais, com camadas de ferramentas, pipelines de conteúdo e times de tecnologia separados dos times de jogo. A arquitetura deles otimiza **escala de produção**: muitas pessoas produzindo conteúdo em paralelo, sem pisar umas nas outras. A literatura pública sobre isso (palestras de GDC e livros como *Game Engine Architecture*, de Jason Gregory) descreve camadas parecidas com as da figura da seção 77.1, mas com muito mais separação, porque o custo de coordenação entre pessoas é maior que o custo de indireção no código.

**Lição para a Vigília:** a arquitetura certa para uma pessoa e quinze minutos de jogo é **menor**. As regras protegem só as bordas, as camadas de gameplay são permeáveis, e não há plugins internos nem serviços. É a comparação "elegante × adequada" que a spec pediu e que o Interlúdio II desenvolveu: adequada é a arquitetura cujo custo de manutenção você consegue pagar sozinho.

---

## Comparação com o desenvolvimento tradicional

| Arquitetura do jogo | O que você conhece | Onde a analogia cai |
|---|---|---|
| Dois andares de vida útil (sessão, mundo) | Escopos de *bean* (aplicação, requisição) | O "mundo" é destruído e reconstruído a cada nível, com o estado puxado da sessão |
| Barramento no meio | *Message broker* interno, eventos de domínio | Síncrono, uma thread, sem garantias de entrega |
| Regras de dependência verificadas | ArchUnit, regras de módulo | O miolo de gameplay é permeável de propósito |
| Tabela de donos de estado | *Bounded contexts* e donos de dados | Relógios diferentes por dono não têm equivalente direto |
| ADRs | ADRs | — (a prática é a mesma) |
| Laboratório fora do jogo | Repositório de *spikes* e protótipos | Os protótipos ficam no mesmo projeto, excluídos pelo *cook* |

---

## Unreal Engine: o que ajuda a manter a arquitetura

- **Módulos e plugins:** a Vigília usa um módulo só. Separar `GenAI` num plugin desligável seria a forma mais forte de isolamento (desafio). Plugins têm o seu próprio `Build.cs` e podem ser excluídos do projeto inteiro.
- **`UPROPERTY(SaveGame)`**, `UGameInstanceSubsystem` e `UWorldSubsystem`: as ferramentas que deram os dois andares de vida útil.
- **Regras de *cook*** (Cap. 62): mapas e diretórios explícitos mantêm o laboratório fora do release.
- **Testes de automação** (`Vigilia.*`) e **verificações externas** (o script de camadas) rodando no `Tools/BuildVigilia.bat`.

---

## Abordagens: como manter as regras

| Critério | A. Disciplina (revisão de código) | **B. Script de verificação no build** | C. Módulos ou plugins separados |
|---|---|---|---|
| **Força** | Fraca: depende de lembrar | Média: falha o build | Forte: o compilador impede |
| **Custo** | Nenhum | Um script | Reestruturação, `Build.cs` por módulo, exportação de símbolos |
| **Flexibilidade** | Total | Exceções explícitas no script | Baixa: cada exceção é uma dependência de módulo |
| **Adequação à Vigília** | Insuficiente: as duas violações da seção 77.2 passaram | **Sim** | Só para o `GenAI` (desafio) |

**Decisão: B**, com C reservado para o protótipo de IA generativa, se ele crescer.

---

## Projeto Final — a arquitetura registrada

- [ ] `docs/arquitetura.md`: a figura da seção 77.1, os quatro fluxos e a tabela de donos.
- [ ] `docs/adr/`: os doze ADRs, cada um com contexto, decisão, alternativas e consequências.
- [ ] `Tools/check_layers.py` no `Tools/BuildVigilia.bat`, antes dos testes, e as duas violações da seção 77.2 corrigidas (🔁 `AVGGameMode` e `UVGAudioMixSubsystem` para `World/`).
- [ ] `L_Turbinas` e `L_Turbinas_Poco` criados conforme o ADR-0011, com a carga do subnível por proximidade.
- [ ] Milestone 1 (Foundation) fechado: o projeto compila sem *warnings*, todos os testes passam e a troca de nível funciona de ponta a ponta.

---

## Decisões arquiteturais

1. **Dois andares de vida útil**: sessão (`UGameInstance`) para a história, o save e as opções; mundo para o lugar.
2. **Regras de dependência só nas bordas** (base, save, UI, ferramentas, protótipo), verificadas por script no build; o miolo de gameplay é permeável.
3. **Tabela de donos de estado** com "salvo?" e "relógio" como referência obrigatória para sistemas novos.
4. **ADRs** para decisões técnicas e de experiência; índice com doze decisões.
5. **Salão das Turbinas**: um nível com o poço como subnível; Nanite condicionado; HLOD só por medição.
6. **`Build.cs` comentado com o capítulo de origem** de cada dependência; IA generativa só fora do Shipping.

---

## Armadilhas

- **Arquitetura que ninguém verifica.** Erode uma inclusão razoável de cada vez.
- **Pirâmide estrita no miolo de gameplay.** Cria interfaces artificiais para ligações legítimas.
- **"Core" como gaveta.** Tudo o que não sabe onde morar vai para a base, e a base passa a depender do topo.
- **ADR escrito depois de esquecer o motivo.** Escreva no dia da decisão, ou pelo menos no dia em que perceber que ela foi tomada.
- **Diagrama que não bate com o código.** A figura da seção 77.1 é revista a cada milestone; um diagrama desatualizado é pior que nenhum.
- **Decidir sem medir** (World Partition, HLOD, Nanite). As decisões de performance estrutural ficam provisórias até o profiling.
- **Dependências sem dono.** Um módulo no `Build.cs` que ninguém sabe por que está lá.

---

## Exercício

**Parte 1 — a figura (1,5 h).** Desenhe a figura da seção 77.1 a partir do **seu** código, não deste capítulo. Use `grep` por `UCLASS`, `: public UWorldSubsystem` e `: public UGameInstanceSubsystem`. Onde a sua figura diverge da do livro?

**Parte 2 — o verificador (1 h).** Coloque `Tools/check_layers.py` no projeto e no script de build. Rode e corrija as violações (mudanças de pasta com 🔁, atualizando os includes). Rode de novo.

**Parte 3 — a tabela de donos (45 min).** Confira cada linha da tabela da seção 77.4 contra o seu código. Para cada sistema que você criou fora do livro (desafios), acrescente uma linha.

**Parte 4 — ADRs (1,5 h).** Escreva os doze ADRs no formato do exemplo. Para cada um, a seção "alternativas" deve ter ao menos uma opção que você realmente considerou.

---

## Desafio — o protótipo como plugin

Mova `Source/Vigilia/GenAI/` para um plugin de projeto (`Plugins/VigiliaGenAI/`), com módulo próprio, que depende de `Vigilia` e de que nada depende.

1. O que precisou ser exportado (`VIGILIA_API`) do módulo do jogo para o plugin compilar?
2. Desligue o plugin no `.uproject`: o jogo compila e roda?
3. Compare com a definição `VG_WITH_GENAI`. Qual isolamento é mais forte, e qual é mais barato de manter?

Registre a resposta como um ADR novo (ADR-0013), aceito ou recusado.

---

## Uso de IA

1. **Para desenhar a figura a partir do código:**
   > "Aqui está a lista de classes do meu projeto Unreal (nome, classe base, pasta) e os includes entre pastas (abaixo). Desenhe um diagrama em ASCII com os subsistemas por vida útil (GameInstance × World), os atores principais e as setas de dependência. Aponte dependências que parecem violar a regra 'Core não depende de ninguém' e 'nada depende de Debug/GenAI'. [lista]"

2. **Para revisar um ADR:**
   > "Revise este ADR de um jogo pequeno (abaixo). O contexto explica por que a decisão foi necessária? As alternativas são reais ou espantalhos? As consequências incluem o custo, não só o benefício? O que faria eu reabrir esta decisão? [ADR]"

3. **Para auditar donos de estado:**
   > "Aqui está a tabela de donos de estado do meu jogo (estado, dono, salvo, relógio) e o código de dois sistemas. Encontre estado com dois donos, estado salvo que também é derivado, e sistemas que usam um relógio diferente do declarado na tabela. [tabela + código]"

**Cuidado específico:** pedida para "melhorar a arquitetura", a IA tende a propor mais camadas, interfaces e injeção de dependência, o vocabulário da arquitetura corporativa em que ela foi treinada. Para um jogo individual, a melhor revisão costuma ser **remover** indireção. Peça explicitamente o que pode ser simplificado.

---

## Checklist

- [ ] Tenho a figura do jogo inteiro, e ela bate com o código.
- [ ] As regras de dependência estão num script que roda no build, com auto-teste.
- [ ] Sei por que o miolo de gameplay é permeável e as bordas não.
- [ ] Tenho a tabela de donos de estado, com "salvo?" e "relógio".
- [ ] Sei contar a história das revisões da arquitetura e as duas lições delas.
- [ ] Os doze ADRs estão escritos, e o Salão das Turbinas tem decisão e critério de revisão.

---

## Para ir além

- **Jason Gregory, *Game Engine Architecture*** — camadas de um motor de jogo e de um *runtime* de gameplay, em escala de estúdio.
- **Robert Nystrom, *Game Programming Patterns*** — em especial *Event Queue*, *Component*, *Service Locator* e *Data Locality*, que reaparecem na figura deste capítulo.
- **Michael Nygard, "Documenting Architecture Decisions"** (2011) — o texto que popularizou o formato de ADR.

---

➡️ **Próximo:** [Capítulo 78 — Vertical Slice](cap-78-vertical-slice.md)
