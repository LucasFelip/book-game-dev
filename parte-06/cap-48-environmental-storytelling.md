# Capítulo 48 — Environmental Storytelling

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar a **narrativa ambiental**: como um espaço conta uma história sem ninguém falar, por vinhetas, rastros, documentos, áudio e arquitetura;
- aplicar os princípios de **implicar em vez de explicar**, coerência ("por que isto está aqui?") e ritmo de descoberta;
- escrever **documentos** para jogos: curtos, com voz, com propósito no livro-razão de mistério;
- modelar documentos como **dados** e distinguir **"pegou"** de **"leu"**, registrando a leitura real como fato;
- implementar o **leitor de documentos** (modo `Reading`) e um **arquivo** consultável;
- montar **vinhetas reutilizáveis** e condicionadas ao estado narrativo;
- migrar os documentos do *Turno da Noite* e fechar o prenúncio pedido no desafio do Capítulo 43.

---

## Contexto

O Capítulo 43 decidiu a mistura de canais da Vigília: **os fatos chegam por documentos e pelo ambiente**, porque a jogadora os procura. É o canal de maior agência (Capítulo 43, seção 43.8): ela decide o que ler, onde olhar e o que conectar.

No Interlúdio I, documentos eram um `BP_PickupDocumento` com um texto, e "ler" era sinônimo de "pegar": o Level Blueprint marcava `bLeuMemorando` no momento do pickup. O Capítulo 46 manteve esse atalho numa regra (pegar o memorando concede `Document.Memo.Read`) e avisou: este capítulo troca isso por **leitura de fato**. A diferença importa. Uma jogadora que pega o memorando e fecha a tela na hora **não leu** o memorando, e Sônia não deveria agir como se ela tivesse lido.

E o ambiente, até aqui, foi cenário: portas, disjuntores, luzes. Este capítulo trata o espaço como **texto**.

---

## 48.1 O espaço conta

Narrativa ambiental é a história que a jogadora **lê no espaço**. Ela tem formas diferentes, com custos e efeitos diferentes:

| Forma | Exemplo na Vigília | O que comunica |
|---|---|---|
| **Vinheta** | Uma cena congelada: a mesa do engenheiro com a caneca, o rádio esquecido, a cadeira afastada às pressas | "O que aconteceu aqui" |
| **Rastro** | Marcas de mão na poeira dos disjuntores; uma lanterna caída no fim do corredor | "Alguém passou por aqui", e quando |
| **Documento** | O livro de ocorrências, o memorando, o bilhete do armário | Fatos, vozes, contradições |
| **Áudio** | Uma fita do turno de 1994; a usina que "respira" | Presença, emoção, prenúncio |
| **Arquitetura** | O corredor longo com uma curva; a janela da sala de controle para o salão das turbinas | Expectativa, poder, isolamento |
| **Mudança de estado** | O mesmo hall antes e depois da energia voltar | Consequência, passagem do tempo |

Quatro princípios atravessam todas as formas.

1. **Implicar, não explicar.** A melhor narrativa ambiental deixa a conclusão para a jogadora. Uma cadeira caída, uma xícara pela metade e um casaco no encosto dizem "saíram às pressas" melhor que um bilhete escrito "saímos às pressas". É a agência de interpretação (Capítulo 43): quem conecta as peças **sente** a história, porque a construiu.
2. **Coerência.** Todo objeto narrativo precisa responder a "por que isto está aqui?". O bilhete do armário diz que Moraes esquece o rádio na mesa, então **o rádio está na mesa**. O mundo confirma o documento, e a confirmação é uma recompensa pequena e poderosa. Um documento que contradiz o espaço sem intenção é uma quebra de confiança.
3. **Ritmo.** Descobertas precisam de respiro. Três documentos na mesma sala viram uma pilha de leitura; um documento por espaço, com o espaço reforçando o documento, vira uma sequência.
4. **Legibilidade.** Num jogo escuro, a narrativa ambiental só existe se for **vista** e **ouvida**. A luz (Capítulo 51) e o som (Capítulo 52) guiam o olhar para o que importa, sem setas e sem marcadores.

> 🌉 **Ponte:** a narrativa ambiental é **documentação implícita** de um sistema: em vez de ler o manual, você entende o que aconteceu olhando os logs, o estado dos dados, o histórico de *commits*. Um bom espaço é um bom *postmortem* sem texto.
>
> 🧱 **Onde a ponte cai:** em engenharia, ambiguidade é defeito, e a documentação deve eliminá-la. Na narrativa ambiental de terror, a ambiguidade é **material**: a jogadora deve ficar com perguntas (o livro-razão de mistério, Capítulo 43). Explicar demais é o defeito.

---

## 48.2 Escrever documentos para jogos

Um documento num jogo de terror é lido **em pé, no escuro, com uma ameaça por perto**. Isso muda tudo o que se sabe sobre escrever textos.

- **Curto.** O livro de ocorrências do Interlúdio tem cerca de 120 palavras e é o documento mais longo da Casa de Força. Se um documento precisa de mais, divida-o em páginas, cada uma com uma ideia.
- **Com voz.** Cada autor escreve como ele mesmo. O operador do turno escreve com horários e abreviações; o engenheiro, com formalidade e medo contido; o colega do armário, com intimidade e pressa. A voz é metade da informação.
- **Com propósito no livro-razão.** Todo documento abre, responde ou complica uma pergunta do mistério (Capítulo 43, seção 43.7). Um documento que não mexe no livro-razão é decoração e pode ser cortado.
- **Com um objeto físico.** Papel timbrado, letra à mão, folha arrancada, carimbo de "confidencial". A forma diz quem escreveu e com que urgência antes da primeira palavra.
- **Mostrando, não contando.** "Ouvimos a turbina 3. Ela não pode estar girando." é melhor que "Algo sobrenatural fez a turbina girar."

E uma regra de sistema: **o mundo não para enquanto ela lê.** Na Vigília, ler não pausa o jogo, e a vulnerabilidade de quem lê é parte do medo. Mas três sistemas já cooperam com a leitura:

- o Diretor não inicia um pico (Capítulo 42);
- o rádio não começa falas não críticas (Capítulo 44);
- o modo `Reading` consome as teclas de movimento (Capítulo 16).

---

## 48.3 "Pegou" não é "leu"

Há três momentos diferentes na vida de um documento, e cada um merece um sinal próprio:

| Momento | O que significa | Sinal na Vigília |
|---|---|---|
| **Abriu** | A jogadora começou a ler | `Event.Document.Opened` (com o documento como contexto) |
| **Leu** | Passou tempo suficiente, ou chegou à última página | `Event.Document.Read` e o **fato de leitura** do documento |
| **Arquivou** | O documento foi para o diário, para reler depois | Implícito: lido = arquivado |

"Leu" é uma **heurística**, e precisa ser declarada como tal. A Vigília usa a mais simples que resiste ao uso real: o documento conta como lido se a jogadora **chegou à última página** ou se ficou com ele aberto por **pelo menos metade do tempo estimado de leitura**. O tempo estimado vem do tamanho do texto, numa velocidade de leitura confortável (cerca de 20 caracteres por segundo para texto corrido, mais rápido que a legenda do Capítulo 44 porque a jogadora controla o ritmo). Quem só abre e fecha não leu, e quem lê rápido mas chega ao fim leu.

> 🌉 **Ponte:** é a diferença entre "*e-mail* entregue", "aberto" e "lido de fato" numa ferramenta de marketing, ou entre "página carregada" e "conteúdo consumido" numa métrica de produto.
>
> 🧱 **Onde a ponte cai:** no produto, a métrica é estatística, e um erro individual não importa. Aqui, cada erro é uma fala de Sônia que pressupõe algo que a jogadora não sabe. Por isso a heurística é **conservadora**: na dúvida, considere que **não** leu. Uma fala condicionada a "leu" é a que mais quebra a ilusão quando está errada.

---

## 48.4 O arquivo

Documentos lidos precisam ser **relidos**. A jogadora encontra o livro de ocorrências no vestiário e só no subsolo, diante dos disjuntores, percebe que a ordem certa está nele. Sem um arquivo, ela teria de voltar ao vestiário, ou anotar num papel de verdade (o que, num jogo de investigação, pode até ser uma experiência desejada, mas é uma decisão de design, não um acidente).

O arquivo da Vigília é mínimo:

- **Lista os documentos lidos**, na ordem em que foram encontrados no mundo (setor, depois a ordem definida no dado).
- **Abre no mesmo leitor**, no modo `Reading`.
- **Não tem marcadores nem resumos**: a jogadora relê o original. Resumos automáticos ("objetivo: religue os disjuntores na ordem A-E-S") tirariam dela o trabalho de conectar, que é a investigação.

O arquivo não precisa de estado próprio. "Documentos lidos" é deduzível do estado narrativo: cada documento declara o seu fato de leitura, e o arquivo lista os documentos cujo fato existe. Um conjunto a menos para salvar.

---

## 48.5 Vinhetas como peças

Uma vinheta é um conjunto de objetos, luz e som que forma uma cena congelada. Ela é montada uma vez, ajustada muitas vezes, e às vezes reaproveitada (em versões diferentes). Duas técnicas mantêm vinhetas sob controle.

1. **Vinheta como peça montada.** A Unreal tem formas de agrupar atores num nível reutilizável: ***Level Instances*** e ***Packed Level Actors*** (⚠️ confira as diferenças e as limitações na sua versão). A vinheta "mesa do engenheiro" vira uma peça com props, *decals*, uma luz de destaque fraca e um emissor de som, colocada e girada como um ator só.
2. **Vinheta condicionada ao estado.** O `UVGFactGateComponent` (Capítulo 47) liga e desliga a vinheta, ou uma variante dela, conforme fatos. A mesma sala pode ter a vinheta "antes" e a "depois", cada uma visível num estado da história.

E uma disciplina de autoria: cada vinheta tem uma **frase de intenção** no documento de nível (Capítulo 50), como "aqui, a jogadora deve entender que o engenheiro saiu às pressas e que tinha medo". A frase decide o que entra na vinheta e o que sobra. Sem ela, vinhetas acumulam objetos até não dizerem nada.

---

## Estudos de caso

### Control — o prédio como documento

**[FATO PÚBLICO]** Em *Control* (Remedy, 2019), a protagonista explora a Oldest House, sede do Federal Bureau of Control, e encontra muitos documentos internos colecionáveis (relatórios, memorandos, correspondência), vários deles com trechos **censurados** por tarjas pretas. Gravações e vídeos complementam os textos, e tudo fica reunido num menu para consulta.

**[INFERÊNCIA]** Os documentos fazem duas coisas ao mesmo tempo. Constroem o mundo, com a burocracia de uma agência que lida com o sobrenatural, e escondem informação, com as tarjas tornando visível o que **não** se pode saber. A censura transforma a lacuna do mistério num objeto concreto: a jogadora **vê** o que lhe foi negado. O tom burocrático, seco e administrativo, contrasta com o conteúdo absurdo, e é desse contraste que nasce boa parte do estranhamento.

**Lição para a Vigília:** os documentos institucionais da usina (memorandos, ordens de serviço, relatórios de vibração) podem usar o mesmo contraste: linguagem técnica e fria descrevendo o inexplicável. O memorando de Moraes já faz isso ("relatos que prefiro não pôr no papel"). E uma tarja, num relatório de 1994, é uma pergunta do livro-razão em forma de objeto.

### Amnesia: A Machine for Pigs — o ambiente como revelação

**[FATO PÚBLICO]** *Amnesia: A Machine for Pigs* (The Chinese Room, publicado pela Frictional Games, 2013) se passa na Londres de 1899. O protagonista, o industrial Oswald Mandus, desce por sua própria casa e por uma imensa máquina construída sob a cidade, reconstruindo aos poucos o que fez.

**[INFERÊNCIA]** A revelação vem do **espaço**. À medida que desce, a jogadora entende a escala e a função da máquina pelos lugares que atravessa, e a arquitetura industrial é a própria história. O terror vem menos do que persegue e mais do que se **compreende** sobre o lugar e sobre quem o construiu. Documentos e vozes acompanham, mas é a máquina, vista por dentro, que conta.

**Lição para a Vigília:** a usina de Serra Funda pode ser, ela mesma, o documento principal. O salão das turbinas, visto pela janela no fim do setor 1 e atravessado no setor 3, deve revelar pela arquitetura e pelo estado (o que foi religado, o que está girando) o que os papéis só sugerem.

### Outlast — o registro do próprio protagonista

**[FATO PÚBLICO]** Em *Outlast* (Red Barrels, 2013), o jornalista Miles Upshur registra o que vê com uma câmera e, em certos momentos, escreve anotações num caderno, que o jogador pode ler.

**[INFERÊNCIA]** As anotações são narrativa ambiental **filtrada pelo protagonista**: o registro do que o jogador acabou de viver, na voz de alguém assustado. Elas resumem sem explicar demais e dão ao jogador um espelho da própria experiência.

**Lição para a Vigília:** Helena quase não fala (Capítulo 43). Um caderno de perita com anotações curtas depois de momentos-chave seria a única voz interior dela. É uma decisão de tom em aberto, e o desafio deste capítulo a explora.

---

## Comparação com o desenvolvimento tradicional

| Narrativa ambiental | O que você conhece | Onde a analogia cai |
|---|---|---|
| O espaço conta | Entender um sistema pelos logs e pelo estado | A ambiguidade é material, não defeito |
| Pegou × leu | Entregue × aberto × consumido | Cada erro é visível na fala de um personagem; a heurística é conservadora |
| Arquivo deduzido de fatos | Visão derivada, sem armazenamento próprio | — (a analogia vale) |
| Vinheta como peça | Componente reutilizável de UI | Cada uso costuma ser **variado** à mão; reuso literal é perceptível |
| Documento com voz | Texto de produto com *tone of voice* | A voz é do personagem, não da marca, e muda por autor |

---

## Unreal Engine: o que existe

- **Interação** (Capítulo 19): `IVGInteractable` (`CanInteract`, `Interact`, `GetInteractionPrompt`, chamados por `Execute_`).
- **Modo de leitura** (Capítulo 16): `EVGInputMode::Reading` na pilha do `AVGPlayerController`, com `IMC_Leitura`.
- **UMG** para o leitor: `URichTextBlock` aceita marcação simples (estilos por tag) com uma tabela de estilos, útil para letra à mão, carimbos e tarjas de censura (⚠️ confira a configuração da *Text Style Set* na sua versão). O Capítulo 55 formaliza a UI.
- **Asset Manager** (*primary assets*): lista todos os documentos do projeto sem que nenhum nível precise referenciá-los, o que serve para o arquivo. É preciso registrar o tipo em *Project Settings → Asset Manager → Primary Asset Types to Scan*.
- ***Level Instances* e *Packed Level Actors*** para vinhetas reutilizáveis.

---

## Abordagens: onde mora o texto do documento

| Critério | A. No ator do nível (Interlúdio I) | **B. Em Data Asset (`UVGDocumentData`)** | C. Num sistema externo (Ink, planilha importada) |
|---|---|---|---|
| **Localização** | Possível, mas espalhada por níveis | `FText` nos assets, coletáveis; *String Tables* opcionais | Depende do importador |
| **Reuso** (o mesmo documento em dois lugares, no arquivo) | Não | Sim | Sim |
| **Revisão por quem escreve** | Abrindo cada nível | Abrindo assets, ou pela *String Table* (Cap. 44) | Na ferramenta externa |
| **Validação** | Nenhuma | `IsDataValid` | Na importação |
| **Adequação à Vigília** | Foi a dor | **Sim** | Excesso para dezenas de documentos |

**Decisão: B**, com o mesmo pipeline de texto do diálogo: `FText` nos assets, *String Table* quando houver revisão externa.

---

## Implementação

### 1. Tags e o documento

```cpp
// VGGameplayTags.h (adições)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Document_Opened);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Document_Read);

// VGGameplayTags.cpp (adições)
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Document_Opened, "Event.Document.Opened");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Document_Read,   "Event.Document.Read");
```

Tags de conteúdo: `Document.*` identifica documentos (`Document.S1.Logbook`), e os fatos de leitura seguem o catálogo (`Narrative.Fact.Document.Logbook.Read`).

```cpp
// Source/Vigilia/Narrative/VGDocumentData.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "GameplayTagContainer.h"
#include "VGDocumentData.generated.h"

class USoundBase;

/** Um documento: o QUE está escrito e o que ler significa para a história. */
UCLASS(BlueprintType)
class VIGILIA_API UVGDocumentData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    /** Identidade (contexto de Event.Document.*). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Document", meta = (Categories = "Document"))
    FGameplayTag DocumentTag;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Document")
    FText Title;

    /** Uma página = uma ideia. Marcação de estilo do RichText permitida (Cap. 55). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Document", meta = (MultiLine = "true"))
    TArray<FText> Pages;

    /** Concedido quando a leitura conta (seção 48.3). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Document", meta = (Categories = "Narrative.Fact"))
    FGameplayTag ReadFact;

    /** Estilo visual do papel no leitor (ex.: Paper.Logbook, Paper.Memo, Paper.Handwritten). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Document", meta = (Categories = "Paper"))
    FGameplayTag PaperStyle;

    /** Ordem no arquivo, dentro do setor. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Document")
    int32 ArchiveOrder = 0;

    /** Opcional: leitura em voz (fitas, Cap. 52). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Document")
    TObjectPtr<USoundBase> Narration;

    virtual FPrimaryAssetId GetPrimaryAssetId() const override
    {
        return FPrimaryAssetId(TEXT("VGDocument"), GetFName()); // tipo "VGDocument" no Asset Manager
    }
};
```

### 2. Regras de leitura

```cpp
// Source/Vigilia/Narrative/VGDocumentRules.h
#pragma once

#include "CoreMinimal.h"

class UVGDocumentData;

namespace VGDocumentRules
{
    /** Tempo de leitura estimado (s): texto corrido, ~20 caracteres/s; mínimo de 2 s por página. */
    float EstimateReadSeconds(const UVGDocumentData& Document);

    /** Conta como lido? Última página alcançada OU metade do tempo estimado. Conservador por desenho. */
    bool CountsAsRead(int32 FurthestPage, int32 PageCount, float SecondsOpen, float EstimatedSeconds);
}
```

```cpp
// Source/Vigilia/Narrative/VGDocumentRules.cpp
#include "Narrative/VGDocumentRules.h"

#include "Narrative/VGDocumentData.h"

float VGDocumentRules::EstimateReadSeconds(const UVGDocumentData& Document)
{
    constexpr float CharsPerSecond = 20.0f; // leitura no ritmo da jogadora; mais rápido que legenda (Cap. 44)
    constexpr float MinPerPage = 2.0f;
    float Total = 0.0f;
    for (const FText& Page : Document.Pages)
    {
        Total += FMath::Max(MinPerPage, Page.ToString().Len() / CharsPerSecond);
    }
    return Total;
}

bool VGDocumentRules::CountsAsRead(int32 FurthestPage, int32 PageCount, float SecondsOpen, float EstimatedSeconds)
{
    const bool bReachedEnd = PageCount > 0 && FurthestPage >= PageCount - 1;
    return bReachedEnd || SecondsOpen >= 0.5f * EstimatedSeconds;
}
```

Repare num caso de borda que a regra decide de propósito: um documento de **uma página** é "alcançado até o fim" no instante em que abre. Para ele, abrir é ler. Para bilhetes curtos, como o do armário, isso é aceitável. Se um documento de uma página for importante para uma variante de fala, divida-o, ou troque a regra para exigir também um tempo mínimo (exercício).

### 3. O leitor

O leitor é um subsistema de mundo com uma máquina de estados pequena (fechado → lendo → fechado), dono do modo `Reading` enquanto um documento está aberto.

```cpp
// Source/Vigilia/Narrative/VGDocumentReaderSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGDocumentReaderSubsystem.generated.h"

class UVGDocumentData;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGDocumentPageSignature, const UVGDocumentData*, Document, int32, Page);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FVGDocumentClosedSignature);

/**
 * Abre, pagina e fecha documentos; decide se a leitura conta e registra o fato.
 * Relógio: tempo REAL (ler é atividade humana; a pausa raramente acontece com um documento aberto).
 */
UCLASS()
class VIGILIA_API UVGDocumentReaderSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Documents")
    void Open(const UVGDocumentData* Document);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Documents")
    void TurnPage(int32 Delta);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Documents")
    void Close();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Documents")
    bool IsReading() const { return Current != nullptr; }

    /** Documentos lidos, na ordem do arquivo (lista os assets do tipo VGDocument e filtra pelos fatos). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Documents")
    TArray<UVGDocumentData*> GetArchive() const;

    /** Abriu ou mudou de página: a UI desenha. */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Documents")
    FVGDocumentPageSignature OnPageShown;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Documents")
    FVGDocumentClosedSignature OnClosed;

private:
    class AVGPlayerController* GetPlayerController() const;

    UPROPERTY()
    TObjectPtr<const UVGDocumentData> Current;

    int32 Page = 0;
    int32 FurthestPage = 0;
    double OpenedAt = 0.0;
};
```

```cpp
// Source/Vigilia/Narrative/VGDocumentReaderSubsystem.cpp (essencial)
#include "Narrative/VGDocumentReaderSubsystem.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Engine/AssetManager.h"
#include "Engine/World.h"
#include "Narrative/VGDocumentData.h"
#include "Narrative/VGDocumentRules.h"
#include "Narrative/VGNarrativeSubsystem.h"
#include "Player/VGPlayerController.h"

void UVGDocumentReaderSubsystem::Open(const UVGDocumentData* Document)
{
    if (!Document || Document->Pages.IsEmpty() || Current)
    {
        return; // um documento por vez
    }
    Current = Document;
    Page = 0;
    FurthestPage = 0;
    OpenedAt = GetWorld()->GetRealTimeSeconds();

    if (AVGPlayerController* PC = GetPlayerController())
    {
        PC->PushInputMode(EVGInputMode::Reading); // dono do nível de pilha que empilhou (Cap. 16)
    }
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Document_Opened, nullptr, nullptr, Document->DocumentTag);
    OnPageShown.Broadcast(Current, Page);
}

void UVGDocumentReaderSubsystem::TurnPage(int32 Delta)
{
    if (!Current)
    {
        return;
    }
    Page = FMath::Clamp(Page + Delta, 0, Current->Pages.Num() - 1);
    FurthestPage = FMath::Max(FurthestPage, Page);
    OnPageShown.Broadcast(Current, Page);
}

void UVGDocumentReaderSubsystem::Close()
{
    if (!Current)
    {
        return;
    }
    const UVGDocumentData* Closed = Current;
    const float SecondsOpen = static_cast<float>(GetWorld()->GetRealTimeSeconds() - OpenedAt);
    const bool bRead = VGDocumentRules::CountsAsRead(FurthestPage, Closed->Pages.Num(), SecondsOpen,
                                                     VGDocumentRules::EstimateReadSeconds(*Closed));
    Current = nullptr; // estado consistente antes dos anúncios (Cap. 4)

    if (AVGPlayerController* PC = GetPlayerController())
    {
        PC->PopInputMode(EVGInputMode::Reading);
    }
    OnClosed.Broadcast();

    if (bRead)
    {
        if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
        {
            Narrative->AddFact(Closed->ReadFact);
        }
        UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Document_Read, nullptr, nullptr, Closed->DocumentTag);
    }
}

TArray<UVGDocumentData*> UVGDocumentReaderSubsystem::GetArchive() const
{
    TArray<UVGDocumentData*> Archive;
    const UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this);
    TArray<FPrimaryAssetId> Ids;
    UAssetManager::Get().GetPrimaryAssetIdList(FPrimaryAssetType(TEXT("VGDocument")), Ids);
    for (const FPrimaryAssetId& Id : Ids)
    {
        // Simplificação: carga síncrona ao abrir o arquivo (dezenas de assets pequenos).
        UVGDocumentData* Document = Cast<UVGDocumentData>(UAssetManager::Get().GetPrimaryAssetPath(Id).TryLoad());
        if (Document && Narrative && Narrative->HasFact(Document->ReadFact))
        {
            Archive.Add(Document);
        }
    }
    Archive.Sort([](const UVGDocumentData& A, const UVGDocumentData& B)
    {
        return A.DocumentTag.ToString() != B.DocumentTag.ToString()
            ? A.DocumentTag.ToString() < B.DocumentTag.ToString() // agrupa por setor (Document.S1.*, S2.*)
            : A.ArchiveOrder < B.ArchiveOrder;
    });
    return Archive;
}

AVGPlayerController* UVGDocumentReaderSubsystem::GetPlayerController() const
{
    return Cast<AVGPlayerController>(GetWorld()->GetFirstPlayerController());
}
```

### 4. O documento no mundo

```cpp
// Source/Vigilia/Interaction/VGReadable.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Interaction/VGInteractable.h"
#include "VGReadable.generated.h"

class UVGDocumentData;

/** Um documento no mundo: interagir abre o leitor. Pode ficar no lugar (placa, parede) ou ser levado. */
UCLASS()
class VIGILIA_API AVGReadable : public AActor, public IVGInteractable
{
    GENERATED_BODY()

public:
    AVGReadable();

    virtual bool CanInteract_Implementation(AActor* Interactor) const override;
    virtual void Interact_Implementation(AActor* Interactor) override;
    virtual FText GetInteractionPrompt_Implementation(AActor* Interactor) const override;

protected:
    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<UStaticMeshComponent> Mesh;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Document")
    TObjectPtr<const UVGDocumentData> Document;

    /** Levado ao ler (some do mundo; continua no arquivo). Falso: fica no lugar. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Document")
    bool bTakeOnRead = true;
};
```

```cpp
// Source/Vigilia/Interaction/VGReadable.cpp (essencial)
#include "Interaction/VGReadable.h"

#include "Components/StaticMeshComponent.h"
#include "Core/VGCollision.h"
#include "Narrative/VGDocumentData.h"
#include "Narrative/VGDocumentReaderSubsystem.h"

AVGReadable::AVGReadable()
{
    PrimaryActorTick.bCanEverTick = false;
    Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
    SetRootComponent(Mesh);
    Mesh->SetCollisionResponseToChannel(ECC_VGInteraction, ECR_Block); // detectável pela interação (Cap. 19)
}

bool AVGReadable::CanInteract_Implementation(AActor* Interactor) const
{
    const UVGDocumentReaderSubsystem* Reader = GetWorld()->GetSubsystem<UVGDocumentReaderSubsystem>();
    return Document && Reader && !Reader->IsReading();
}

void AVGReadable::Interact_Implementation(AActor* Interactor)
{
    UVGDocumentReaderSubsystem* Reader = GetWorld()->GetSubsystem<UVGDocumentReaderSubsystem>();
    if (!Reader)
    {
        return;
    }
    Reader->Open(Document);
    if (bTakeOnRead)
    {
        // Some na hora, mas o documento segue aberto no leitor e vai para o arquivo se a leitura contar.
        // Simplificação: um documento "levado" e não lido sai do mundo assim mesmo; o Cap. 57 decide se ele volta.
        SetActorHiddenInGame(true);
        SetActorEnableCollision(false);
    }
}

FText AVGReadable::GetInteractionPrompt_Implementation(AActor* Interactor) const
{
    return NSLOCTEXT("Vigilia", "ReadPrompt", "Ler");
}
```

### Explicação das decisões

- **O leitor é dono do modo `Reading`**: ele empilha ao abrir e desempilha ao fechar (Capítulo 16, "quem empilhou é dono daquele nível"). Nenhum widget mexe na pilha.
- **Um documento por vez** (`Open` recusa se já há um aberto). Um documento aberto por cima de outro empilharia `Reading` duas vezes e desalinharia o leitor e a pilha.
- **Relógio real**, declarado no comentário da classe. Ler é atividade humana, e o hitstop ou a câmera lenta não deveriam acelerar nem atrasar a contagem. A pausa com o documento aberto é rara, e contá-la como leitura é inofensivo, porque a regra já é conservadora.
- **A leitura concede o fato direto do dado** (`ReadFact`). É um momento narrativo, não um "evento de mundo" (Capítulo 46, seção 46.4). O evento `Event.Document.Read` continua publicado para objetivos e telemetria.
- **O arquivo é deduzido** dos fatos de leitura e da lista de assets do Asset Manager. Não há conjunto novo no estado narrativo e, portanto, nada novo para salvar nem para versionar.
- **Esconder, não destruir**, ao levar o documento. O ator continua existindo e a persistência (Capítulo 57) decide o que acontece com ele num save.
- **Prompt localizável** com `NSLOCTEXT`, como todo texto exibido.

### 5. Teste

```cpp
// Source/Vigilia/Tests/VGDocumentRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Narrative/VGDocumentData.h"
#include "Narrative/VGDocumentRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGDocumentRulesTest, "Vigilia.Narrative.Documents.ReadHeuristic",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGDocumentRulesTest::RunTest(const FString& Parameters)
{
    UVGDocumentData* Doc = NewObject<UVGDocumentData>();
    Doc->Pages = { FText::FromString(FString::ChrN(200, TEXT('a'))), FText::FromString(FString::ChrN(200, TEXT('b'))) };
    const float Estimated = VGDocumentRules::EstimateReadSeconds(*Doc);
    TestEqual(TEXT("Estimativa: 400 caracteres a 20/s"), Estimated, 20.0f);

    TestFalse(TEXT("Abrir e fechar não é ler"), VGDocumentRules::CountsAsRead(0, 2, 1.0f, Estimated));
    TestTrue(TEXT("Chegar à última página é ler"), VGDocumentRules::CountsAsRead(1, 2, 3.0f, Estimated));
    TestTrue(TEXT("Metade do tempo na primeira página é ler"), VGDocumentRules::CountsAsRead(0, 2, 10.0f, Estimated));
    TestTrue(TEXT("Documento de uma página: abrir é ler (decisão declarada)"), VGDocumentRules::CountsAsRead(0, 1, 0.1f, 5.0f));
    return true;
}

#endif
```

O último caso fixa uma **decisão** em teste: se alguém mudar a regra de uma página, o teste falha e obriga a pessoa a mudar o teste, e com isso a pensar na mudança.

---

## Projeto 6 — os documentos e o espaço do setor 1

🔁 A quinta etapa da refatoração do *Turno da Noite*.

### Os documentos como dados

| Asset | `DocumentTag` | Páginas | `ReadFact` | No mundo |
|---|---|---|---|---|
| `DA_Doc_S1_Logbook` | `Document.S1.Logbook` | 2 (as entradas até 00h20; depois 00h41–00h58) | `Document.Logbook.Read` | `AVGReadable` no vestiário, levado ao ler |
| `DA_Doc_S1_Memo` | `Document.S1.Memo` | 1 | `Document.Memo.Read` | Na mesa do engenheiro, levado |
| `DA_Doc_S1_BilheteArmario` | `Document.S1.LockerNote` | 1 | `Document.LockerNote.Read` | No armário, com a chave, fica no lugar |
| `DA_Doc_S1_BilheteTeixeira` | `Document.S1.TeixeiraNote` | 1 | `Document.TeixeiraNote.Read` | No hall, condicionado (Cap. 47) |

Ao dividir o livro de ocorrências em duas páginas, a sequência dos disjuntores (00h41) e a última entrada, que prenuncia o susto (00h58), ficam juntas na segunda. **Ler o livro de verdade exige chegar a ela.** É ali que a variante de fala "foi igual ao livro" passa a fazer sentido.

### O que muda em volta

- **Cap. 46:** as regras `Event.Item.Collected` + `Item.Document.*` → `Document.*.Read` **saem** do `DA_FatosDoJogo`. A leitura concede o fato.
- **Cap. 45:** o objetivo `DA_Obj_S1_Livro` passa a ouvir `Event.Document.Opened` com o contexto `Document.S1.Logbook`. "Encontre o livro" se conclui ao **abrir** o livro, não ao ler, porque o objetivo é encontrá-lo. O que a história faz com a leitura vem do fato.
- **Cap. 44:** a conversa `DA_Dlg_S1_PosSusto` ganha uma variante condicionada a `TEM Document.Logbook.Read`: *"Helena? Você tá aí? ...Foi igual ao livro, não foi. As luzes."* É o prenúncio do desafio do Capítulo 43, fechado: quem leu reconhece o susto, e Sônia confirma o reconhecimento.

### As vinhetas

| Vinheta | Onde | Intenção | Elementos |
|---|---|---|---|
| **Os seis armários** | Vestiário | Seis pessoas, uma noite: cinco armários fechados, um aberto às pressas | Nomes nas portas (os mesmos dos crachás), um casaco no banco, a chave e o bilhete |
| **A mesa de Moraes** | Sala do engenheiro | Ele tinha medo, e sabia | O rádio esquecido (o bilhete confirma), registros de vibração com anotações a lápis, a cadeira afastada |
| **As mãos na poeira** | Depósito, subsolo | Alguém religou os disjuntores **antes** de Helena | Marcas de mão nas alavancas, numa ordem diferente da do livro |
| **As luminárias** | Corredor | As luzes "andaram" antes | Lâmpadas quebradas em sequência, do fundo para a frente |

A terceira vinheta abre uma pergunta nova no livro-razão (*"quem religou os disjuntores antes, e numa ordem errada?"*), respondida no setor 3. A quarta é um prenúncio ambiental do susto, para quem **não** leu o livro.

### O inventário de dores

A refatoração do Interlúdio está quase completa. Restam a dor 6 (sequências sem cancelamento) e a parte da dor 12 que é a cinemática, ambas do próximo capítulo, e a dor 2 (salvar), que é o Capítulo 56.

---

## Decisões arquiteturais

1. **O espaço é texto**: vinhetas, rastros, documentos, áudio, arquitetura e mudança de estado, cada vinheta com uma frase de intenção.
2. **Documentos como dados** (`UVGDocumentData`), com páginas, voz e propósito no livro-razão.
3. **"Leu" é uma heurística conservadora e declarada**: última página ou metade do tempo estimado; a leitura concede o fato do próprio documento.
4. **O leitor é um subsistema dono do modo `Reading`**, um documento por vez, no relógio real.
5. **O arquivo é deduzido** dos fatos de leitura via Asset Manager, sem estado próprio.
6. **O mundo não para durante a leitura**, mas Diretor e rádio cooperam.

---

## Armadilhas

- **Documentos longos.** Ninguém lê três parágrafos com a Presença por perto.
- **Documento sem propósito no livro-razão**: decoração que custa a atenção da jogadora.
- **Explicar demais.** A vinheta com um bilhete dizendo o que a vinheta já mostra.
- **Incoerência entre texto e espaço.** O bilhete fala do rádio na mesa, e a mesa está vazia.
- **"Pegou" tratado como "leu"**, e falas que pressupõem conhecimento que a jogadora não tem.
- **O widget empilhando o modo de input.** Se a UI empilha e o subsistema desempilha (ou o contrário), a pilha desalinha (Capítulo 16).
- **Dois documentos abertos ao mesmo tempo.**
- **Arquivo com resumos automáticos** que fazem a investigação no lugar da jogadora.
- **Vinhetas ilegíveis no escuro.** Sem luz e som que guiem o olhar, a vinheta não existe (Caps. 51–52).

---

## Exercício

**Parte 1 — dados e regras (1 h).** Implemente `UVGDocumentData`, `VGDocumentRules` e o teste. Registre o tipo `VGDocument` no Asset Manager.

**Parte 2 — leitor e arquivo (2 h).** Implemente `UVGDocumentReaderSubsystem` e `AVGReadable`. Faça o `WBP_Documento` (página, título, estilo por `PaperStyle`) e o `WBP_Arquivo`. As teclas de página e de fechar entram no `IMC_Leitura` e chamam o subsistema pelo controller. Teste:
- abrir e fechar na hora: sem fato;
- ler até o fim: fato e arquivo;
- abrir o arquivo e reler: o fato não muda.

**Parte 3 — migração (1,5 h).** Migre os documentos do setor 1 conforme o Projeto 6, ajuste o objetivo do livro e as regras de fatos, e acrescente a variante "foi igual ao livro". Jogue duas vezes, lendo e não lendo o livro, e confira o comentário de Sônia depois do susto.

**Parte 4 — vinhetas (2 h).** Monte as quatro vinhetas no grey-box, cada uma com a frase de intenção no documento de nível. Peça a alguém que jogue sem explicação e pergunte depois: "o que você acha que aconteceu na sala do engenheiro?". Compare a resposta com a frase de intenção.

---

## Desafio — o caderno de Helena

Inspirado nas anotações de Outlast, desenhe e implemente um **caderno de perita**: depois de momentos-chave (o susto, a turbina vista pela janela, o fim do setor), Helena escreve uma anotação curta, que vai para o arquivo como um documento.

1. Cada anotação é um `UVGDocumentData` com `PaperStyle = Paper.Handwritten`, concedida por uma ação de quest (Capítulo 45) ou pelo gatilho do momento.
2. Escreva as três anotações do setor 1, até 40 palavras cada, na voz de uma perita técnica tentando manter o controle.
3. Decida e justifique no `DEVLOG.md`: o caderno contradiz a decisão do Capítulo 43 de que Helena quase não fala? Ele explica demais? Teste com alguém e decida se ele fica no jogo.

---

## Uso de IA

1. **Para revisar um documento:**
   > "Aqui está um documento de um jogo de terror (o livro de ocorrências de um turno noturno de 1994, abaixo), com o seu autor e a pergunta do mistério que ele deve abrir. Sem reescrever: aponte frases que explicam demais, frases genéricas, inconsistências de época (1994, Brasil, usina hidrelétrica) e onde a voz do autor se perde. [documento + contexto]"

2. **Para checar coerência entre texto e espaço:**
   > "Aqui estão os documentos de um setor de jogo e a descrição das vinhetas de cada sala. Liste todas as afirmações dos documentos que o espaço deveria confirmar (objetos, marcas, estados) e verifique quais estão presentes na descrição das salas. [documentos + vinhetas]"

3. **Para variar vinhetas:**
   > "Proponha três versões de uma vinheta de 'mesa de engenheiro abandonada às pressas numa usina em 1994', cada uma comunicando uma coisa diferente sobre ele (medo, culpa, negação), usando só objetos e o estado deles, sem texto."

**Cuidado específico:** IAs escrevem documentos de jogo "competentes" com muita facilidade, e é exatamente esse texto, plausível, completo e explicativo, que mata a narrativa ambiental de terror. Use a IA para encontrar o que sobra no seu texto, não para escrevê-lo.

---

## Checklist

- [ ] Sei as formas de narrativa ambiental e os quatro princípios (implicar, coerência, ritmo, legibilidade).
- [ ] Sei escrever documentos curtos, com voz e com propósito no livro-razão.
- [ ] Sei distinguir abriu, leu e arquivou, e a minha heurística de leitura é conservadora e testada.
- [ ] Implementei o leitor (dono do modo `Reading`) e o arquivo deduzido de fatos.
- [ ] Montei vinhetas com frase de intenção e sei condicioná-las ao estado.
- [ ] Os documentos do setor 1 são dados, e o prenúncio do livro se fecha com Sônia.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Asset Manager** (primary assets), **UMG Rich Text Block** e **Level Instancing**.
- **GDC Vault** (gdcvault.com): palestras sobre narrativa ambiental e *environmental storytelling* (há apresentações clássicas sobre o tema; confira títulos e autores lá) e postmortems de jogos de exploração narrativa.
- **Jesse Schell, *The Art of Game Design*** — os capítulos sobre mundo e história.

---

➡️ **Próximo:** [Capítulo 49 — Cinematics](cap-49-cinematics.md)
