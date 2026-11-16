# Capítulo 71 — IA para Narrative Design

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar por que, na Vigília, **a IA revisa e gera variações, e o texto final é humano**, com argumentos de design, de produção e de autoria;
- escrever uma **bíblia de mundo** que sirva ao mesmo tempo a pessoas e a IAs, incluindo a seção do que **nunca** se diz;
- verificar a consistência do roteiro contra **três fontes da verdade** (bíblia, livro-razão de mistério, catálogo de fatos) e reconhecer quatro tipos de inconsistência;
- usar IA para gerar **variações** de falas e *barks* como matéria-prima, sem perder a voz;
- usar IA em quests, documentos e localização, sabendo onde ela erra;
- exportar o roteiro dos assets para um arquivo de texto legível (por você e por uma IA) e escrever, à mão, as falas que o protótipo dos Capítulos 73–74 vai usar como significado e como reserva.

---

## Contexto

A Parte VI construiu os sistemas: o rádio como canal (Capítulo 44), quests como dados (45), um dono do estado narrativo (46), ramificação com orçamento (47), documentos e narrativa ambiental (48). A partir de agora, o gargalo da narrativa da Vigília deixa de ser engenharia e passa a ser **conteúdo**: dezenas de falas de Sônia, documentos de 1994, variantes por fato, *barks* dos vigias, tudo isso em português e, talvez, em inglês.

É exatamente aqui que a IA generativa parece mais tentadora, porque ela escreve texto fluente sem esforço. E é exatamente aqui que os capítulos anteriores mais alertaram. O Capítulo 43 disse que IAs escrevem prosa plausível e genérica. O Capítulo 44 disse que falas genéricas matam o rádio de um jogo de terror, e que a voz de Sônia é sua. Este capítulo transforma esses alertas em método: **onde** a IA ajuda no trabalho narrativo, **como** pedir, e **o que** fica com você.

Há também um motivo de continuidade. Os Capítulos 73 e 74 vão colocar um modelo de linguagem dentro do jogo, verbalizando respostas de Sônia. Esse protótipo só é seguro porque **o que Sônia pode dizer** é escrito à mão, condicionado por fatos. Essas falas nascem aqui, no projeto deste capítulo.

---

## 71.1 Por que o texto final é humano

Não é uma regra moral; são cinco motivos de engenharia e de design.

1. **Especificidade.** Terror vive do detalhe concreto: "as luzes do corredor apagaram de uma ponta à outra, como se alguém viesse andando com elas" (Capítulo 43). Um modelo de linguagem tende à continuação **mais provável**, e a mais provável é, por definição, a menos específica. Você pode empurrá-lo para o específico com exemplos e restrições, mas a fala que fica na memória da jogadora quase nunca é a mais provável.

2. **Contenção e ambiguidade.** O livro-razão de mistério (Capítulo 43) mantém perguntas abertas **de propósito**, e respostas parciais ("ver, não entender") assustam mais que respostas completas. Modelos de linguagem tendem a **explicar**: peça uma fala de Sônia sobre a Presença e é comum receber uma teoria. A bíblia da Vigília tem uma seção "nunca dizer" por causa disso.

3. **Consistência de elenco.** Sônia é "cansada, profissional, assustada sem admitir" (Capítulo 43). A voz de um personagem é uma soma de escolhas pequenas (o que ela nunca diz, como ela trata Helena, o humor seco), e escolhas pequenas se perdem quando cada fala vem de uma amostragem nova.

4. **Produção.** Cada fala autorada vira áudio dublado, legenda com tempo de leitura, entrada de *String Table*, linha de localização. O texto final precisa de um dono que responda por ele na gravação, na tradução e na revisão.

5. **Autoria e transparência.** Quem assina o roteiro responde por ele. E lojas digitais podem exigir que você declare o uso de conteúdo gerado por IA no jogo (confira as regras atuais da loja em que pretende publicar). O mais simples de declarar, e de defender, é "o texto do jogo foi escrito por pessoas; a IA foi usada em revisão e rascunhos".

O que sobra para a IA é muito, e é trabalho de verdade: **revisar** (consistência, ordem de revelação, tamanho de legenda, tradução), **listar** (o que falta, o que contradiz, o que se repete), **gerar matéria-prima** (variações que você reescreve), **traduzir em rascunho** e **sugerir** onde no livro-razão uma informação deveria entrar.

---

## 71.2 A bíblia de mundo

Uma **bíblia** é o documento de referência do mundo do jogo: o que é verdade, quem é quem, como cada um fala, o que aconteceu e quando. Num estúdio, ela é a fonte que roteiristas, artistas e QA consultam. Na Vigília, ela tem um papel extra: é o **contexto** que você cola antes de pedir qualquer revisão a uma IA, o equivalente narrativo do `CONTEXTO.md` do Capítulo 69.

```text
# docs/narrativa/biblia.md — VIGÍLIA (trecho)

STATUS DAS AFIRMAÇÕES
  [CÂNONE]  verdade no mundo do jogo; mudar exige revisar roteiro e catálogo de fatos
  [RASCUNHO] em discussão
  [NUNCA]   verdade que o jogo NUNCA diz explicitamente (nem Sônia, nem documentos)

O LUGAR                                                               [CÂNONE]
  Usina Hidrelétrica de Serra Funda, interior. Desativada. Três setores visitáveis:
  Casa de Força (S1), Subestação (S2), Salão das Turbinas (S3).

O EVENTO                                                              [CÂNONE]
  Noite de 14/08/1994: o turno C (seis homens) entrou e não saiu.
  O livro de ocorrências do turno termina no meio de uma frase.
  Esta noite (hoje), sem explicação, as turbinas voltaram a girar.

PESSOAS
  Helena Duarte — perita do órgão estadual de energia. Quase não fala; a jogadora fala por ela.
  Sônia — operadora da Central de Despacho, no rádio. Cansada, profissional, assustada sem
          admitir. Frases curtas. Trata Helena pelo nome. Humor seco quando tem medo.
          Só sabe o que está no papel e o que Helena conta a ela.
  Eng. Valter Moraes — engenheiro-chefe em 1994. Existe só em documentos.
  Os seis do turno C — (nomes e um traço de cada; ver tabela própria)

A PRESENÇA                                                            [NUNCA]
  (o que ela é, para quem escreve; o jogo nunca diz)

REGRAS DE VOZ
  Documentos de 1994: ofício numerado, carimbo, linguagem de repartição, datas por extenso.
  Sônia: nunca explica a Presença; nunca diz "monstro"; nunca promete que vai dar tudo certo.
  Ninguém usa gíria posterior a 1994 nos documentos.

GLOSSÁRIO
  Casa de Força, disjuntor, turbina 3, livro de ocorrências, Central de Despacho...
```

Três decisões de formato importam:

- **Status em cada afirmação.** Uma IA não distingue cânone de rascunho a menos que o texto distinga. Sem o status, ela trata uma ideia descartada como verdade e "corrige" o roteiro na direção errada.
- **A seção `[NUNCA]` está na bíblia, e fora dos prompts de geração.** Para revisar consistência, a IA precisa saber o que é a Presença, porque é assim que ela aponta uma fala que **revela demais**. Para gerar variações, ela não deve saber, porque o que o modelo sabe pode aparecer no texto. Essa é a mesma regra que o Capítulo 74 vai aplicar em runtime: **não peça segredo ao modelo; não lhe dê o segredo**.
- **Regras de voz como regras verificáveis**, não como adjetivos. "Sônia nunca diz 'monstro'" é verificável. "Sônia é misteriosa" não é.

---

## 71.3 Três fontes da verdade e quatro inconsistências

A Vigília tem três documentos que, juntos, definem o que é uma fala correta:

```text
 BÍBLIA                  LIVRO-RAZÃO (Cap. 43)           CATÁLOGO DE FATOS (Cap. 46)
 o que é VERDADE         QUANDO a jogadora fica           o que o JOGO SABE que ela
 no mundo                sabendo, e por qual canal        viu, leu, fez ou contou
        │                          │                                │
        └──────────────────────────┼────────────────────────────────┘
                                   ▼
                    uma FALA (texto + condição sobre fatos)
```

E uma fala pode estar errada de quatro maneiras:

| Tipo | Exemplo na Vigília | Quem detecta |
|---|---|---|
| **Contradição factual** | Um documento diz que o turno C tinha sete homens; outro diz "turno B" | Comparação com a bíblia: boa tarefa para IA |
| **Revelação fora de ordem** | Uma fala do setor 1 responde à pergunta 3 do livro-razão ("o que Moraes sabia?"), que só fecha no setor 2 | Comparação com o livro-razão: boa tarefa para IA, com o livro-razão no contexto |
| **Conhecimento indevido** | Sônia diz "você religou a três" numa variante em que Helena **não** admitiu (o fato `Narrative.Fact.Helena.AdmittedTurbine3` não está na condição) | Comparação texto × condição × catálogo: a IA aponta candidatas; você confirma |
| **Condição desalinhada** | A fala exige `Document.Memo.Read`, mas o texto supõe que Helena leu o **livro** de ocorrências | Idem |

As duas primeiras são clássicas de qualquer obra longa. As duas últimas são **específicas de narrativa interativa**: o mesmo texto vive em estados diferentes do jogo, e a fala certa num estado é errada em outro. É o "o que Helena contou a Sônia" do Capítulo 44 virando critério de revisão.

A ferramenta do Capítulo 47 (auditoria combinatória) responde a perguntas **estruturais**: que combinações de fatos deixam uma conversa muda, que nós nunca tocam. Ela não lê o texto. A revisão deste capítulo é o complemento: dado um nó tocável, **o texto dele é verdadeiro naquele estado?** Uma é código; a outra é leitura. A IA é boa na leitura, se tiver as três fontes e o roteiro **com as condições** à vista.

Por isso a implementação deste capítulo é um exportador: os assets de diálogo são binários e a IA não os lê. O texto está nas *String Tables*, mas as condições estão nos nós.

---

## 71.4 Variações sem perder a voz

Gerar variações é o uso mais óbvio, e o que mais exige método. O fluxo que funciona:

```text
 1. VOCÊ escreve a fala de referência (a que você gravaria se só houvesse uma)
 2. IA: N variações, com a regra de voz e a referência no prompt; "nenhuma explica nada"
 3. VOCÊ escolhe 2 ou 3 e REESCREVE cada uma (nunca usa sem editar)
 4. IA (revisão): "estas três soam como a mesma pessoa? alguma revela mais que a referência?"
 5. VOCÊ decide; as falas entram na String Table
```

O passo 3 é o que separa matéria-prima de produto. Uma variação gerada costuma ter um acerto (uma imagem, um ritmo) e dois vícios (uma explicação, um clichê). Reescrever é guardar o acerto e cortar os vícios.

### Barks: geração offline

Os *barks* dos vigias (desafio do Capítulo 44) são o caso ideal para geração **offline**: muitas falas curtas, por situação, com exigência de variedade e de não-repetição. O *pipeline*:

```text
 situação (Event.AI.TargetLost, ...) + tom ("cansado e nervoso, não militar") + limite (6 palavras)
   → IA gera 15 por situação → você corta para 5 e reescreve → gravação → UVGBarkSet
```

Repare no que **não** acontece: nenhum modelo roda durante o jogo. A variedade que a jogadora percebe vem de cinco falas autorais por situação, do sorteio sem repetição e das condições do banco de regras. O Capítulo 74 volta a essa escolha e explica por que os *barks* ficam offline mesmo quando o jogo tem um modelo de linguagem disponível.

### Variantes por fato

A auditoria do Capítulo 47 lista combinações de fatos em que uma conversa fica **muda**. Cada uma é um pedido natural de variante: "escreva três versões desta fala para quem **não** leu o memorando e **leu** o livro". A IA gera, você reescreve, a condição entra no nó. É trabalho mecânico de narrativa interativa, e é onde a IA economiza mais tempo com menos risco, porque a referência e as restrições estão todas no pedido.

---

## 71.5 Quests e documentos

**Quests.** O Capítulo 47 estabeleceu o **orçamento de ramificação**: toda escolha de estado precisa de uma consequência tardia, e cada variante tem custo. Peça ideias de quest secundária à IA **com o custo junto** ("para cada ideia: quantas falas novas, quantos documentos, que fatos novos, onde é lida a consequência"). Sem isso, a IA propõe o que aparece nos textos sobre jogos de escolhas: reputação, finais múltiplos, companheiros. O Capítulo 45 já alertou que ela tende ao RPG grande.

**Documentos.** Para os documentos de 1994 (Capítulo 48), a IA é útil em três revisões:

- **Anacronismo:** "este memorando de 1994 de uma estatal brasileira tem algum objeto, expressão ou procedimento que não existiria na época?". A resposta é uma lista de **suspeitas**, e cada suspeita histórica precisa de verificação em fonte confiável. A IA também inventa história.
- **Forma:** "este ofício segue as regras de voz da bíblia (numeração, carimbo, datas por extenso, linguagem de repartição)?". Regras explícitas são verificáveis.
- **Lugar no livro-razão:** "que perguntas este documento abre ou responde? Em que setor ele deveria estar?". Uma boa forma de descobrir que um documento bonito revela cedo demais.

---

## 71.6 Localização assistida

O texto da Vigília está em `FText` e em *String Tables* desde o Capítulo 44, e por isso a tradução é possível sem tocar em código. A IA pode fazer o primeiro rascunho, com quatro cuidados:

1. **Glossário fixo.** "Casa de Força", "Central de Despacho", "turno C" têm tradução decidida uma vez e colada em todo pedido.
2. **Restrições de legenda.** Duas linhas, tempo mínimo de leitura (Capítulo 44). Uma tradução fiel e longa demais é uma tradução errada.
3. **Gênero e número.** O português marca gênero onde o inglês não marca, e vice-versa. Sônia fala com Helena; frases neutras em inglês podem precisar de escolha em português, e o contrário também acontece.
4. **Retrotradução como teste.** Traduza para o inglês, peça a **outra** conversa que traduza de volta, compare com o original. O que mudou de sentido é onde a tradução escorregou.

A revisão final é de alguém que fala a língua de chegada. Se o jogo sair em inglês, uma revisão humana nativa (LQA, *localization quality assurance*) não é luxo.

---

## Estudos de caso

### Amnesia: A Machine for Pigs — a voz ao telefone

**[FATO PÚBLICO — observável jogando]** Em *Amnesia: A Machine for Pigs* (The Chinese Room e Frictional Games, 2013), o protagonista, Oswald Mandus, é guiado ao longo do jogo por uma voz que fala com ele por telefone. Quem é essa voz, e o que ela quer, permanece ambíguo por boa parte da experiência.

**[INFERÊNCIA]** A força da voz vem tanto do que ela **não** diz quanto do que diz. Cada telefonema entrega instrução e inquietação na mesma fala, e a ambiguidade é **mantida por escolha de escrita** ao longo do jogo. Se cada fala fosse escrita para ser a mais clara possível, a tensão se dissolveria em exposição.

**Lição para a Vigília:** Sônia ocupa um lugar estrutural parecido (uma voz que guia, a distância), com intenção diferente: ela é aliada e está assustada. A tentação de uma IA, ao gerar falas para uma voz que guia, é **esclarecer**. A seção `[NUNCA]` da bíblia e a regra de voz "nunca explica a Presença" existem para conter isso na revisão, e o Capítulo 74 as transforma em **estrutura**: o modelo que verbaliza Sônia em runtime nunca recebe o segredo.

### Control — a voz de uma instituição como regras

**[FATO PÚBLICO — observável jogando]** Em *Control* (Remedy, 2019), boa parte do mundo do Federal Bureau of Control chega à jogadora por documentos internos: memorandos, relatórios, correspondência. Muitos têm trechos **tarjados** (palavras cobertas por barras pretas), e o tom é de repartição, seco e procedimental, mesmo quando descreve o absurdo.

**[INFERÊNCIA]** A "voz" do Bureau é, em grande parte, um conjunto de **regras de forma**: tipos de documento, cabeçalhos, jargão, o que é tarjado. Regras assim são reconhecíveis e, por isso, **verificáveis**: dá para conferir se um documento novo as segue. O conteúdo que faz um documento ser memorável (o detalhe estranho dito em linguagem de formulário) continua sendo escolha de quem escreve.

**Lição para a Vigília:** escreva a voz da estatal de 1994 como regras na bíblia (ofício numerado, carimbo, datas por extenso, a assinatura "Eng. Valter Moraes") e use a IA para **conferir** os documentos contra as regras. É uma tarefa em que ela vai bem. Escrever o detalhe estranho continua sendo com você.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Bíblia de mundo | **Linguagem ubíqua** e invariantes do domínio (DDD) | Parte do domínio é **segredo de propósito** (`[NUNCA]`), e o "usuário" não pode descobri-lo cedo |
| Revisão de consistência | Testes de contrato, validação de esquema | O "esquema" é semântico (fatos, ordem de revelação); a IA aponta, não prova |
| Livro-razão de mistério | Plano de *release* de informação | O objetivo é **manter** dívida de informação aberta até o momento certo |
| Variante por fato | *Feature flag* com textos por variante | O mesmo texto é certo num estado e falso em outro: o teste é por estado |
| Localização assistida | Pipeline de i18n com tradução automática + revisão | O texto tem voz, tempo de legenda e, às vezes, áudio por idioma |

> 🌉 **Ponte:** a bíblia é o que o DDD chama de linguagem ubíqua, escrita, com os invariantes do domínio ("o turno C tinha seis homens"). Você já sabe que um domínio sem linguagem ubíqua produz código inconsistente; um mundo sem bíblia produz roteiro inconsistente, e uma IA sem bíblia produz as duas coisas.
>
> 🧱 **Onde a ponte cai:** num sistema corporativo, todo invariante deve estar visível para quem usa o sistema. Num mistério, alguns invariantes devem ficar **escondidos** da jogadora até o fim, e de alguns colaboradores (inclusive de uma IA geradora) para sempre.

---

## Unreal Engine: o que existe

- **`FText` e *String Tables*** (Capítulo 44): o texto mora fora do código e dos grafos. Uma *String Table* pode ser exportada e importada como CSV, que é o formato natural para revisão em planilha e por IA.
- **Painel de localização** (*Localization Dashboard*): coleta os textos do projeto, exporta arquivos para tradução (no formato PO, usado por ferramentas de tradutores) e importa as traduções de volta. ⚠️ Confira os passos e opções na documentação da sua versão.
- **Asset Registry**: lista os assets de um tipo sem abri-los um a um. É o que o exportador deste capítulo usa.
- **Validação de dados** (`IsDataValid`, Capítulo 13) e a **auditoria combinatória** do Capítulo 47, para o que é estrutural.

O que **não** existe: nenhuma ferramenta da engine lê o roteiro com as condições e o compara com uma bíblia. Esse é o trabalho do exportador mais o prompt de revisão.

---

## Abordagens

Onde a IA entra no texto da Vigília:

| Critério | A. IA escreve o texto final | B. IA rascunha, humano reescreve | **C. Humano escreve, IA revisa e varia** |
|---|---|---|---|
| **Complexidade** | Baixa | Média | Média |
| **Performance** (velocidade) | Alta | Alta | Média |
| **Extensibilidade** (escala de conteúdo) | Alta, com qualidade instável | Alta | Média: o gargalo é você |
| **Manutenção** (consistência de voz) | Ruim: cada fala é uma amostragem | Média | Boa: uma voz, revisada por lista |
| **Prototipação** | Ótima para texto descartável | Boa | Boa |
| **Adequação à Vigília** | Não: terror, rádio, voz única | Para *barks* e texto descartável | **Sim**, para tudo que a jogadora lê ou ouve |

**Decisão:** **C** para o roteiro: falas de Sônia, documentos, textos de quest. **B** só para matéria-prima de alto volume e baixa importância individual (*barks*, variantes de ambiente), sempre reescrita. **A** só para texto de protótipo que nunca chega à jogadora, como placeholders num nível de teste, marcados para substituição.

---

## Implementação: o roteiro como texto

O exportador percorre todos os `UVGDialogueData` e `UVGDocumentData` do projeto e escreve um Markdown com o texto **e as condições** de cada fala. É uma ferramenta de editor, um *cheat* do console disponível no PIE, que gera um arquivo para leitura.

```csharp
// Vigilia.Build.cs — acrescentar (Cap. 71)
"AssetRegistry"
```

```cpp
// Source/Vigilia/Debug/VGCheatManager.h (adição)
#if WITH_EDITOR
    /** Escreve Saved/Narrative/roteiro.md: todas as conversas e documentos, com condições e efeitos. */
    UFUNCTION(Exec)
    void VGExportScript();
#endif
```

```cpp
// Source/Vigilia/Debug/VGCheatManager.cpp (adição)
#if WITH_EDITOR
#include "Algo/Sort.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Core/VGLog.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Narrative/VGDialogueData.h"
#include "Narrative/VGDocumentData.h"
#include "Narrative/VGSpeakerData.h"

namespace
{
    /** Carrega todos os assets de uma classe. Ferramenta de editor: carga síncrona é aceitável. */
    template <typename T>
    TArray<const T*> LoadAllAssetsOfClass()
    {
        IAssetRegistry& Registry =
            FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry")).Get();
        TArray<FAssetData> Found;
        Registry.GetAssetsByClass(T::StaticClass()->GetClassPathName(), Found); // ⚠️ UE 5.1+: caminho da classe

        TArray<const T*> Loaded;
        for (const FAssetData& Asset : Found)
        {
            if (const T* Object = Cast<T>(Asset.GetAsset()))
            {
                Loaded.Add(Object);
            }
        }
        Algo::Sort(Loaded, [](const T* A, const T* B) { return A->GetName() < B->GetName(); });
        return Loaded;
    }
}

void UVGCheatManager::VGExportScript()
{
    FString Out = TEXT("# Roteiro corrido da Vigília\n\n_Gerado por VGExportScript. Não edite: edite os assets._\n\n");

    for (const UVGDialogueData* Dialogue : LoadAllAssetsOfClass<UVGDialogueData>())
    {
        Out += FString::Printf(TEXT("## %s `%s`\n\n"), *Dialogue->GetName(), *Dialogue->ConversationTag.ToString());
        for (const FVGDialogueNode& Node : Dialogue->Nodes)
        {
            const FString Speaker = Node.Speaker ? Node.Speaker->DisplayName.ToString() : TEXT("?");
            Out += FString::Printf(TEXT("- **%s** — %s: %s\n"), *Node.Id.ToString(), *Speaker, *Node.Text.ToString());
            if (!Node.Condition.IsEmpty())
            {
                // ⚠️ A descrição é montada pelo editor ao editar a consulta; confira na sua versão.
                Out += FString::Printf(TEXT("  - condição: %s\n"), *Node.Condition.GetDescription());
            }
            if (!Node.GrantFacts.IsEmpty())
            {
                Out += FString::Printf(TEXT("  - concede: %s\n"), *Node.GrantFacts.ToStringSimple());
            }
            for (const FVGDialogueChoice& Choice : Node.Choices)
            {
                Out += FString::Printf(TEXT("  - escolha: \"%s\" → concede %s\n"),
                                       *Choice.Text.ToString(), *Choice.GrantFacts.ToStringSimple());
            }
        }
        Out += TEXT("\n");
    }

    for (const UVGDocumentData* Document : LoadAllAssetsOfClass<UVGDocumentData>())
    {
        Out += FString::Printf(TEXT("## Documento: %s — %s\n\n"), *Document->GetName(), *Document->Title.ToString());
        for (const FText& Page : Document->Pages)
        {
            Out += Page.ToString() + TEXT("\n\n");
        }
        if (Document->ReadFact.IsValid())
        {
            Out += FString::Printf(TEXT("_Ao ler, concede: %s_\n\n"), *Document->ReadFact.ToString());
        }
    }

    const FString Path = FPaths::ProjectSavedDir() / TEXT("Narrative/roteiro.md");
    FFileHelper::SaveStringToFile(Out, *Path, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
    UE_LOG(LogVigilia, Display, TEXT("VGExportScript: %s"), *Path);
}
#endif
```

O arquivo gerado é a entrada da revisão. O prompt de revisão é um modelo fixo do projeto:

```text
# docs/ia/prompts/revisar-roteiro.md

Contexto: [biblia.md COMPLETA, incluindo NUNCA] [livro-razão] [docs/design/fatos.md]
Roteiro: [Saved/Narrative/roteiro.md, só o setor em revisão]

Para CADA fala, verifique e relate só os problemas, em tabela (fala | tipo | evidência | sugestão):
 1. CONTRADIÇÃO: o texto contradiz uma afirmação [CÂNONE] da bíblia?
 2. ORDEM: o texto abre ou responde uma pergunta do livro-razão antes do setor previsto?
 3. CONHECIMENTO: o falante sabe algo que, NAQUELA condição, ele não teria como saber?
    (Sônia só sabe o que está no papel e o que Helena contou: fatos Helena.*)
 4. CONDIÇÃO: o texto supõe um fato que não está na condição da fala?
 5. NUNCA: o texto revela ou insinua fortemente algo marcado [NUNCA]?
 6. VOZ: o texto viola uma REGRA DE VOZ (cite a regra)?
Não reescreva falas. Não elogie. Se não tiver certeza, diga "verificar" e por quê.
```

### Explicação das decisões

- **Exportar com as condições**, não só o texto. Três dos seis itens da revisão dependem da condição da fala; uma *String Table* sozinha não basta.
- **Um *cheat* de editor, não um *commandlet*.** É o mecanismo de ferramenta que o projeto já tem (Capítulos 16, 44, 46), e roda no PIE com um comando. Um *commandlet* rodaria sem abrir o editor e caberia num script como o do Capítulo 69; vale a pena quando a revisão virar rotina de integração.
- **`#if WITH_EDITOR`** no cheat inteiro: a ferramenta carrega todos os assets de forma síncrona e não tem lugar num build de jogo.
- **Saída em Markdown, ordenada por nome de asset.** Duas exportações seguidas produzem o mesmo arquivo, e o diff entre versões do roteiro passa a ser legível no controle de versão.
- **O prompt pede tabela e proíbe reescrita.** A revisão produz achados; reescrever é a próxima etapa, e é sua.

---

## Projeto Vigília — a bíblia e as falas de Sônia

O que muda no repositório:

```text
docs/narrativa/
├── biblia.md                  cânone, rascunho, NUNCA; pessoas; regras de voz; glossário
└── revisoes/2026-xx-s1.md     o resultado da revisão do setor 1, com o que foi corrigido
docs/ia/prompts/
└── revisar-roteiro.md
Saved/Narrative/roteiro.md     gerado (não versionado)
```

**A revisão do setor 1.** Rode `VGExportScript`, cole o setor 1 e as três fontes, e corrija o que for confirmado. Registre também os **falsos positivos**: eles mostram onde a bíblia está ambígua e precisa de uma linha nova.

**As falas livres de Sônia.** O protótipo dos Capítulos 73–74 deixa a jogadora fazer perguntas livres a Sônia pelo rádio, dentro de um conjunto **fechado** de intenções. Para cada intenção, Sônia tem uma resposta **autorada**, com variantes por fato. Essa resposta tem dois papéis: é o **significado** que o modelo pode parafrasear e é a **reserva** dublada quando o modelo falha. Escreva-as aqui, à mão, com as regras deste capítulo. Os textos abaixo são um ponto de partida para você reescrever:

| Intenção | Condição (fatos `Narrative.Fact.*`) | Fala autorada |
|---|---|---|
| `Ask.Objective` | NÃO `S1.BreakersRestored` | "Os disjuntores ficam no subsolo da Casa de Força. Escada do fundo, Helena." |
| | `S1.BreakersRestored` E NÃO `S1.Completed` | "Os painéis acenderam aqui. Volta pro hall, que eu te guio." |
| | `S1.Completed` | "Sai pela porta do pátio. A subestação é a próxima." |
| `Ask.TurnoC` | `Document.Logbook.Read` | "Você leu o livro. Eu também. Trinta vezes. E continuo sem saber." |
| | NÃO `Document.Logbook.Read` | "Seis homens entraram no turno C em 14 de agosto de 94. Nenhum saiu. É o que tem no papel." |
| `Ask.Moraes` | `Document.Memo.Read` | "Se o Moraes mandou não religar a três, ele sabia de alguma coisa. Eu não sei o quê." |
| | NÃO `Document.Memo.Read` | "Moraes era o engenheiro-chefe. A sala dele fica na Casa de Força." |
| `Ask.Presence` | — | "Eu não sei o que é. E não quero descobrir pelo rádio. Fica no claro." |
| `Talk.Fear` | — | "Eu tô aqui. Respira. No claro você tá segura." |
| `Ask.Sonia` | — | "Central de Despacho. Quarenta quilômetros daí, com café ruim e a luz acesa." |
| `Unknown` | — | "Helena? A linha tá ruim. Fala de novo?" |
| (ocupada) | — | "Agora não. Fica quieta e escuta." |

Cada linha vira um nó num `DA_Dlg_Free_*` (um asset por intenção, prioridade Normal, `bOnce = false`, com `Next = End` em cada nó para que só uma variante toque), com texto numa *String Table* nova, `ST_Radio_Livre`. Passe as falas pela revisão de seis itens **antes** de gravá-las: elas vão ser ditas em qualquer momento em que a conversa livre estiver aberta, e por isso a pergunta "esta fala é verdadeira em todos os estados em que a condição passa?" importa mais do que em qualquer fala de beat.

Repare em duas escolhas. A fala de `Ask.Presence` **não tem variante**: em nenhum estado do jogo Sônia explica a Presença. E a fala de `Unknown` usa uma desculpa **diegética** (a linha está ruim) para o caso em que o sistema não entendeu, um recurso que o Capítulo 74 vai explorar.

---

## Decisões arquiteturais

1. **Texto final humano; IA em revisão, variação e rascunho de tradução.** *Barks* e variantes de baixo peso podem nascer de rascunho de IA, sempre reescritos.
2. **Bíblia com status por afirmação** (`[CÂNONE]`, `[RASCUNHO]`, `[NUNCA]`), servindo a pessoas e a IAs.
3. **`[NUNCA]` entra no contexto de revisão e fica fora do contexto de geração.**
4. **Consistência contra três fontes** (bíblia, livro-razão, catálogo de fatos), com quatro tipos de inconsistência, dois deles específicos de narrativa interativa.
5. **O roteiro sai dos assets para texto** com condições e efeitos (`VGExportScript`), ordenado e reproduzível.
6. **As respostas livres de Sônia são autoradas aqui**, com variantes por fato, e servem de significado e de reserva ao protótipo dos Capítulos 73–74.

---

## Armadilhas

- **Usar uma variação gerada sem reescrever.** Ela costuma trazer um clichê ou uma explicação a mais.
- **Deixar a IA "consertar" o mistério.** Peça revisão de consistência, não de clareza: clareza demais é o defeito.
- **Bíblia sem status.** A IA trata rascunho como cânone e corrige o roteiro na direção errada.
- **Pôr a seção `[NUNCA]` num prompt de geração.** O que o modelo sabe pode aparecer no texto.
- **Revisar o texto sem as condições.** Conhecimento indevido e condição desalinhada são invisíveis numa *String Table*.
- **Confiar em fatos históricos fornecidos pela IA** para os documentos de 1994. Suspeitas de anacronismo são pistas, não fatos.
- **Traduzir sem glossário e sem limite de legenda.** O resultado é fiel e inutilizável.
- **Pedir "torne esta fala mais assustadora".** O resultado típico é adjetivo e explicação; terror é detalhe e omissão.

---

## Exercício

**Parte 1 — a bíblia (1 h).** Escreva o `biblia.md` com as seções do trecho da seção 71.2, status em cada afirmação, a tabela dos seis do turno C e pelo menos cinco regras de voz verificáveis.

**Parte 2 — o exportador (1 h).** Implemente `VGExportScript`, rode no PIE e abra o `roteiro.md`. Confira se as condições aparecem legíveis; se `GetDescription()` vier vazio na sua versão, troque por uma listagem das tags da consulta e anote no `apis-verificadas.md`.

**Parte 3 — a revisão do setor 1 (1,5 h).** Rode o prompt de revisão com as três fontes. Classifique cada achado em confirmado, falso positivo (e por quê) ou "verificar". Corrija os confirmados nos assets e exporte de novo; o diff do `roteiro.md` mostra o que mudou.

**Parte 4 — as falas livres (1 h).** Reescreva a tabela de falas livres de Sônia com a sua voz. Crie os `DA_Dlg_Free_*` e a `ST_Radio_Livre`. Passe cada fala pela revisão e confira, uma a uma, que nenhuma variante de `Ask.Objective` é falsa em algum estado em que a condição passa.

---

## Desafio — o tradutor adversário

Traduza o setor 1 para o inglês com ajuda de IA, usando um glossário e o limite de duas linhas de legenda. Depois:

1. Em **outra** conversa, sem contexto, peça a retrotradução para o português.
2. Compare original e retrotradução fala a fala, e marque: sentido preservado, sentido deslocado, tom perdido.
3. Para cada deslocamento, decida se o erro está na tradução ou na **ambiguidade do original** (às vezes, a fala em português dizia duas coisas e a tradução escolheu uma).
4. Registre no `DEVLOG.md`: quantas falas tiveram de ser reescritas **no original** por causa da tradução? O que isso diz sobre escrever pensando em localização desde o começo?

---

## Uso de IA

Prompts meta, para avaliar o seu uso de IA no texto:

1. **Para medir o achatamento da voz:**
   > "Aqui estão duas versões de 10 falas: a minha original e a que ficou depois de eu aceitar sugestões de IA. Sem dizer qual é qual, compare as duas colunas: qual é mais específica, qual explica mais, qual usa mais palavras comuns, e em quais falas as diferenças são maiores. [coluna A] [coluna B]"

2. **Para auditar o que a IA sabe do seu mistério:**
   > "Leia apenas estas 20 falas e 5 documentos do setor 1. Sem nenhum outro contexto, diga o que você acha que é a Presença e o que aconteceu com o turno C, e com que confiança. Cite as falas que sustentam cada palpite."
   *(Se o palpite estiver certo e com confiança alta, o setor 1 revela demais. Se estiver perdido, talvez revele de menos.)*

3. **Para checar a sua dependência na escrita:**
   > "Aqui está o meu DEVLOG das sessões de escrita. Liste as falas que entraram no jogo com menos de 30% de mudança em relação à sugestão de IA, e as que eu reescrevi por completo. Não julgue a qualidade; só mostre a proporção."

4. **Para revisar a bíblia como contrato:**
   > "Esta é a bíblia de um jogo narrativo. Encontre afirmações ambíguas (que admitem duas leituras), regras de voz que não são verificáveis, e fatos [CÂNONE] que se contradizem entre si. Não acrescente conteúdo ao mundo."

**Cuidado específico:** a pergunta "esta fala está boa?" quase sempre recebe sim com sugestões de "melhoria" que acrescentam explicação, adjetivo ou emoção declarada. Em terror e em mistério, essas melhorias costumam piorar a fala. Peça revisão contra **regras escritas** (bíblia, livro-razão, catálogo), nunca contra gosto.

---

## Checklist

- [ ] Sei explicar os cinco motivos pelos quais o texto final da Vigília é humano.
- [ ] Tenho uma bíblia com status por afirmação, regras de voz verificáveis e a seção `[NUNCA]`.
- [ ] Sei por que `[NUNCA]` entra no contexto de revisão e fica fora do de geração.
- [ ] Sei reconhecer os quatro tipos de inconsistência e quais são específicos de narrativa interativa.
- [ ] Exportei o roteiro com condições e rodei a revisão do setor 1.
- [ ] Sei gerar variações e *barks* como matéria-prima e reescrevê-los.
- [ ] Escrevi à mão as falas livres de Sônia, com variantes por fato, prontas para o Capítulo 74.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Localization** (painel de localização, coleta, exportação e importação de traduções) e **String Tables**.
- **Chris Bateman (org.), *Game Writing: Narrative Skills for Videogames*.** Coletânea sobre escrita para jogos, com capítulos sobre diálogo, documentação de mundo e trabalho com equipes.
- **Emily Short** (emshort.blog): textos sobre narrativa baseada em estado e sobre ferramentas de escrita procedural, com uma visão crítica de onde a geração ajuda e onde atrapalha.
- **GDC Vault** (gdcvault.com): a trilha *Narrative Summit*, com palestras sobre bíblias de mundo, localização e escrita de *barks*. Confira títulos e autores lá.
- **Game Accessibility Guidelines** (gameaccessibilityguidelines.com): a seção de legendas, que vale como restrição em qualquer tradução.

---

➡️ **Próximo:** [Capítulo 72 — IA para Game AI](cap-72-ia-game-ai.md)
