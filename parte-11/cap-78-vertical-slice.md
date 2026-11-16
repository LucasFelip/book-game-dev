# Capítulo 78 — Vertical Slice

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que é um ***vertical slice*** e como ele difere de protótipo, de *alpha* e de MVP;
- escolher a **fatia** certa: curta, representativa, com todos os pilares que importam;
- definir uma **barra de qualidade** por disciplina, verificável, e não "ficou bonito";
- conduzir a fatia por um **pipeline** de passes (arte, luz, áudio, VFX, UI, sensação), na ordem certa para uma pessoa só;
- **medir o custo** da qualidade final por minuto de jogo e usar o número para decidir o escopo do resto;
- instrumentar o jogo com **telemetria de playtest** e conduzir playtests que produzem dados, não opiniões.

---

## Contexto

A Introdução (seção 6.2) definiu o Projeto 7 assim: *os primeiros ~5 minutos da Vigília em qualidade final*. O Capítulo 76 explicou por que ele vem antes do resto do conteúdo: provar que a qualidade final é **alcançável** e medir quanto ela **custa**, antes de se comprometer com quinze minutos.

Até aqui, quase tudo na Vigília estava em *grey-box* ou em qualidade de sistema: funciona, mas é feito de cubos, luzes provisórias, sons de placeholder e legendas cruas. O setor 1 tem a história inteira, todos os sistemas e nenhuma beleza. O vertical slice é o momento de descobrir se a soma dos sistemas, quando vestida, produz a experiência que a página única promete, e quanto tempo de vida isso consome.

---

## 78.1 O que é um vertical slice

O nome vem de uma imagem. Se o jogo completo é um bolo em camadas (cada camada é uma disciplina: código, arte, luz, áudio, UI), um *vertical slice* é uma fatia que atravessa **todas** as camadas, de cima a baixo, numa parte **pequena** do jogo. O oposto, um *horizontal slice*, é uma camada inteira (todos os níveis em *grey-box*) sem as outras.

| Artefato | Extensão | Qualidade | Pergunta que responde |
|---|---|---|---|
| **Protótipo** (Interlúdio I) | Pequena | Baixa, descartável | "A ideia funciona jogada?" |
| ***Grey-box* completo** | O jogo inteiro | Baixa | "A estrutura e o ritmo funcionam?" |
| ***Vertical slice*** | Poucos minutos | **Final** | "A experiência prometida é alcançável? Quanto custa?" |
| ***Alpha*** | O jogo inteiro | Variável; tudo jogável | "Está tudo lá?" |
| ***Beta*** | O jogo inteiro | Quase final; só correção | "Está pronto?" |

> 🌉 **Ponte:** o MVP de produto é o paralelo mais citado, e é quase o oposto. O MVP é **mínimo em qualidade e máximo em alcance** útil: a menor coisa que entrega valor. O vertical slice é **máximo em qualidade e mínimo em extensão**: a menor coisa que prova o padrão de acabamento.
>
> 🧱 **Onde a ponte cai:** um MVP é lançado e iterado com usuários reais. Um vertical slice quase nunca é lançado como está: ele é uma **medida**. Seu valor está no que ele ensina sobre o custo do resto, e não em quem o joga.

---

## 78.2 Escolher a fatia

A fatia da Vigília vai do **começo do prólogo até o fim do susto do corredor**: o Pátio (cerca de 2 minutos) e o setor 1 até o beat 6 (cerca de 4 a 5 minutos), com o puzzle no meio. Ficam de fora a cinemática final do setor 1 e todo o resto do jogo.

Três critérios guiaram a escolha.

1. **Todos os pilares que dependem de acabamento.**
   - Luz: a lanterna, as luminárias e a linguagem de luz.
   - A usina como documento: o livro, o memorando e as vinhetas.
   - Vulnerabilidade: o corredor e o susto.
   - Momentos cinematográficos: o rádio e o susto como cena com controle.

   O pilar 5 (combate) **fica fora de propósito**. O encontro dos vigias depende do setor 2 inteiro, e a qualidade do combate já foi medida no Galpão (Parte IV). O registro de riscos anota a exclusão.
2. **O começo do jogo.** É a parte que todas as jogadoras veem, e a que decide se elas continuam. Polir o começo primeiro é um bom investimento mesmo que o resto do projeto fracasse.
3. **Conteúdo já validado.** O setor 1 passou por um protótipo (Interlúdio I), uma refatoração (Parte VI) e playtests. A fatia mede o custo do **acabamento**, sem misturar com o custo de descobrir o design.

---

## 78.3 A barra de qualidade

"Qualidade final" precisa ser escrita, ou vira um alvo que se move. A barra da Vigília, por disciplina:

| Disciplina | Barra (verificável) | Fonte |
|---|---|---|
| **Espaço e arte** | Nenhum cubo de *blockout* visível; props com escala e materiais coerentes com 1994; cada vinheta legível na luz de jogo | Caps. 48, 50 |
| **Luz** | A linguagem de luz respeitada em 100% das luminárias (âmbar = seguro, sempre com zona; frio = energia; destaque = atenção); caminho crítico sem preto absoluto; a calibração de brilho funciona | Cap. 51 |
| **Áudio** | Nenhum som de placeholder; ambiente em camadas por espaço; passos por material; a usina respira; o silêncio do susto existe; a voz de Sônia passa pela cadeia do rádio | Cap. 52 |
| **Animação** | Braços em primeira pessoa com a lanterna; nenhuma pose T; a silhueta do susto lê como "alguém" a 16 m | Cap. 53 |
| **VFX** | A poeira no feixe; o flicker com faíscas onde há falha elétrica; nenhum efeito sem função escrita | Cap. 54 |
| **UI** | Só o layout final (Cap. 55); legendas, prompt, aviso de objetivo, leitor e menu de pausa; legendas ligadas por padrão | Cap. 55 |
| **Sensação** | Movimento pelo perfil Vigília; interações com som e resposta em menos de 100 ms; portas com peso | Caps. 17–19, 25 |
| **Narrativa** | Texto final revisado; vozes temporárias gravadas por você (ou uma voz sintética **marcada como temporária**); legendas sincronizadas | Caps. 43–49 |
| **Performance** | ≤ 16,67 ms no pior momento da fatia na máquina-alvo (build Test) | Caps. 58–60 |
| **Estabilidade** | Zero bugs A (travamento, progresso impossível, perda de save) em 3 playtests seguidos | Cap. 61 |
| **Acessibilidade** | Legendas, "reduzir luzes piscando", movimento de câmera ajustável e brilho, todos funcionando na fatia | Cap. 55 |

A linha de narrativa tem uma decisão que vale explicitar: **vozes temporárias**. Uma pessoa sozinha raramente consegue atores para um vertical slice, e uma voz sintética pode servir para medir ritmo e sincronia. Ela precisa estar **marcada** no projeto (pasta `Audio/Voz/Temp/`, nome com sufixo `_TEMP`) e na lista de pendências do release. Uma voz temporária esquecida num build de lançamento é uma armadilha clássica de produção. A Parte X discutiu os limites éticos e de qualidade do uso de vozes geradas; a decisão final é sua, e vai no ADR correspondente.

---

## 78.4 O pipeline de uma pessoa

Num estúdio, os passes de arte, luz e áudio acontecem em paralelo, com pessoas diferentes. Sozinho, a ordem importa, porque cada passe muda o que o anterior parecia.

```text
 1. TRAVAR O BLOCKOUT         métricas, caminho, vinhetas no lugar (Cap. 50) — nada de mexer em parede depois
        ▼
 2. PASSE DE ARTE             kit modular final, materiais, props das vinhetas, decalques
        ▼
 3. PASSE DE LUZ              linguagem de luz, exposição, sombras só onde vistas (Cap. 51)
        ▼                     (luz DEPOIS da arte: materiais mudam a leitura da luz)
 4. PASSE DE ÁUDIO            camadas de ambiente, passos, a usina, o rádio, os silêncios (Cap. 52)
        ▼                     (áudio DEPOIS da luz: o som acompanha o que se vê)
 5. PASSE DE VFX              só o que tem função (Cap. 54)
        ▼
 6. PASSE DE UI E SENSAÇÃO    layout final, legendas, tempos de resposta
        ▼
 7. PLAYTEST + POLIMENTO      3 playtests com telemetria; correções; barra conferida
```

Cada passe tem um **limite de tempo** fixado antes de começar. Quando o limite acaba, o passe acaba, e o que ficou abaixo da barra entra na lista de polimento (Cap. 82). Sem limite, o primeiro passe come o orçamento de todos.

O passo 1 merece ênfase. Depois que a arte entra, mudar uma parede custa dez vezes mais: o kit modular, a luz assada (se houver), as vinhetas, a navegação, os checkpoints e os gatilhos se movem junto. **Travar o *blockout*** é uma decisão consciente, registrada no documento de nível, e só se volta atrás com um motivo de playtest.

---

## 78.5 Medir o custo

A pergunta que o vertical slice responde em números: **quantas horas custa um minuto de jogo em qualidade final?**

Registre as horas de cada passe (o `DEVLOG.md` já é um diário; acrescente uma coluna de horas) e divida pela duração da fatia, medida nos playtests (mediana):

```text
 custo por minuto = Σ horas dos passes / minutos de jogo da fatia
 custo do resto   = custo por minuto × minutos restantes × fator de novidade

 fator de novidade: 1,0 se o resto reaproveita o que a fatia criou (kit, materiais, sons);
                    1,3–1,6 se exige peças novas (o Salão das Turbinas, os vigias, a perseguição)
```

Um exemplo **[HIPOTÉTICO]**, para mostrar o raciocínio, e não como referência de quanto as coisas custam:

| Passe | Horas na fatia (6,5 min) |
|---|---|
| Arte | 38 |
| Luz | 14 |
| Áudio | 16 |
| VFX | 5 |
| UI e sensação | 9 |
| Playtests e correções | 12 |
| **Total** | **94 h ≈ 14,5 h por minuto** |

Com 8 minutos restantes e um fator de novidade de 1,4, o resto custaria cerca de **162 horas**. A 8,5 horas por semana, são umas **19 semanas**, contra as 8 que o cronograma do Capítulo 76 reserva para os Milestones 5–7. O número diz, sem drama, que o plano não cabe, e obriga uma decisão **agora**, não na semana 12:

- cortar conteúdo: uma sala e um documento do setor 2, uma vinheta por setor;
- baixar a barra **onde a jogadora menos nota**: arte de áreas de passagem, VFX;
- aumentar o reuso: o kit da Casa de Força serve à Subestação com outros materiais;
- ou estender o prazo, conscientemente, com uma nova data fixa.

O valor do vertical slice está aí: transformar "acho que dá" num número que se pode discutir.

---

## 78.6 Playtests que produzem dados

Os playtests do livro até aqui foram de observação: "onde a pessoa se perdeu?", "o susto funcionou?". Eles continuam valendo. A fatia acrescenta **dados**: o jogo registra o que aconteceu, e você compara o que viu com o que foi medido.

O barramento de eventos (Capítulo 24) já é, sem querer, uma telemetria completa: tudo o que importa passa por ele. Basta um ouvinte que grave.

### O que registrar

| Pergunta de design | Evento | Métrica |
|---|---|---|
| Quanto dura cada beat? | `Event.Quest.StageEntered` | Tempo entre etapas |
| As jogadoras leem? | `Event.Document.Opened` / `Read` | Taxa de leitura por documento; abertos × lidos |
| O rádio atrapalha? | `Event.Dialogue.Started` / `Finished` | Falas por minuto; falas expiradas (Cap. 44) |
| O puzzle é justo? | `Event.Puzzle.Failed` / `Solved` | Tentativas até resolver |
| Onde morrem? | `Event.Player.Died` | Mortes por setor e por local (`Event.Trigger.Entered` mais próximo) |
| O Diretor respira? | (amostra periódica) | Tempo em cada fase |

E, igualmente importante, **o que não registrar**: nada de dado pessoal, nada que identifique quem jogou, e nada fora do computador de quem joga sem consentimento explícito. Para playtests com amigos, um arquivo CSV local que a pessoa envia se quiser é suficiente, e é o mais honesto.

### O protocolo

1. **Não explique nada.** Dê o controle e observe (Interlúdio I).
2. **Anote o que vê** numa folha com o tempo: "02:10 parou diante do mapa do Pátio por 20 s".
3. **Depois, três perguntas abertas.** O que você acha que aconteceu nessa usina? Quando você teve mais medo? Teve algum momento em que não sabia o que fazer?
4. **Cruze as notas com a telemetria.** As notas dizem **por quê**, e a telemetria diz **quanto** e **quando**.
5. **Três playtests**, pelo menos, antes de qualquer conclusão. Um playtest é uma anedota.

---

## Estudo de caso: a demonstração como fatia

**[INFERÊNCIA]** Demonstrações jogáveis de jogos em desenvolvimento, mostradas em feiras ou a editoras, costumam ser *vertical slices*: um trecho curto em qualidade próxima da final, escolhido para representar o jogo. A literatura pública de produção (postmortems e palestras de GDC) menciona com frequência o lado ruim dessa prática: o trecho da demonstração recebe um polimento desproporcional, que o resto do jogo não consegue acompanhar no prazo, e cria uma expectativa que o produto final não cumpre.

**Lição para a Vigília:** a fatia é uma **medida**, não uma vitrine. O teste de honestidade é o número da seção 78.5: se a qualidade da fatia não for sustentável no resto do jogo, a barra é que precisa mudar, não o prazo em silêncio. Uma barra que só a fatia alcança é uma mentira para você mesmo.

---

## Comparação com o desenvolvimento tradicional

| Vertical slice | O que você conhece | Onde a analogia cai |
|---|---|---|
| A fatia em qualidade final | *Spike* de arquitetura + piloto de produto | O que se mede é **custo de conteúdo**, não viabilidade técnica |
| Barra de qualidade escrita | *Definition of done* | Inclui critérios estéticos verificados por pessoas |
| Custo por minuto de jogo | *Velocity*, estimativa por histórico | O "fator de novidade" pesa mais que em software, porque conteúdo novo exige peças novas |
| Telemetria pelo barramento | Eventos de produto, *analytics* | Amostras minúsculas (3–10 pessoas); serve a perguntas, não a estatísticas |
| Travar o *blockout* | Congelar a interface antes de integrar | Mudar depois custa várias disciplinas, não só código |

---

## Unreal Engine: o que ajuda no acabamento

- **Kits modulares** e **instâncias de material** (`MI_*`) para variar o mesmo kit entre setores.
- **Fab** (o *marketplace* da Epic) e bibliotecas de *assets* para props e texturas. ⚠️ Leia a licença de cada *asset* e registre-a: o Capítulo 84 tem uma lista de licenças no checklist de release.
- **Level Instances** para as vinhetas (Cap. 48) e o **Asset Audit** / **Reference Viewer** para achar *assets* de *blockout* que sobraram.
- **Test build** com `-ExecCmds` para medir a performance da fatia como a jogadora a veria (Caps. 59 e 83).

---

## Abordagens: como chegar à qualidade final

| Critério | A. Horizontal primeiro (todo o jogo em *grey-box*, depois a arte inteira) | B. Vertical primeiro (fatia final, depois o resto) | **C. *Grey-box* completo + fatia** |
|---|---|---|---|
| **Descobre problemas de estrutura cedo** | Sim | Não: o resto ainda não existe | Sim |
| **Mede o custo de acabamento cedo** | Não: só no fim | Sim | Sim |
| **Risco de polir o que será cortado** | Baixo | Alto | Baixo, se a fatia for o começo validado |
| **Adequação à Vigília** | Mede tarde demais | Os setores 2 e 3 sem estrutura | **Sim** |

**Decisão: C.** Os setores 2 e 3 estão em *blockout* (Cap. 50), e a fatia é o começo já validado pelo protótipo e pela refatoração.

---

## Implementação: telemetria de playtest

```cpp
// Source/Vigilia/Debug/VGTelemetrySubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGTelemetrySubsystem.generated.h"

struct FVGGameplayEvent;

/** Uma linha de telemetria, pronta para virar CSV. */
struct FVGTelemetryRow
{
    double Seconds = 0.0;   // relógio REAL da sessão: queremos o tempo da pessoa, não o do jogo
    FString Map;
    FString Channel;
    FString Context;
    FString Target;
};

namespace VGTelemetry
{
    /** Cabeçalho e linha CSV (RFC 4180: aspas dobradas, campo entre aspas se tiver vírgula/aspas/quebra). */
    FString Header();
    FString ToCsvLine(const FVGTelemetryRow& Row);
}

/**
 * Grava os eventos do barramento num CSV por nível carregado (Saved/Telemetry/<data-hora>.csv), para playtests.
 * Só fora do Shipping; desligado por padrão (vg.Telemetry.Enabled). Nenhum dado pessoal.
 */
UCLASS()
class VIGILIA_API UVGTelemetrySubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void OnWorldBeginPlay(UWorld& InWorld) override;
    virtual void Deinitialize() override;

private:
    void HandleEvent(const FVGGameplayEvent& Event);
    void Flush();

    TArray<FString> Pending;
    FString FilePath;
    double StartSeconds = 0.0;
    FDelegateHandle EventHandle;
    FTimerHandle FlushTimer;
};
```

```cpp
// Source/Vigilia/Debug/VGTelemetrySubsystem.cpp
#include "Debug/VGTelemetrySubsystem.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Engine/World.h"
#include "GameFramework/Actor.h"
#include "HAL/FileManager.h"
#include "HAL/IConsoleManager.h"
#include "Misc/DateTime.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "TimerManager.h"

static TAutoConsoleVariable<bool> CVarVGTelemetryEnabled(
    TEXT("vg.Telemetry.Enabled"),
    false,
    TEXT("Grava os eventos do barramento em Saved/Telemetry/<data-hora>.csv, um por nível (playtests). Fora do Shipping."),
    ECVF_Default);

namespace
{
    FString Escape(const FString& Field)
    {
        const bool bNeedsQuotes = Field.Contains(TEXT(",")) || Field.Contains(TEXT("\""))
                               || Field.Contains(TEXT("\n")) || Field.Contains(TEXT("\r"));
        if (!bNeedsQuotes)
        {
            return Field;
        }
        return TEXT("\"") + Field.Replace(TEXT("\""), TEXT("\"\"")) + TEXT("\"");
    }
}

FString VGTelemetry::Header()
{
    return TEXT("seconds,map,channel,context,target");
}

FString VGTelemetry::ToCsvLine(const FVGTelemetryRow& Row)
{
    return FString::Printf(TEXT("%.2f,%s,%s,%s,%s"), Row.Seconds, *Escape(Row.Map), *Escape(Row.Channel),
                           *Escape(Row.Context), *Escape(Row.Target));
}

void UVGTelemetrySubsystem::OnWorldBeginPlay(UWorld& InWorld)
{
    Super::OnWorldBeginPlay(InWorld);
#if !UE_BUILD_SHIPPING
    if (!CVarVGTelemetryEnabled.GetValueOnGameThread())
    {
        return;
    }
    StartSeconds = InWorld.GetRealTimeSeconds();
    FilePath = FPaths::ProjectSavedDir() / TEXT("Telemetry") /
               (FDateTime::Now().ToString(TEXT("%Y%m%d-%H%M%S")) + TEXT(".csv"));
    Pending.Add(VGTelemetry::Header());

    if (UVGGameplayEventSubsystem* Bus = InWorld.GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Bus->OnEventNative.AddUObject(this, &UVGTelemetrySubsystem::HandleEvent);
    }
    // Grava em lotes a cada 5 s: nada de E/S de disco a cada evento.
    InWorld.GetTimerManager().SetTimer(FlushTimer, FTimerDelegate::CreateUObject(this, &UVGTelemetrySubsystem::Flush),
                                       5.0f, true);
#endif
}

void UVGTelemetrySubsystem::HandleEvent(const FVGGameplayEvent& Event)
{
    FVGTelemetryRow Row;
    Row.Seconds = GetWorld()->GetRealTimeSeconds() - StartSeconds;
    Row.Map = GetWorld()->GetMapName();
    Row.Channel = Event.Channel.ToString();
    Row.Context = Event.Context.ToString();
    Row.Target = Event.Target ? Event.Target->GetName() : FString();
    Pending.Add(VGTelemetry::ToCsvLine(Row));
}

void UVGTelemetrySubsystem::Flush()
{
    if (Pending.IsEmpty() || FilePath.IsEmpty())
    {
        return;
    }
    FFileHelper::SaveStringArrayToFile(Pending, *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM,
                                       &IFileManager::Get(), FILEWRITE_Append);
    Pending.Reset();
}

void UVGTelemetrySubsystem::Deinitialize()
{
    Flush(); // o que sobrou ao trocar de nível ou fechar o jogo
    if (UVGGameplayEventSubsystem* Bus = GetWorld() ? GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>() : nullptr)
    {
        Bus->OnEventNative.Remove(EventHandle);
    }
    Super::Deinitialize();
}
```

```cpp
// Source/Vigilia/Tests/VGTelemetryTest.cpp
#include "Misc/AutomationTest.h"
#include "Debug/VGTelemetrySubsystem.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGTelemetryTest, "Vigilia.Debug.Telemetry.CsvEscaping",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGTelemetryTest::RunTest(const FString& Parameters)
{
    FVGTelemetryRow Row;
    Row.Seconds = 12.5;
    Row.Map = TEXT("L_CasaDeForca");
    Row.Channel = TEXT("Event.Document.Read");
    Row.Context = TEXT("Document.S1.Memo");
    TestEqual(TEXT("Linha simples"), VGTelemetry::ToCsvLine(Row),
              FString(TEXT("12.50,L_CasaDeForca,Event.Document.Read,Document.S1.Memo,")));

    Row.Target = TEXT("BP_Livro, \"o\" do vestiário");
    TestEqual(TEXT("Vírgula e aspas escapadas"), VGTelemetry::ToCsvLine(Row),
              FString(TEXT("12.50,L_CasaDeForca,Event.Document.Read,Document.S1.Memo,\"BP_Livro, \"\"o\"\" do vestiário\"")));
    return true;
}

#endif
```

### Explicação das decisões

- **O barramento já é a telemetria.** Nenhum sistema precisou ser alterado para ser medido. O custo de instrumentar o jogo inteiro foi um ouvinte.
- **Relógio real**, declarado na estrutura. A pergunta é "quanto tempo a **pessoa** levou", e o tempo de jogo, dilatado e pausado, responderia outra coisa.
- **Gravação em lote** a cada 5 segundos e no `Deinitialize`. Escrever no disco a cada evento num jogo que mede o próprio frame (Cap. 58) seria sabotar a medição.
- **CSV com escape** segundo a convenção comum (RFC 4180), porque nomes de atores e contextos podem ter vírgulas, e um CSV quebrado só é descoberto na hora da análise. O teste fixa o escape.
- **Desligado por padrão e ausente no Shipping** (`#if !UE_BUILD_SHIPPING`). Telemetria de playtest é ferramenta de desenvolvimento, não funcionalidade do jogo.
- **Sem dado pessoal.** Nomes de atores, tags e tempos; nada sobre quem jogou. A análise (duração por beat, mortes por setor, taxa de leitura) é feita com um script fora do jogo, no Capítulo 82.

---

## Projeto 7 — o vertical slice da Vigília

**Escopo:** do início do prólogo ao fim do susto do corredor (Pátio + setor 1, beats 1–7 e 6).

- [ ] Blockout travado (Pátio e Casa de Força), com a data no documento de nível.
- [ ] Passes 2–6 com limite de tempo fixado e horas registradas no `DEVLOG.md`.
- [ ] A barra de qualidade da seção 78.3 conferida item por item (uma tabela com ✓/✗ e nota).
- [ ] `UVGTelemetrySubsystem` no projeto, e três playtests com protocolo e CSV.
- [ ] O cálculo da seção 78.5 com os **seus** números e a decisão de escopo resultante: cortes, reuso, barra ajustada ou prazo novo, registrada no registro de riscos e, se mudar um pilar, num ADR.
- [ ] Milestone 2 (Player) fechado: playtest de 5 minutos no Pátio sem que ninguém comente os controles.

---

## Decisões arquiteturais (de produção)

1. **A fatia vai do início do prólogo ao fim do susto do corredor**: o começo validado, com todos os pilares que dependem de acabamento; o combate fica fora, declarado.
2. **Barra de qualidade escrita e verificável**, por disciplina.
3. **Pipeline em passes ordenados** (arte → luz → áudio → VFX → UI), com o blockout travado antes e um limite de tempo por passe.
4. **Custo por minuto medido** e usado para decidir o escopo **agora**.
5. **Telemetria pelo barramento**, desligada por padrão, ausente no Shipping, sem dado pessoal.
6. **Vozes temporárias marcadas** como temporárias, com pendência no release.

---

## Armadilhas

- **A fatia que vira vitrine**: polida além do que o resto do jogo consegue acompanhar.
- **Mexer no blockout depois da arte.** Cada parede movida arrasta luz, navegação, gatilhos e vinhetas.
- **Passe sem limite de tempo.** A arte come o orçamento da luz, e a luz o do áudio.
- **Luz antes da arte.** Os materiais mudam a leitura da luz, e o passe precisa ser refeito.
- **Concluir com um playtest.** Uma pessoa é uma anedota.
- **Telemetria que mede o que é fácil**, não o que responde a uma pergunta de design.
- **Dado pessoal em telemetria de amigos.** Desnecessário e desonesto.
- **Voz temporária no build de lançamento.**
- **Ignorar o número do custo** porque ele é desagradável.

---

## Exercício

**Parte 1 — a barra (1 h).** Escreva a barra de qualidade para o **seu** jogo, a partir da tabela da seção 78.3, com um critério verificável por linha.

**Parte 2 — telemetria (1,5 h).** Implemente `UVGTelemetrySubsystem` e o teste. Jogue a fatia com `vg.Telemetry.Enabled 1` e abra o CSV numa planilha: quanto tempo você levou em cada etapa da quest?

**Parte 3 — os passes (o resto do tempo do Milestone).** Conduza a fatia pelos passes, com limites e horas registradas.

**Parte 4 — a decisão (1 h).** Faça o cálculo da seção 78.5 com os seus números. Escreva a decisão de escopo resultante e atualize o cronograma do Capítulo 76.

---

## Desafio — o mapa de calor das mortes

Acrescente à telemetria uma amostra da posição da jogadora a cada 2 segundos (`Event`-less: um timer do próprio subsistema, com uma linha `sample` no CSV). Num script fora do jogo, desenhe as posições e as mortes por cima da planta do nível (a imagem do blockout do Capítulo 50). Onde as jogadoras param? Onde morrem? A curva do corredor funciona como o Capítulo 50 previu (linha de visão de 8 m antes da virada)?

---

## Uso de IA

1. **Para escrever a barra de qualidade:**
   > "Atue como diretor de arte e áudio de um jogo independente de terror em primeira pessoa. Para cada disciplina (arte, luz, áudio, animação, VFX, UI, sensação), proponha três critérios **verificáveis** de 'qualidade final' para um vertical slice de 6 minutos feito por uma pessoa só, evitando critérios subjetivos como 'bonito' ou 'imersivo'."

2. **Para analisar a telemetria:**
   > "Aqui está um CSV de telemetria de playtest (segundos, mapa, canal, contexto, alvo) de três sessões. Calcule a duração de cada etapa de quest por sessão, a taxa de leitura dos documentos (aberto × lido) e o número de falhas do puzzle. Mostre o código que você usou para calcular, e não só o resultado. [CSV]"

3. **Para revisar o plano depois da fatia:**
   > "Meu vertical slice de 6,5 minutos custou X horas (por passe, abaixo). O resto do jogo tem 8 minutos com estas peças novas [lista]. Tenho N semanas de 8,5 horas. Proponha três planos (cortar, reusar, ajustar a barra), com o custo estimado e o que cada um sacrifica, sem mudar os pilares [pilares]."

**Cuidado específico:** a IA calcula mal de cabeça, e números de produção são exatamente o tipo de conta em que um erro passa despercebido. Peça sempre o **código** do cálculo (o pedido 2 faz isso) e rode-o você mesmo.

---

## Checklist

- [ ] Sei a diferença entre protótipo, *grey-box*, *vertical slice*, *alpha* e *beta*.
- [ ] Escolhi a fatia com critérios: começo, pilares, conteúdo validado.
- [ ] Tenho uma barra de qualidade verificável, por disciplina.
- [ ] Conduzi os passes na ordem, com o blockout travado e limites de tempo.
- [ ] Medi o custo por minuto e tomei uma decisão de escopo com ele.
- [ ] A telemetria funciona e os playtests seguem um protocolo.

---

## Para ir além

- **GDC Vault** (gdcvault.com): palestras de produção sobre *vertical slices*, *greyboxing* e pipelines de nível em estúdios pequenos (confira os títulos lá), e postmortems que discutem o custo de demonstrações.
- **Jesse Schell, *The Art of Game Design*** — os capítulos sobre playtest.
- **RFC 4180** (*Common Format and MIME Type for Comma-Separated Values (CSV) Files*, 2005): a convenção de CSV que o escape segue.

---

➡️ **Próximo:** [Capítulo 79 — Implementação](cap-79-implementacao.md)
