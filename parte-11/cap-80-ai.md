# Capítulo 80 — AI

## Objetivo

Ao final deste capítulo você deve conseguir:

- planejar os **encontros com IA** de um jogo inteiro: que ameaça aparece em cada setor e com que intensidade;
- transformar as constantes do Diretor em **perfis por setor** (Data Assets), cumprindo a dívida declarada no Capítulo 42;
- criar **zonas de trava do Diretor**, que deixam o design de nível pedir "aqui, nada de caça" sem tocar em código;
- projetar e implementar a **perseguição** do setor 3 com garantias de justiça;
- ajustar o **encontro dos vigias** com perfis de utilidade e tokens;
- verificar a IA com **critérios mensuráveis**: telegrafia, mortes por setor, taxa de sucesso da perseguição.

---

## Contexto

A Parte V construiu a IA da Vigília num laboratório: a Presença no Pátio e no Galpão, os vigias no Galpão, e o Diretor regulando a frequência dos encontros. Funcionava, com números escolhidos para testar.

O jogo real tem outras exigências. Cada setor pede uma **dosagem** diferente:

- o setor 1 é cenografia;
- o setor 2 mistura pessoas armadas e uma criatura;
- o setor 3 é caça;
- e o final é quietude.

O Diretor do Capítulo 42 tinha um comentário honesto no código: *"Simplificação: constantes aqui; no projeto final, um Data Asset de pacing."* Chegou a hora.

O Capítulo 76 atribuiu a este capítulo o Milestone 4 (AI), com um critério de conclusão em duas partes: **ninguém morre mais de duas vezes por setor; ninguém atravessa um setor sem sentir a Presença.** As duas metades puxam em direções opostas, e o trabalho deste capítulo é equilibrá-las.

---

## 80.1 Os encontros do jogo

| Parte | Ameaça | Intensidade | O que o encontro ensina | Ferramentas |
|---|---|---|---|---|
| **Prólogo** | Nenhuma | — | Que o lugar é estranho | Áudio, luz |
| **Setor 1** | A Presença como **cenografia** (o susto) | Baixa, autoral | Que algo existe | Cena com controle (Cap. 49) |
| **Setor 2** | **Vigias** (pessoas armadas) + a Presença **sistêmica**, mas longe do pátio | Média | Que há humanos envolvidos; que a luz e a cobertura importam | Parte V; zona de trava (80.3) |
| **Setor 3** | A Presença **caçando**, com uma **perseguição** | Alta | Que ela é real, e que fugir é a regra | Perfil agressivo; perseguição (80.4) |
| **Final** | A Presença **recua** | Nula | A quietude da escolha | Zona de trava (80.3) |

Repare na progressão: **cenografia → pessoas → sistema** (Capítulo 76). A jogadora só encontra a Presença sistêmica depois de ter aprendido com ela (setor 1) e de ter aprendido a lutar e a se cobrir com outra ameaça (setor 2). No setor 3, ela já conhece as regras (luz protege, sobrecarga repele, correr faz barulho), e a caça é um exame do que aprendeu.

---

## 80.2 Um perfil de Diretor por setor

O Diretor (Capítulo 42) tem quatro fases (Relax → BuildUp → Peak → Recovery) e tempos que decidem o ritmo. Com um único conjunto de constantes, o setor 2 seria tão agressivo quanto o 3, ou o 3 tão manso quanto o 2. A solução é a mesma de toda configuração que varia por contexto: **um Data Asset por contexto**.

| Parâmetro | Setor 1 | Setor 2 | Setor 3 | Por quê |
|---|---|---|---|---|
| `MinRelaxTime` (s) | 600 (o Diretor não age) | 60 | 30 | No setor 1 a Presença é autoral, não sistêmica |
| `MaxRelaxTime` (s) | 900 | 150 | 75 | O setor 3 nunca fica tranquilo por muito tempo |
| `BuildUpTime` (s) | 25 | 30 | 15 | No setor 3, os sinais são curtos: a jogadora já os conhece |
| `MaxPeakTime` (s) | 0 | 20 | 35 | A caça do setor 3 dura mais |
| `RecoveryTime` (s) | 20 | 30 | 15 | Alívio menor onde a tensão é o objetivo |
| `bAllowPeak` | ✗ | ✓ | ✓ | O setor 1 nunca tem caça sistêmica |

Os números são de partida, **[DECISÃO DE PROJETO]** a confirmar no playtest. O que importa é que eles moram num **dado** que o designer muda sem compilar, e que cada setor tem o seu.

> 🌉 **Ponte:** é configuração por ambiente (*profiles*), como `application-prod.yml` × `application-dev.yml`: o mesmo código com parâmetros diferentes por contexto.
>
> 🧱 **Onde a ponte cai:** a "correção" da configuração não se verifica com testes de integração. Ela se verifica com **pessoas jogando**, e os números certos para uma jogadora experiente são errados para uma novata. A Vigília escolhe a média do playtest e oferece acessibilidade (Cap. 55) para os extremos.

---

## 80.3 Zonas de trava do Diretor

O Diretor decide a frequência dos encontros pela **tensão estimada** da jogadora. Mas há lugares em que o design já sabe o que quer, independentemente da tensão:

- **O pátio dos vigias (setor 2):** enquanto houver vigias de pé, a Presença não caça ali. Duas ameaças ao mesmo tempo, numa arena de tiro, fariam o encontro virar caos e quebrariam a leitura de "agora é combate".
- **A sala do comando manual (final):** a escolha pede quietude. A Presença recua.
- **A perseguição (setor 3):** do poço até o comando, a caça **precisa** acontecer.

O Diretor já tem a ferramenta para isso: as **travas de roteiro** (`PushScriptLock`/`PopScriptLock`, Capítulo 42), que forçam uma fase. Falta um jeito de o **nível** pedi-las sem Blueprint de cola: uma zona com uma condição sobre fatos, que trava enquanto a jogadora está dentro e a condição vale.

Três decisões de desenho:

1. **A zona trava enquanto as duas coisas forem verdadeiras**: a jogadora dentro, e a condição sobre fatos passando. O pátio trava "enquanto NÃO TEM `S2.GuardsCleared`". Quando o último vigia cai, o fato chega (Capítulo 79), a zona solta a trava sozinha, e a Presença pode voltar a circular.
2. **A zona é dona da trava que pediu** (o *handle*) e a solta em todos os caminhos: a jogadora sai, a condição deixa de valer, o nível sai (`EndPlay`).
3. **A fase forçada é um parâmetro**: `Relax` no pátio e no final, `Peak` na perseguição. É a mesma ferramenta para "nada de caça aqui" e para "aqui, caça".

---

## 80.4 A perseguição

A spec do projeto final pede **uma sequência de perseguição** (seção 3.3), e o Capítulo 50 desenhou o espaço:

- passarelas em laço, saindo do poço da turbina 3 até o comando manual;
- uma porta que fecha;
- o destino iluminado.

Este capítulo dá à perseguição o comportamento e as **garantias**.

### O que a jogadora vive

```text
 poço (revelação, S3.WellSeen) ──► as luzes do poço falham em cascata (o mesmo sinal do susto do setor 1)
   ──► a Presença surge ATRÁS, fora de vista (spawn com regra de visibilidade, Cap. 32)
   ──► telegrafia longa (o som, a falha de luz) ──► caça (Peak travado pela zona)
   ──► passarelas em laço; a porta de manutenção fecha ATRÁS da jogadora (filtro da Presença evita portas fechadas, Cap. 35)
   ──► a Presença contorna pelo laço, o que dá à jogadora a vantagem que o laço foi desenhado para dar
   ──► o comando manual: luz âmbar estável, zona segura (Cap. 51) ──► gatilho: fato S3.ChaseSurvived; a zona solta a trava
```

### As garantias de justiça

Uma perseguição injusta frustra; uma perseguição que não ameaça entedia. As garantias, todas verificáveis:

| Garantia | Como é garantida | Como é verificada |
|---|---|---|
| **Nenhum ataque sem telegrafia** (Cap. 21) | Estrutura da `BT_Presenca`: a task de ataque só existe depois da task de telegrafia, na mesma *sequence* (Cap. 37) | Teste de estrutura da árvore (Cap. 72) |
| **Telegrafia ≥ 1,2 s** | Parâmetro da task de telegrafia, 1,5 s na perseguição | Telemetria: intervalo entre o sinal e o dano |
| **Rota de fuga sempre existe** | O laço do Capítulo 50 e a porta que fecha atrás | Teste no PIE com a Presença na velocidade máxima |
| **A Presença não surge à vista** | Ponto de surgimento fora do cone e da linha de visão (Cap. 32) | `VGVisibility` (Interlúdio II) no momento do spawn |
| **A jogadora pode se defender** | Sobrecarga da lanterna (Cap. 51) e sinalizador (Cap. 28) funcionam durante a caça | Playtest |
| **Morrer não é recomeçar do zero** | Checkpoint antes da perseguição (`CP_S3_Poco`), fora da trava de momento (Cap. 56) | Matriz de save (Cap. 79) |

### Os números

| Parâmetro | Valor inicial | Por quê |
|---|---|---|
| Velocidade da Presença na caça | 92% da corrida da jogadora | Ela alcança quem para ou erra o caminho, não quem corre bem |
| Distância de surgimento | 18–22 m atrás | Fora do alcance útil da lanterna (12–15 m, Cap. 51) |
| Duração esperada | 35–50 s | Dentro do `MaxPeakTime` do perfil do setor 3 |
| Meta de sucesso na primeira tentativa | 70–85% | Abaixo de 70%, frustra; acima de 85%, a ameaça não é crível |

A meta de sucesso é medida pela telemetria (Capítulo 78): quantas tentativas cada pessoa precisou entre o fato `S3.WellSeen` e o fato `S3.ChaseSurvived`.

---

## 80.5 Os vigias no jogo real

O encontro do pátio usa toda a Parte V:

- três vigias, com perfis de utilidade por arquétipo (o 🔁 do Capítulo 72: veterano e recrutas);
- tokens (Attack 2, Flank 1, Suppress 1, Bark 1);
- EQS de cobertura e de flanco;
- *barks* gerados offline e gravados (Capítulo 71).

O ajuste para o jogo real é sobretudo **dosagem**:

- **A munição da jogadora é contada.** A pistola dos vigias, se coletada, vem com pouca munição, e o encontro é desenhado para ser vencido com cobertura, não com precisão. O TTD de 2,5 s sob fogo de um vigia (documento de combate, Cap. 21) faz da cobertura uma necessidade.
- **O sinalizador não fere humanos** (multiplicador 0 de luz, Cap. 22). A sobrecarga também não. As ferramentas de defesa contra a Presença são inúteis contra os vigias. O jogo ensina, sem tutorial, que são ameaças de naturezas diferentes.
- **Os vigias são evitáveis** (*could*, Cap. 76): rotas pelo alto, percepção que não vê no escuro (Cap. 36), e o fato `S2.GuardsAvoided` concedido ao sair do pátio sem combate. Se o furtivo for cortado, a zona de trava e o fato `S2.GuardsCleared` continuam bastando.

---

## Estudo de caso: Alien: Isolation — dois cérebros

**[FATO PÚBLICO — confira as fontes]** Desenvolvedores de *Alien: Isolation* (Creative Assembly, 2014) descreveram em entrevistas e palestras uma IA em duas camadas. Um "diretor" sabe onde o jogador está e decide quando aproximar a criatura. A criatura, por sua vez, só age pelo que **percebe**: ela é aproximada, mas precisa encontrar o jogador com os próprios sentidos.

**[INFERÊNCIA]** A separação resolve um dilema de horror sistêmico. Uma criatura que só percebe pode passar o jogo inteiro longe do jogador e virar irrelevante. Uma que sabe tudo é injusta e parece trapacear. O diretor garante a **frequência** dos encontros; a percepção garante a **justiça** de cada encontro: se você se escondeu bem, ela não te achou.

**Lição para a Vigília:** é exatamente a divisão da Parte V. O Diretor (Cap. 42) "controla a frequência dos encontros, nunca as regras deles", e a Presença percebe pela luz, pelo som e pela postura (Cap. 36). As zonas de trava deste capítulo não quebram a divisão: elas mudam a **frequência** em lugares específicos (nenhuma caça no pátio; caça garantida na perseguição), e o encontro em si continua decidido pela percepção.

---

## Comparação com o desenvolvimento tradicional

| IA no jogo real | O que você conhece | Onde a analogia cai |
|---|---|---|
| Perfil de Diretor por setor | Configuração por ambiente | O "teste" de uma configuração é o playtest |
| Zona de trava do Diretor | *Feature flag* por região, sobreposição de política | A zona é posicionada no espaço, por designers |
| Garantias de justiça | SLOs (objetivos de nível de serviço) | Medidos em sensação e em telemetria de poucas pessoas |
| Meta de sucesso de 70–85% | Taxa de conversão-alvo | Acima da meta também é falha: sem ameaça não há medo |
| Dois cérebros (diretor e criatura) | Orquestrador e agentes autônomos | O orquestrador **nunca** decide pelo agente, só o aproxima |

---

## Unreal Engine: o que é usado

Nada novo da engine. Este capítulo usa:

- a Parte V inteira (BT, Blackboard, EQS, AI Perception, navegação com filtros, tokens);
- Data Assets para os perfis (`UPrimaryDataAsset`);
- um `UBoxComponent` com sobreposição para a zona;
- o Visual Logger e a categoria `VigiliaAI` do Gameplay Debugger (Cap. 61) para depurar a caça.

---

## Abordagens: como dosar a IA por lugar

| Critério | A. Constantes globais (Cap. 42) | B. Scripts por setor (Level Blueprint liga e desliga a Presença) | **C. Perfil de dados por setor + zonas de trava com condição** |
|---|---|---|---|
| **Granularidade** | Nenhuma | Total | Setor (perfil) e lugar (zona) |
| **Quem ajusta** | Programador | Quem abre o Level Blueprint | Designer, em dados e no nível |
| **Respeita "frequência, nunca regras"** | Sim | Não: ligar e desligar a Presença muda as regras | Sim |
| **Limpeza das travas** | — | Manual, fácil de esquecer | Por construção (dono do *handle*) |
| **Adequação à Vigília** | Não | Volta ao Interlúdio I | **Sim** |

**Decisão: C.**

---

## Implementação

### 1. O perfil do Diretor

```cpp
// Source/Vigilia/AI/VGDirectorProfile.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "VGDirectorProfile.generated.h"

/** O ritmo do Diretor num setor (substitui as constantes de VGDirectorTuning, Cap. 42). */
UCLASS(BlueprintType)
class VIGILIA_API UVGDirectorProfile : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, Category = "Pacing", meta = (ClampMin = "0.0"))
    float MinRelaxTime = 45.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Pacing", meta = (ClampMin = "0.0"))
    float MaxRelaxTime = 120.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Pacing", meta = (ClampMin = "0.0"))
    float BuildUpTime = 25.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Pacing", meta = (ClampMin = "0.0"))
    float MaxPeakTime = 30.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Pacing", meta = (ClampMin = "0.0"))
    float RecoveryTime = 20.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Pacing", meta = (ClampMin = "0.0"))
    float TensionSmoothing = 0.5f;

    /** Falso: o Diretor nunca entra em Peak por conta própria (só por trava de roteiro). */
    UPROPERTY(EditDefaultsOnly, Category = "Pacing")
    bool bAllowPeak = true;
};

namespace VGDirectorProfileRules
{
    /** Problemas de um perfil (vazio = ok). Os designers mexem nesses números; o editor avisa. */
    TArray<FString> Validate(const UVGDirectorProfile& Profile);
}
```

```cpp
// Source/Vigilia/AI/VGDirectorProfile.cpp
#include "AI/VGDirectorProfile.h"

TArray<FString> VGDirectorProfileRules::Validate(const UVGDirectorProfile& Profile)
{
    TArray<FString> Problems;
    if (Profile.MinRelaxTime > Profile.MaxRelaxTime)
    {
        Problems.Add(TEXT("MinRelaxTime maior que MaxRelaxTime: o Relax nunca termina pela tensão."));
    }
    if (Profile.bAllowPeak && Profile.MaxPeakTime <= 0.0f)
    {
        Problems.Add(TEXT("bAllowPeak com MaxPeakTime 0: o pico acaba no mesmo frame em que começa."));
    }
    if (Profile.TensionSmoothing <= 0.0f)
    {
        Problems.Add(TEXT("TensionSmoothing precisa ser > 0 (decaimento exponencial, Cap. 3)."));
    }
    return Problems;
}
```

🔁 **No `UVGDirectorSubsystem` (Capítulo 42):** o `namespace VGDirectorTuning` sai. O subsistema ganha `TObjectPtr<const UVGDirectorProfile> Profile` e `void ApplyProfile(const UVGDirectorProfile*)`, e o `UpdatePhase` lê `Profile->MinRelaxTime` e os demais onde lia as constantes. Sem perfil, um perfil padrão criado no `Initialize` reproduz os números antigos. A transição para `Peak` passa a exigir `Profile->bAllowPeak` (as travas de roteiro continuam podendo forçar qualquer fase). O `AVGGameMode` ganha `UPROPERTY(EditAnywhere) TObjectPtr<const UVGDirectorProfile> DirectorProfile` e o aplica no `BeginPlay`. Cada nível usa o seu GameMode (ou a sobreposição nas *World Settings*) com o perfil do setor.

O perfil também valida no editor, com a mesma regra:

```cpp
#if WITH_EDITOR
EDataValidationResult UVGDirectorProfile::IsDataValid(FDataValidationContext& Context) const
{
    EDataValidationResult Result = Super::IsDataValid(Context);
    for (const FString& Problem : VGDirectorProfileRules::Validate(*this))
    {
        Context.AddError(FText::FromString(Problem));
        Result = EDataValidationResult::Invalid;
    }
    return Result;
}
#endif
```

(A declaração vai no cabeçalho, dentro de `#if WITH_EDITOR`, e o `.cpp` inclui `Misc/DataValidation.h`, como nos Capítulos 44–45.)

### 2. A zona de trava

```cpp
// Source/Vigilia/AI/VGDirectorLockZone.h
#pragma once

#include "CoreMinimal.h"
#include "AI/VGDirectorSubsystem.h"
#include "GameFramework/Actor.h"
#include "GameplayTagContainer.h"
#include "VGDirectorLockZone.generated.h"

class UBoxComponent;

/**
 * Enquanto a jogadora está dentro E a condição sobre fatos passa, força uma fase do Diretor.
 * Dona do handle: solta a trava ao sair, ao a condição falhar, ou no EndPlay.
 */
UCLASS()
class VIGILIA_API AVGDirectorLockZone : public AActor
{
    GENERATED_BODY()

public:
    AVGDirectorLockZone();

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<UBoxComponent> Volume;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Director")
    EVGDirectorPhase ForcedPhase = EVGDirectorPhase::Relax;

    /** Vazia = sempre. Ex.: pátio dos vigias = NÃO TEM S2.GuardsCleared. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Director")
    FGameplayTagQuery Condition;

private:
    UFUNCTION()
    void HandleBeginOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
                            UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep,
                            const FHitResult& SweepResult);

    UFUNCTION()
    void HandleEndOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
                          UPrimitiveComponent* OtherComp, int32 OtherBodyIndex);

    void Refresh();

    bool bPlayerInside = false;
    int32 LockHandle = INDEX_NONE;
    FDelegateHandle FactHandle;
};
```

```cpp
// Source/Vigilia/AI/VGDirectorLockZone.cpp
#include "AI/VGDirectorLockZone.h"

#include "Components/BoxComponent.h"
#include "GameFramework/Pawn.h"
#include "Narrative/VGNarrativeSubsystem.h"

AVGDirectorLockZone::AVGDirectorLockZone()
{
    PrimaryActorTick.bCanEverTick = false;
    Volume = CreateDefaultSubobject<UBoxComponent>(TEXT("Volume"));
    Volume->SetCollisionProfileName(TEXT("Trigger"));
    SetRootComponent(Volume);
}

void AVGDirectorLockZone::BeginPlay()
{
    Super::BeginPlay();
    Volume->OnComponentBeginOverlap.AddDynamic(this, &AVGDirectorLockZone::HandleBeginOverlap);
    Volume->OnComponentEndOverlap.AddDynamic(this, &AVGDirectorLockZone::HandleEndOverlap);
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        // A condição pode mudar com a jogadora dentro (o último vigia cai): reavalia no anúncio.
        FactHandle = Narrative->OnFactChangedNative.AddWeakLambda(this, [this](FGameplayTag, bool) { Refresh(); });
    }
}

void AVGDirectorLockZone::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    bPlayerInside = false;
    Refresh(); // solta a trava, se houver
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        Narrative->OnFactChangedNative.Remove(FactHandle);
    }
    Super::EndPlay(EndPlayReason);
}

void AVGDirectorLockZone::HandleBeginOverlap(UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*,
                                             int32, bool, const FHitResult&)
{
    const APawn* Pawn = Cast<APawn>(OtherActor);
    if (Pawn && Pawn->IsPlayerControlled())
    {
        bPlayerInside = true;
        Refresh();
    }
}

void AVGDirectorLockZone::HandleEndOverlap(UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*, int32)
{
    const APawn* Pawn = Cast<APawn>(OtherActor);
    if (Pawn && Pawn->IsPlayerControlled())
    {
        bPlayerInside = false;
        Refresh();
    }
}

void AVGDirectorLockZone::Refresh()
{
    UVGDirectorSubsystem* Director = GetWorld() ? GetWorld()->GetSubsystem<UVGDirectorSubsystem>() : nullptr;
    const UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this);
    const bool bWants = bPlayerInside && Narrative && Narrative->MatchesFacts(Condition);

    if (bWants && LockHandle == INDEX_NONE && Director)
    {
        LockHandle = Director->PushScriptLock(ForcedPhase, GetFName());
    }
    else if (!bWants && LockHandle != INDEX_NONE)
    {
        if (Director)
        {
            Director->PopScriptLock(LockHandle);
        }
        LockHandle = INDEX_NONE;
    }
}
```

### 3. Teste

```cpp
// Source/Vigilia/Tests/VGDirectorProfileTest.cpp
#include "Misc/AutomationTest.h"
#include "AI/VGDirectorProfile.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGDirectorProfileTest, "Vigilia.AI.Director.ProfileValidation",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGDirectorProfileTest::RunTest(const FString& Parameters)
{
    UVGDirectorProfile* Profile = NewObject<UVGDirectorProfile>();
    TestEqual(TEXT("O perfil padrão (números do Cap. 42) é válido"), VGDirectorProfileRules::Validate(*Profile).Num(), 0);

    Profile->MinRelaxTime = 200.0f; // maior que MaxRelaxTime (120)
    TestEqual(TEXT("Relax impossível é apontado"), VGDirectorProfileRules::Validate(*Profile).Num(), 1);

    Profile->MinRelaxTime = 45.0f;
    Profile->MaxPeakTime = 0.0f;
    TestEqual(TEXT("Pico sem duração é apontado"), VGDirectorProfileRules::Validate(*Profile).Num(), 1);

    Profile->bAllowPeak = false; // setor 1: sem pico, MaxPeakTime 0 é coerente
    TestEqual(TEXT("Sem pico, MaxPeakTime 0 é válido"), VGDirectorProfileRules::Validate(*Profile).Num(), 0);
    return true;
}

#endif
```

### Explicação das decisões

- **O perfil reproduz as constantes antigas por padrão.** A migração do Capítulo 42 não muda o comportamento de nada até alguém criar um perfil. É uma refatoração segura, verificável pelo teste ("o perfil padrão é válido") e pelo jogo.
- **`bAllowPeak` no perfil, e travas acima dele.** O setor 1 nunca entra em pico por conta própria, mas uma trava de roteiro ainda pode forçar qualquer fase. É a hierarquia certa: o design autoral (a zona, a cena) vence o sistêmico (o Diretor).
- **A zona é dona do *handle*** e o solta em três caminhos: saída, condição falsa, `EndPlay`. É o padrão de aquisição e liberação do Capítulo 49, aplicado a outro recurso.
- **A zona reage ao anúncio de fatos** (Capítulo 46). Sem isso, a trava do pátio só soltaria quando a jogadora saísse e voltasse, e a Presença demoraria a voltar ao jogo depois do encontro.
- **Só pawns de jogador** contam na sobreposição (`IsPlayerControlled`). Os vigias e a Presença passando pela zona não podem pedir travas.
- **A validação do perfil tem regra pura e teste**, porque são números que designers mudam no editor, e um perfil impossível (Relax que nunca termina) é um bug silencioso: a Presença simplesmente nunca aparece.

---

## Projeto Final — a IA do jogo

- [ ] Perfis `DA_Diretor_S1`, `_S2`, `_S3`, `_Final` com os números da seção 80.2; os GameModes dos níveis apontando para eles.
- [ ] 🔁 `UVGDirectorSubsystem` lendo o perfil; o teste verde.
- [ ] Zonas de trava: pátio dos vigias (`Relax`, `NÃO TEM S2.GuardsCleared`), perseguição (`Peak`, `TEM S3.WellSeen E NÃO TEM S3.ChaseSurvived`), sala final (`Relax`, sempre).
- [ ] A perseguição com as garantias da seção 80.4, cada uma verificada como a tabela indica.
- [ ] O encontro dos vigias com perfis de utilidade por arquétipo e munição contada.
- [ ] Telemetria de três playtests: mortes por setor ≤ 2; perseguição com 70–85% de sucesso na primeira tentativa; ninguém atravessa os setores 2 e 3 sem pelo menos um encontro com a Presença.
- [ ] Milestone 4 fechado.

---

## Decisões arquiteturais

1. **Progressão de ameaça por natureza**: cenografia (S1) → pessoas (S2) → sistema (S3) → quietude (final).
2. **Perfil de Diretor por setor** em Data Asset, com o perfil padrão igual às constantes antigas.
3. **Zonas de trava do Diretor com condição sobre fatos**, donas do próprio *handle*; o design autoral vence o sistêmico.
4. **Perseguição com garantias explícitas e verificadas**, e uma meta de sucesso com piso e teto.
5. **Vigias e Presença com ferramentas de defesa diferentes**, ensinando por mecânica que são ameaças distintas.
6. **Critério de pronto da IA medido por telemetria**, e não por impressão.

---

## Armadilhas

- **Um Diretor só para o jogo inteiro.** Ou o setor 2 fica cruel ou o setor 3 fica manso.
- **Ligar e desligar a Presença por script** em vez de mudar a frequência. As regras dela deixam de valer, e a jogadora sente a trapaça.
- **Trava sem dono**, ou solta só num caminho. A Presença fica presa em `Relax` depois do encontro, ou em `Peak` depois da perseguição.
- **Perseguição sem rota de fuga garantida.** A jogadora morre por geometria, não por erro.
- **Perseguição fácil demais.** Acima de 85% de sucesso, a ameaça vira cenário.
- **Surgimento à vista.** A Presença aparecendo do nada diante da jogadora destrói a lógica que a percepção construiu.
- **Medir a IA por "pareceu bom".** Sem telemetria, a primeira pessoa que testar (você) é a menos representativa.

---

## Exercício

**Parte 1 — perfis (1,5 h).** Implemente `UVGDirectorProfile`, a validação, o teste e a migração do Diretor. Confirme que, sem perfil, o comportamento do Capítulo 42 é o mesmo (`vg.Debug` do Diretor e o Gameplay Debugger mostram as mesmas fases nos mesmos tempos).

**Parte 2 — zonas (1,5 h).** Implemente `AVGDirectorLockZone` e coloque as três zonas. No pátio, derrube os vigias e confirme no painel que a trava solta **sem** sair da zona.

**Parte 3 — a perseguição (3 h).** Monte a perseguição com as garantias. Jogue-a dez vezes, metade correndo bem e metade errando o caminho de propósito, e registre os resultados.

**Parte 4 — playtest (2 h).** Três pessoas, com telemetria. Ajuste os perfis e a velocidade da Presença até a meta da seção 80.4 e o critério do Milestone 4.

---

## Desafio — o Diretor que aprende

Faça o perfil do setor 3 se ajustar à jogadora **dentro dos limites do design**: se ela morreu duas vezes na perseguição, a próxima tentativa tem a Presença a 88% da corrida em vez de 92%, com um piso de 85%. Responda no `DEVLOG.md`:

1. Isso é ajuste de dificuldade ou trapaça?
2. A jogadora deveria saber?
3. O ajuste deve persistir no save?

Compare com a regra "frequência, nunca regras": velocidade é frequência ou regra?

---

## Uso de IA

1. **Para revisar a justiça de um encontro:**
   > "Aqui está a descrição de uma perseguição num jogo de terror (espaço, velocidades, telegrafia, rota de fuga, checkpoint). Liste todas as formas de a jogadora morrer sem ter cometido um erro (geometria, surgimento à vista, ataque sem aviso, porta que não fecha a tempo) e, para cada uma, a garantia de design que a impediria. [descrição]"

2. **Para analisar a telemetria da IA:**
   > "Aqui está um CSV de telemetria de três playtests (abaixo). Calcule, por pessoa: mortes por setor, tempo entre S3.WellSeen e S3.ChaseSurvived, número de tentativas da perseguição, e o intervalo entre cada falha de luz e o dano seguinte. Mostre o código do cálculo. [CSV]"

3. **Para propor perfis:**
   > "Meu Diretor de terror tem estes parâmetros (abaixo) e quatro setores com estas intenções [intenções]. Proponha valores iniciais para cada setor, explique cada escolha em uma frase, e diga quais dois parâmetros eu deveria ajustar primeiro no playtest."

**Cuidado específico:** a IA tende a recomendar dificuldade adaptativa "inteligente" (aprendizado, modelos de jogador) porque é o assunto mais discutido sobre o tema. Para quinze minutos de jogo, um ajuste simples dentro de limites de design, como no desafio, é mais honesto e mais testável.

---

## Checklist

- [ ] Planejei os encontros do jogo inteiro com uma progressão de natureza da ameaça.
- [ ] O Diretor lê perfis por setor, e o perfil padrão reproduz o Capítulo 42.
- [ ] As zonas de trava pedem fases ao Diretor, soltam em todos os caminhos e reagem a fatos.
- [ ] A perseguição tem garantias verificadas e uma meta de sucesso com piso e teto.
- [ ] O encontro dos vigias ensina que eles são uma ameaça diferente da Presença.
- [ ] O Milestone 4 foi fechado com telemetria, não com impressão.

---

## Para ir além

- **GDC Vault** (gdcvault.com): a palestra de Michael Booth na GDC 2009 sobre o design cooperativo de *Left 4 Dead* e a de Alistair Hope, da Creative Assembly, sobre o medo em *Alien: Isolation* (GDC 2015) (confira os títulos lá). A apresentação *The AI Systems of Left 4 Dead* (Booth, 2009), já citada no Capítulo 42, tem os slides publicados pela Valve; as entrevistas de desenvolvedores de *Alien: Isolation* sobre a IA da criatura saíram na imprensa especializada.
- ***Game AI Pro*** (a série organizada por Steve Rabin): capítulos sobre diretores de ritmo, perseguição e IA justa.

---

➡️ **Próximo:** [Capítulo 81 — Narrative](cap-81-narrative.md)
