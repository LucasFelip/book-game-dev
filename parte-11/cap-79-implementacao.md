# Capítulo 79 — Implementação

## Objetivo

Ao final deste capítulo você deve conseguir:

- conduzir a produção do vertical slice ao jogo completo **por setor**, com o jogo **sempre jogável** do começo ao fim;
- tratar o setor como **unidade de conteúdo** com um manifesto: o que ele contém, os tetos do inventário, e um teste que verifica tudo;
- montar os setores 2 e 3 e o final **com os sistemas que já existem**, quase sem código novo;
- implementar a **escolha final** como uma etapa de quest "qualquer um" e duas cenas;
- fechar o **save no jogo inteiro** (Milestone 8), com uma matriz de testes por checkpoint;
- organizar o trabalho diário: build semanal, triagem de bugs, cortes no meio da produção.

---

## Contexto

Depois do vertical slice (Capítulo 78), a Vigília tem dois minutos de prólogo e um setor em qualidade final, mais os setores 2 e 3 em *blockout* (Capítulo 50), com plantas, métricas e frases de intenção. O que falta é **conteúdo**: quests, documentos, conversas, vinhetas, encontros e cenas dos setores 2 e 3, e o final.

Este é o capítulo em que a arquitetura das Partes V–VIII cobra os seus dividendos. Se os sistemas foram bem desenhados, produzir um setor novo deveria ser, quase todo, **trabalho de dados e de nível**:

- uma quest com etapas;
- objetivos que ouvem o barramento;
- conversas com variantes por fato;
- documentos com fatos de leitura;
- luminárias que leem fatos;
- cenas com estado no `Finish`;
- checkpoints;
- um perfil de Diretor.

O teste do capítulo é simples e impiedoso: **quanto código novo o setor 2 exigiu?** A resposta esperada é "muito pouco", e cada exceção é uma lição sobre um sistema que faltou ou que foi desenhado estreito demais.

O Capítulo 76 atribuiu a este capítulo os Milestones 3 (Combat), 6 (Level) e 8 (Save System).

---

## 79.1 O jogo sempre jogável

A regra de produção mais importante deste capítulo:

> **A cada semana, um build de desenvolvimento leva do menu principal aos créditos.**

Trechos ainda em *blockout* são aceitáveis; trechos **quebrados** não. Um setor pela metade pode ter cubos e sons provisórios, mas tem a quest, os objetivos, as conversas (mesmo com texto provisório) e a saída para o próximo nível.

| Sem a regra | Com a regra |
|---|---|
| O setor 2 "fica pronto" isolado, e na semana 11 descobre-se que o save do setor 1 não carrega nele | A integração quebra **na semana em que foi introduzida**, e a causa está fresca |
| O ritmo do jogo inteiro só é sentido no fim, quando já não há tempo de mudar | Cada playtest semanal mostra a curva inteira (Cap. 76) |
| Cortar é traumático: há meio setor polido e meio sem nada | Cortar é ajustar uma lista: o setor já funciona inteiro em qualidade baixa |

> 🌉 **Ponte:** é integração contínua levada ao produto. Não basta o build compilar e os testes passarem: o **produto inteiro** tem de ser utilizável, a cada ciclo.
>
> 🧱 **Onde a ponte cai:** "utilizável" num jogo inclui **ritmo**, uma propriedade do todo que nenhum teste automatizado verifica. O build semanal é jogado de ponta a ponta por uma pessoa, pelo menos às vezes alguém que não é você.

---

## 79.2 O setor como unidade de conteúdo

Um setor é um pacote de conteúdo com fronteiras claras:

- um nível;
- uma quest;
- documentos, conversas e vinhetas;
- checkpoints e encontros;
- e os **tetos** do inventário do Capítulo 76.

Um **manifesto** torna o pacote explícito e verificável. É um Data Asset por setor que lista o que o setor deve ter e quanto ele pode ter.

O manifesto serve a três coisas:

1. **Verificação.** Um teste confere que tudo o que o manifesto lista existe e é válido, que os tetos não foram ultrapassados e que cada conversa passa na auditoria de ramificação (Capítulo 47) com os fatos do setor.
2. **Visão de produção.** O manifesto é a lista de conteúdo do setor, legível por qualquer pessoa, e a contagem contra o teto é o progresso.
3. **Empacotamento.** O Capítulo 84 usa os manifestos para conferir que nada do conteúdo do jogo ficou fora do *cook*.

---

## 79.3 O setor 2: Subestação

A planta do Capítulo 50:

- duas rotas, a de Sônia (galeria de cabos) e a de Moraes (casa de comando), que convergem antes do pátio dos vigias;
- o encontro dos vigias no pátio, com a Presença mantida longe enquanto houver vigias de pé;
- as seccionadoras, um puzzle de quatro alavancas com o mesmo `AVGSequencePuzzle`;
- a saída para o Salão das Turbinas.

Como o setor 2 se monta com o que existe:

| Peça | Sistema | Código novo? |
|---|---|---|
| **A escolha de rota** (estado, Cap. 47) | Dois `AVGEventTrigger` na bifurcação. O da galeria tem `FactOnTrigger = S2.Route.Sonia` e `RequiredFacts = NÃO TEM S2.Route.Moraes`; o da casa de comando, o simétrico. A primeira rota tomada vence, e o fato é monotônico | Não |
| **Sônia reage à rota** | Conversas com variantes por fato | Não |
| **A ordem de serviço de 2026** | `UVGDocumentData` (`Document.S2.WorkOrder`), só na rota de Moraes | Não |
| **O encontro dos vigias** | Vigias da Parte V (BT, Utility, tokens) colocados no pátio | Não |
| **"Vigias derrubados" como fato** | Regra de fatos com contador (Cap. 46) sobre `Event.Actor.Died` | **Sim, pequeno** (abaixo) |
| **A Presença fora do pátio durante o tiroteio** | Uma zona de trava do Diretor (Cap. 80) | Sim, no Cap. 80 |
| **As seccionadoras** | `AVGSequencePuzzle` (Cap. 50) com 4 alavancas, cuja ordem está no documento da rota de Sônia **ou** numa placa da rota de Moraes | Não |
| **A quest** | `DA_Quest_S2_Substation`: Chegar à subestação → (rota) → Pátio (vigias **ou** passagem furtiva, *could*) → Seccionadoras → Saída | Não |

A única exceção de código é instrutiva. Para contar "vigias derrubados" por regra, o evento de morte precisa dizer **quem** morreu, e o `Event.Actor.Died` do Capítulo 27 não tem contexto. A correção é de uma linha, no dono do evento:

```cpp
// 🔁 UVGHealthComponent::ReceiveDamage, ao morrer (Cap. 27): o contexto passa a ser a facção da vítima.
FGameplayTag Faction;
if (const UVGStatusTagsComponent* Tags = GetOwner()->FindComponentByClass<UVGStatusTagsComponent>())
{
    Faction = Tags->GetAllTags().Filter(FGameplayTagContainer(TAG_Faction_Player.GetTag().RequestDirectParent())).First();
}
UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Actor_Died,
    Instigator ? Instigator->GetPawn() : nullptr, GetOwner(), Faction);
```

O filtro pega a primeira tag de identidade sob `Faction` (o pai de `Faction.Player`). O resto é dado, no `DA_FatosDoJogo`:

```text
 Event.Actor.Died  ctx Faction.Guard  →  contador S2.GuardsDown;  em 3 → fato S2.GuardsCleared
```

Repare no que **não** mudou: o objetivo do Galpão "derrube 10 alvos" (Cap. 31) filtrava pela tag do alvo, e continua funcionando, porque contexto novo não quebra filtro antigo. Acrescentar informação a um evento é uma mudança compatível. **Tirar** informação não seria.

---

## 79.4 O setor 3: Salão das Turbinas

A planta do Capítulo 50:

- a galeria superior, a mesma vista pela janela no fim do setor 1;
- as passarelas em laço;
- o poço da turbina 3, a revelação, como subnível (ADR-0011);
- o comando manual, a única zona segura;
- a perseguição na volta do poço (Cap. 80);
- um atalho de escada que só abre por baixo.

| Peça | Sistema |
|---|---|
| A primeira vista do salão, de cima | Cena com controle (`AVGCinematicActor`, `bTakeControl = false`): a câmera não é tomada; a luz e o som conduzem o olhar (Cap. 49) |
| **O poço: seis pares de pegadas na poeira, os crachás (se encontrados), a alavanca travada "por dentro"** | Vinhetas com `UVGFactGateComponent` (os nomes só se `S1.AllBadgesFound`); o fato `S3.WellSeen` concedido por um gatilho |
| A perseguição | Cap. 80 |
| O atalho | Uma porta `AVGDoor` que só destranca pelo lado de baixo (`RequiredTag` concedido ao passar) |
| A quest | `DA_Quest_S3_Turbines`: Galeria → Passarelas → Poço (`CompletedIf: TEM S3.WellSeen`) → Fuga (`S3.ChaseSurvived`) → Comando manual |

O setor 3 não tem documento longo. A revelação é **espacial** (Capítulo 48, A Machine for Pigs): a jogadora entende o que aconteceu em 1994 pelo que vê no poço, e os três documentos do setor são curtos (uma página arrancada do livro de ocorrências, um crachá, um recado de Moraes nunca enviado).

---

## 79.5 O final

`L_Final` é a sala do comando manual. A estrutura é a única ramificação estrutural do jogo (Capítulo 47):

```text
 Helena entra ──► a Presença recua (trava do Diretor em Relax, Cap. 80) ──► Sônia fala (Critical)
     ──► duas interações na mesma sala:
           [alavanca]  "Desligar a turbina 3"        ──► BP_Cena_FinalA ──► fato Final.TurbineStopped
           [porta]     "Ir embora e deixá-la girar"  ──► BP_Cena_FinalB ──► fato Final.TurbineKept
     ──► cada cena pede no Finish a conversa de epílogo (variantes por todos os fatos) ──► créditos
```

A quest do final usa um recurso do Capítulo 45 que até aqui não tinha aparecido em conteúdo: a conclusão **"qualquer um"**.

```text
 DA_Quest_Final (Quest.Final.Choice)
   etapa "Escolha"   conclusão: AnyRequired
     objetivo A: Event.Cinematic.Finished  ctx Cinematic.Final.A
     objetivo B: Event.Cinematic.Finished  ctx Cinematic.Final.B
   etapa "Epilogo"   objetivo: Event.Dialogue.Finished  ctx Dialogue.Radio.Final.Epilogue
   ao concluir: sinal Signal.Final.Credits
```

O epílogo é a conversa com mais variantes do jogo. Ela lê a escolha final, o memorando, a admissão a Sônia, os crachás, a rota e os vigias. O Capítulo 81 escreve as falas, e a auditoria do Capítulo 47 garante que nenhuma combinação deixa Sônia muda.

Dois detalhes de design:

- **A escolha não tem tempo-limite.** Diferente das respostas de rádio, ela pede quietude (Capítulo 76: "o pico final não é o mais alto"). A Presença recua, e o tempo é da jogadora.
- **As duas opções são ações físicas no espaço**: puxar uma alavanca ou sair por uma porta, e não um menu. A escolha é feita com o corpo de Helena, na sala, coerente com o pilar de que a usina é o documento.

---

## 79.6 O save no jogo inteiro (Milestone 8)

O Capítulo 56 montou o save sobre o setor 1. Para o jogo inteiro, a pergunta é de **cobertura**: cada checkpoint, carregado, reproduz o estado?

| Checkpoint | Nível | Estado esperado ao carregar | Como verificar |
|---|---|---|---|
| `CP_Patio_Portao` | `L_Patio` | Quest do prólogo na etapa 2; rádio da chegada tocado | `vg.Debug.Narrative`, `vg.Debug.Quests` |
| `CP_S1_*` (4) | `L_CasaDeForca` | Cap. 56 | Teste existente |
| `CP_S2_Entrada` | `L_Subestacao` | `S1.Completed`; quest do S2 na etapa 1 | Painel |
| `CP_S2_Bifurcacao` | idem | A rota ainda não escolhida | Painel |
| `CP_S2_PosPatio` | idem | `S2.GuardsCleared` (ou furtivo); vigias **não** reaparecem | Painel + olhar o pátio |
| `CP_S3_Galeria` | `L_Turbinas` | — | Painel |
| `CP_S3_Comando` | idem | `S3.WellSeen`, `S3.ChaseSurvived` | Painel |
| `CP_Final` | `L_Final` | Antes da escolha | Painel |

A linha `CP_S2_PosPatio` é a que mais quebra, e o Capítulo 57 previu o porquê: os vigias não são persistidos um a um (atores colocados, mas com estado de vida que não se salva). O **fato de resultado** `S2.GuardsCleared` é que decide se eles existem: cada vigia tem um `UVGFactGateComponent` com `NÃO TEM S2.GuardsCleared`. Ao carregar depois do pátio, o fato existe, e os vigias simplesmente não aparecem. É a regra "salve a fonte, derive o resto" do Capítulo 57 aplicada a um encontro inteiro.

A matriz vira um teste manual guiado (`docs/qa/save-matriz.md`) e uma receita com cheats (`VGGotoCheckpoint`, `VGSave`, `VGLoad`, Cap. 61), executada a cada build semanal.

---

## 79.7 O dia a dia da produção

### Triagem de bugs

| Classe | Definição | Prazo |
|---|---|---|
| **A** | Travamento, progresso impossível, perda de save, conteúdo ofensivo por acidente | Corrigir antes de qualquer outra coisa |
| **B** | Atrapalha a experiência: uma fala errada, uma luz mentindo, um objetivo confuso | Corrigir no milestone |
| **C** | Cosmético ou raro | Lista de polimento (Cap. 82), sem garantia |

Cada bug tem passos para reproduzir e, sempre que possível, um **estado de teste** (o JSON de narrativa do Capítulo 46, um save, uma linha de cheats). Bug sem reprodução é palpite.

### Cortes no meio da produção

O cálculo do Capítulo 78 e o registro de riscos do Capítulo 76 vão pedir cortes. Os cortes da Vigília já estão pré-negociados no MoSCoW: o furtivo do setor 2 (*could*), as fitas narradas (*could*), o caderno de Helena (*should*). Cortar algo **fora** dessa lista exige revisitar os pilares, e às vezes um ADR.

---

## Estudo de caso: o jogo sempre jogável

**[INFERÊNCIA]** Relatos públicos de desenvolvedores, em postmortems e palestras de produção, voltam com frequência a um mesmo tema: equipes que mantêm o jogo jogável de ponta a ponta durante a produção descobrem problemas de ritmo e de integração muito antes das que montam partes isoladas para juntar no fim. O custo é a disciplina de não deixar nada quebrado por mais de um ciclo; o ganho é que a última fase da produção vira polimento, e não descoberta.

**Lição para a Vigília:** o build semanal do menu aos créditos é a versão individual dessa prática. Ele é barato na Vigília porque a arquitetura ajuda: quests, conversas e documentos com texto provisório já fazem o jogo "funcionar" do começo ao fim.

---

## Comparação com o desenvolvimento tradicional

| Produção por setor | O que você conhece | Onde a analogia cai |
|---|---|---|
| Jogo sempre jogável | Integração e entrega contínuas | "Jogável" inclui ritmo, verificado por pessoas |
| Manifesto de setor | Manifesto de deploy, lista de artefatos | Inclui **tetos** de conteúdo, não só presença |
| Acrescentar contexto ao evento de morte | Evolução compatível de contrato de evento | — (a regra é a mesma: acrescentar é compatível; remover não) |
| Matriz de checkpoints | Matriz de testes de migração de dados | O "dado" inclui o mundo derivado (vigias que não devem reaparecer) |
| Triagem A/B/C | Severidade de incidentes | "Ofensivo por acidente" é classe A num jogo narrativo |

---

## Unreal Engine: o que ajuda na produção

- **Asset Manager** e *primary assets* para os manifestos e as quests.
- ***Data Validation*** (`IsDataValid`, Cap. 13) e o comando de validação em lote do editor para checar todo o conteúdo antes do build.
- **`-ExecCmds`** e os cheats (Cap. 61) para receitas de teste reproduzíveis.
- ***Level Streaming*** para o poço da turbina 3 (ADR-0011).

---

## Abordagens: em que ordem produzir

| Critério | A. Um setor de cada vez, até ficar pronto | B. Todos os setores juntos, disciplina por disciplina | **C. Jogo sempre jogável; setores em paralelo de qualidade baixa, depois passes por setor** |
|---|---|---|---|
| **Integração** | Tardia entre setores | Tardia em qualidade | Contínua |
| **Ritmo sentido cedo** | Não | Sim, em qualidade baixa | Sim |
| **Risco de setor inacabado** | Alto no último | Baixo | Baixo |
| **Adequação à Vigília** | Não | Perde a lição do vertical slice | **Sim** |

**Decisão: C.** Primeiro os setores 2, 3 e o final jogáveis com texto e sons provisórios. Depois os passes do Capítulo 78, setor a setor, na ordem em que a jogadora os vê.

---

## Implementação: o manifesto de setor

```cpp
// Source/Vigilia/Narrative/VGSectorManifest.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "GameplayTagContainer.h"
#include "VGSectorManifest.generated.h"

class UVGDialogueData;
class UVGDocumentData;
class UVGQuestData;

/** O que um setor contém, e quanto pode conter (os tetos do Cap. 76). */
UCLASS(BlueprintType)
class VIGILIA_API UVGSectorManifest : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, Category = "Sector")
    TSoftObjectPtr<UWorld> Level;

    UPROPERTY(EditDefaultsOnly, Category = "Sector")
    TObjectPtr<const UVGQuestData> Quest;

    UPROPERTY(EditDefaultsOnly, Category = "Sector")
    TArray<TObjectPtr<const UVGDocumentData>> Documents;

    UPROPERTY(EditDefaultsOnly, Category = "Sector")
    TArray<TObjectPtr<const UVGDialogueData>> Conversations;

    /** Fatos que as conversas deste setor leem (para a auditoria do Cap. 47). */
    UPROPERTY(EditDefaultsOnly, Category = "Sector", meta = (Categories = "Narrative.Fact"))
    TArray<FGameplayTag> RelevantFacts;

    UPROPERTY(EditDefaultsOnly, Category = "Sector")
    TArray<FName> CheckpointIds;

    UPROPERTY(EditDefaultsOnly, Category = "Sector|Ceilings", meta = (ClampMin = "0"))
    int32 MaxDocuments = 5;

    UPROPERTY(EditDefaultsOnly, Category = "Sector|Ceilings", meta = (ClampMin = "0"))
    int32 MaxConversations = 6;

    virtual FPrimaryAssetId GetPrimaryAssetId() const override
    {
        return FPrimaryAssetId(TEXT("VGSector"), GetFName());
    }
};

namespace VGSectorRules
{
    /** Problemas do manifesto (vazio = ok): referências nulas, tetos ultrapassados, conversas mudas ou com nós mortos. */
    TArray<FString> Check(const UVGSectorManifest& Manifest);
}
```

```cpp
// Source/Vigilia/Narrative/VGSectorManifest.cpp
#include "Narrative/VGSectorManifest.h"

#include "Narrative/VGBranchAudit.h"
#include "Narrative/VGDialogueData.h"

TArray<FString> VGSectorRules::Check(const UVGSectorManifest& Manifest)
{
    TArray<FString> Problems;
    const FString Name = Manifest.GetName();
    if (Manifest.Level.IsNull()) { Problems.Add(Name + TEXT(": sem nível.")); }
    if (!Manifest.Quest)         { Problems.Add(Name + TEXT(": sem quest.")); }
    if (Manifest.Documents.Num() > Manifest.MaxDocuments)
    {
        Problems.Add(FString::Printf(TEXT("%s: %d documentos, teto %d."), *Name, Manifest.Documents.Num(), Manifest.MaxDocuments));
    }
    if (Manifest.Conversations.Num() > Manifest.MaxConversations)
    {
        Problems.Add(FString::Printf(TEXT("%s: %d conversas, teto %d."), *Name, Manifest.Conversations.Num(), Manifest.MaxConversations));
    }
    for (const UVGDialogueData* Conversation : Manifest.Conversations)
    {
        if (!Conversation)
        {
            Problems.Add(Name + TEXT(": conversa vazia na lista."));
            continue;
        }
        const VGBranchAudit::FResult Audit = VGBranchAudit::Audit(*Conversation, Manifest.RelevantFacts);
        if (!Audit.SilentCombinations.IsEmpty())
        {
            Problems.Add(FString::Printf(TEXT("%s: %s fica muda em %d combinação(ões)."),
                *Name, *Conversation->GetName(), Audit.SilentCombinations.Num()));
        }
        for (const FName& Dead : Audit.UnreachableNodes)
        {
            Problems.Add(FString::Printf(TEXT("%s: %s.%s nunca toca."), *Name, *Conversation->GetName(), *Dead.ToString()));
        }
    }
    return Problems;
}
```

```cpp
// Source/Vigilia/Tests/VGSectorManifestTest.cpp
#include "Misc/AutomationTest.h"
#include "Engine/AssetManager.h"
#include "Narrative/VGSectorManifest.h"

#if WITH_DEV_AUTOMATION_TESTS && WITH_EDITOR

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGSectorManifestTest, "Vigilia.Content.SectorManifests",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGSectorManifestTest::RunTest(const FString& Parameters)
{
    TArray<FPrimaryAssetId> Ids;
    UAssetManager::Get().GetPrimaryAssetIdList(FPrimaryAssetType(TEXT("VGSector")), Ids);
    TestTrue(TEXT("Há manifestos registrados (prólogo, S1, S2, S3, final)"), Ids.Num() >= 5);

    for (const FPrimaryAssetId& Id : Ids)
    {
        const UVGSectorManifest* Manifest =
            Cast<UVGSectorManifest>(UAssetManager::Get().GetPrimaryAssetPath(Id).TryLoad());
        if (!TestNotNull(*FString::Printf(TEXT("Manifesto %s carrega"), *Id.ToString()), Manifest))
        {
            continue;
        }
        for (const FString& Problem : VGSectorRules::Check(*Manifest))
        {
            AddError(Problem);
        }
    }
    return true;
}

#endif
```

### Explicação das decisões

- **Um teste de conteúdo, não de código.** Ele carrega os manifestos reais do projeto e falha com a lista de problemas. É o teste que mais quebra durante a produção, e é para isso que ele existe.
- **A auditoria do Capítulo 47 reaproveitada** com os fatos declarados no manifesto, que funciona como a resposta ao desafio daquele capítulo ("onde guardar a lista de fatos relevantes de cada conversa?"): **no manifesto do setor**.
- **Tetos no dado, não no código.** O teto é uma decisão de produção que muda (Capítulo 78), e mudá-lo é editar um asset.
- **`#if WITH_EDITOR`** no teste, porque carregar assets por caminho e o Asset Manager configurado são do ambiente de editor. O build Shipping não precisa dele.
- **Os checkpoints como nomes**, sem verificação automática de existência no nível. Verificar exigiria carregar cada mapa num teste, o que é possível (um teste funcional, Cap. 61) mas caro. A matriz manual da seção 79.6 cobre isso semanalmente.

---

## Projeto Final — do slice ao jogo

- [ ] Os cinco manifestos (`DA_Setor_Prologo`, `_S1`, `_S2`, `_S3`, `_Final`), com o teste verde.
- [ ] Setor 2 jogável: rotas, documentos, vigias, seccionadoras, quest; a regra dos vigias derrubados.
- [ ] Setor 3 jogável: galeria, passarelas, poço (vinhetas condicionadas), atalho, quest. A perseguição vem do Cap. 80.
- [ ] Final jogável: a sala, as duas interações, as duas cenas, a quest "qualquer um", os créditos.
- [ ] O build semanal do menu aos créditos, com a data de cada um no `DEVLOG.md`.
- [ ] A matriz de save executada no build mais recente; nenhum bug A aberto.
- [ ] Milestones 3, 6 e 8 fechados, com os critérios do Capítulo 76.

---

## Decisões arquiteturais (de produção)

1. **Jogo sempre jogável**: um build por semana do menu aos créditos.
2. **O setor é a unidade de conteúdo**, com um manifesto verificado por teste (referências, tetos, auditoria).
3. **Setores montados com sistemas existentes**; código novo só onde um sistema estava estreito (o contexto do evento de morte) ou faltava (a zona de trava do Diretor, Cap. 80).
4. **A rota do setor 2 como fato monotônico** (a primeira tomada vence), sem grupo exclusivo.
5. **O encontro dos vigias derivado de um fato de resultado**, com os vigias condicionados ao fato.
6. **A escolha final como etapa "qualquer um"**, com duas cenas e um epílogo de variantes.
7. **Bugs com classe e reprodução**; cortes pré-negociados no MoSCoW.

---

## Armadilhas

- **O setor pronto isolado**, que não conversa com o save, a quest ou o ritmo dos outros.
- **Código novo por hábito**, quando o sistema existente resolveria com dados. Pergunte primeiro: qual sistema já faz isso?
- **Remover informação de um evento** "porque ninguém usa". Alguém usa: os filtros antigos e as regras de fatos.
- **Encontros que reaparecem** depois do load, porque o resultado não foi registrado como fato.
- **A escolha final com tempo-limite**, ou num menu fora do espaço.
- **Bug sem reprodução.**
- **Cortar fora da lista pré-negociada** sem revisitar os pilares.

---

## Exercício

**Parte 1 — manifestos (1,5 h).** Implemente `UVGSectorManifest`, `VGSectorRules` e o teste. Registre o tipo `VGSector` no Asset Manager. Crie os cinco manifestos, mesmo com conteúdo incompleto, e veja o teste falhar com a lista do que falta. Ela é o seu quadro de produção.

**Parte 2 — o setor 2 (o grosso do Milestone 6).** Monte o setor 2 com as peças da seção 79.3. Conte o código novo que você escreveu e explique cada linha no `DEVLOG.md`.

**Parte 3 — o setor 3 e o final.** Monte-os com as seções 79.4 e 79.5 (a perseguição pode ser um gatilho provisório até o Cap. 80).

**Parte 4 — save (Milestone 8, 3 h).** Execute a matriz da seção 79.6. Para cada linha que falhar, abra um bug com reprodução (save + cheats) e corrija os de classe A.

---

## Desafio — o setor que não existe

Desenhe, **só no papel e nos dados**, um setor extra entre o 2 e o 3 (por exemplo, a represa): o manifesto, a quest, dois documentos, três conversas e uma vinheta. Não escreva código. Responda:

1. Quanto do setor cabe nos sistemas existentes?
2. Que sistema faltaria?
3. Quanto ele custaria, pelo número do Capítulo 78?

É o teste final da arquitetura: um setor novo deveria ser, quase todo, dados.

---

## Uso de IA

1. **Para montar um setor a partir dos sistemas:**
   > "Aqui está a lista de sistemas do meu jogo (quests por etapas, objetivos por eventos, diálogo com variantes por fatos, documentos, gatilhos condicionados a fatos, atores condicionados, cenas com estado, checkpoints) e a planta de um setor novo (abaixo). Para cada momento do setor, diga qual sistema o implementa e com que dados. Marque com ⚠️ só o que nenhum sistema cobre. [sistemas + planta]"

2. **Para revisar a matriz de save:**
   > "Aqui estão os checkpoints do meu jogo e o que cada um deve restaurar. Para cada um, liste o que pode dar errado ao carregar (encontros que reaparecem, portas no estado errado, falas repetidas, fatos ausentes) e como verificar com cheats em menos de um minuto. [matriz]"

3. **Para triar bugs:**
   > "Classifique estes relatos de playtest em A (travamento, progresso impossível, perda de save, ofensivo), B (atrapalha a experiência) ou C (cosmético), e para cada A proponha os passos mínimos de reprodução que eu deveria tentar primeiro. [relatos]"

**Cuidado específico:** a IA sugere com facilidade "um sistema novo" para cada pedido de conteúdo. O primeiro pedido acima faz o contrário: ele pede o mapeamento para o que **já existe**, e trata o resto como exceção a justificar.

---

## Checklist

- [ ] O build do menu aos créditos funciona toda semana.
- [ ] Os manifestos de setor estão verdes no teste de conteúdo.
- [ ] Os setores 2 e 3 e o final foram montados quase só com dados, e sei justificar cada linha de código novo.
- [ ] A escolha final é uma etapa "qualquer um", com duas cenas e um epílogo auditado.
- [ ] A matriz de save passa em todos os checkpoints.
- [ ] Os bugs têm classe e reprodução, e os cortes saíram da lista pré-negociada.

---

## Para ir além

- **GDC Vault** (gdcvault.com): postmortems de jogos narrativos e de terror feitos por equipes pequenas, sobre produção de conteúdo e integração contínua (confira os títulos lá).
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Data Validation** e **Asset Manager**.
- O seu `DEVLOG.md`: a contagem de código novo por setor é a melhor métrica da qualidade da sua arquitetura.

---

➡️ **Próximo:** [Capítulo 80 — AI](cap-80-ai.md)
