# Capítulo 55 — UI/UX

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o modelo do **UMG**: *widgets* como árvore, `UUserWidget` com base em C++, `BindWidget`, ciclo de vida e o custo de atualizar a UI;
- classificar elementos de interface em **diegéticos**, **não diegéticos**, **espaciais** e **meta**, e decidir qual usar num jogo de terror;
- montar a **HUD formal** da Vigília, que substitui os widgets provisórios dos capítulos anteriores (legendas, respostas, diário, documento, arquivo, objetivos, prompt, munição, mira);
- desenhar a UI **subordinada à pilha de modos** do Capítulo 16, com a regra de que *widgets* não empilham modos;
- construir as **opções e a acessibilidade**: legendas (tamanho, fundo, nomes), `vg.Camera.Motion`, luzes piscando, campo de visão, brilho, volumes, remapeamento;
- avaliar o **CommonUI** com a cautela que ele merece.

---

## Contexto

A Vigília tem UI desde o Capítulo 19, mas nunca teve **uma** UI. Ela tem uma coleção de widgets criados por quem precisou deles, cada um no capítulo em que apareceu:

| Widget provisório | Capítulo | Quem cria | Problema |
|---|---|---|---|
| `WBP_PromptInteracao` | 19 | O controller, no `BeginPlay` | Reinscreve à mão a cada possessão |
| Texto de munição | 20 | Debug na tela | "Temporário, até o Capítulo 55" |
| `WBP_Notificacoes` | 24 | Quem quiser | Ferramenta de depuração na tela da jogadora |
| HUD de objetivos | 31 | Debug | Lista permanente de tarefas: contradiz o Cap. 50 |
| `WBP_Legenda`, `WBP_RespostasRadio` | 44 | "O HUD" ("o Capítulo 55 formaliza") | Sem opções de tamanho, sem regra de camada |
| `WBP_Diario` | 45 | "A HUD formal é o Capítulo 55" | Só texto |
| `WBP_Documento`, `WBP_Arquivo` | 48 | O leitor | Sem lugar no menu |

E há promessas acumuladas: o *hit marker* (Cap. 27), a vinheta de dano e o indicador direcional (Cap. 21), a calibração de brilho (Cap. 51), os volumes por classe (Cap. 52), as opções de inverter o eixo (Cap. 14), de segurar ou alternar (Cap. 17), de campo de visão e de movimento de câmera (Cap. 18) e de luzes piscando (Cap. 11). O Capítulo 11 avisou, no primeiro dia: luzes piscando podem desencadear crises em pessoas com epilepsia fotossensível, e a opção é requisito, não detalhe.

Este capítulo fecha a Parte VII. Depois dele, a Vigília tem espaço, luz, som, corpo, efeitos e interface: o setor 1 está pronto para ser salvo (Cap. 56).

---

## 55.1 UMG: o modelo

O **UMG** (*Unreal Motion Graphics*) é o sistema de UI da Unreal, construído sobre o **Slate**, a biblioteca de UI em C++ que desenha o próprio editor. No dia a dia, você trabalha com UMG; o Slate aparece quando você precisa de algo que o UMG não expõe.

**Uma árvore de widgets.** Um `UUserWidget` (o asset `WBP_*`) é uma árvore: painéis (*Canvas*, *Overlay*, *Vertical Box*, *Horizontal Box*, *Grid*) contêm outros widgets (*Text*, *Rich Text*, *Image*, *Button*, *Progress Bar*). Cada filho tem um ***slot***, que diz como ele se posiciona no pai: âncoras e margens num *Canvas*, alinhamento e preenchimento num *Box*. **Âncoras** são o que faz a UI funcionar em telas de proporções diferentes: um elemento ancorado no canto inferior esquerdo fica lá em 16:9, 21:9 ou 4:3.

**Base em C++, aparência em Blueprint.** A regra de camadas do Capítulo 13 vale para UI: a classe C++ (`UVGSubtitleWidget`) tem a lógica (inscrever-se no sistema, aplicar as opções, mostrar e esconder) e declara os widgets de que precisa com `meta = (BindWidget)`; o Blueprint (`WBP_Legenda`) desenha, e **precisa** ter widgets com aqueles nomes e tipos, ou não compila.

**Ciclo de vida.** `NativeConstruct` roda quando o widget entra na tela (é o lugar de se inscrever em delegates); `NativeDestruct`, quando sai (o lugar de se desinscrever). Um widget pode ser construído e destruído várias vezes ao ser adicionado e removido; inscrições feitas fora desse par vazam.

**O custo da UI.** Cada widget visível tem custo de *layout* e de desenho. Três regras práticas:

- **Eventos, não *bindings* por frame.** O UMG permite ligar uma propriedade a uma função chamada todo frame (o *property binding*). É conveniente e caro. A Vigília atualiza a UI por eventos (`OnLineStarted`, `OnQuestChanged`, `OnHealthChanged`), como o Capítulo 4 ensinou: discreto por evento, contínuo por consulta, e só o que é realmente contínuo (a barra de tempo das respostas) é consultado a cada frame.
- ***Collapsed* para o que não aparece.** Um widget *Hidden* ainda ocupa espaço no *layout*; *Collapsed* sai do cálculo.
- ***Invalidation*.** Painéis de invalidação (*Invalidation Box*, *Retainer Box*) guardam o resultado de partes da UI que não mudam. ⚠️ São otimizações a medir, não a aplicar por padrão; o Capítulo 59 mede.

> 🌉 **Ponte:** o UMG é um *framework* de UI declarativo-retido, como uma árvore de componentes de *front-end*: composição, *layout* por contêineres, ciclo de vida de montagem e desmontagem, e o mesmo conselho de não recalcular tudo a cada renderização.
>
> 🧱 **Onde a ponte cai:** a UI de uma aplicação é o produto; a de um jogo de terror é uma **intrusão** no produto. Cada elemento na tela compete com a escuridão e com o medo. A pergunta de design não é "como mostrar bem", é "isto precisa estar na tela?".

---

## 55.2 Diegético, não diegético, espacial, meta

Uma classificação útil, de uma tese de 2009 sobre interfaces de FPS (Erik Fagerholt e Magnus Lorentzon), cruza duas perguntas: o elemento **existe na ficção**? Ele está **no espaço 3D** do jogo?

```text
                         EXISTE NA FICÇÃO?
                     sim                      não
               ┌──────────────────────┬──────────────────────┐
  NO ESPAÇO    │ DIEGÉTICO            │ ESPACIAL             │
  DO JOGO?     │ o LED da lanterna;   │ o contorno de        │
     sim       │ o papel do documento;│ interação (Cap. 54); │
               │ o rádio na mesa      │ um marcador no mundo │
               ├──────────────────────┼──────────────────────┤
     não       │ META                 │ NÃO DIEGÉTICO        │
               │ a vinheta de dano;   │ legendas; prompt;    │
               │ a respiração;        │ menu; mira;          │
               │ a tela "suja" do     │ aviso de objetivo    │
               │ rádio chiando        │                      │
               └──────────────────────┴──────────────────────┘
```

- **Diegético**: Helena poderia vê-lo. O LED de bateria na lanterna, o papel do documento.
- **Espacial**: está no mundo 3D, mas não na ficção. O contorno de interação.
- **Meta**: está na ficção (a dor, o medo), mas é mostrado na tela, não no mundo. A vinheta de dano, a respiração (Cap. 52).
- **Não diegético**: nem na ficção nem no espaço. Legendas, menus, o prompt "E — Ler".

Para um jogo de terror, a regra da Vigília é uma ordem de preferência: **diegético > meta > espacial > não diegético**. Toda informação começa tentando ser diegética e só "desce" quando não dá. A bateria da lanterna é diegética (o LED); a vida é meta (vinheta e respiração, sem números, Cap. 21); o contorno é espacial e discreto (Cap. 54); a legenda é não diegética, e **tem de ser**, porque acessibilidade vem antes de imersão.

> 🌉 **Ponte:** é a hierarquia de lugares onde uma informação pode viver numa ferramenta: no próprio objeto (o estado no botão), num indicador perto dele, numa notificação, numa página de configurações. Quanto mais perto do objeto, menos carga cognitiva.
>
> 🧱 **Onde a ponte cai:** numa ferramenta, a clareza é o objetivo final. No terror, um pouco de **incerteza** é desejada: o LED de bateria piscando, difícil de ler no escuro, é melhor que um "23%" nítido. A exceção são as informações de acessibilidade, que nunca podem ser incertas.

---

## 55.3 A UI obedece à pilha de modos

O Capítulo 16 construiu a pilha de modos de input (`Exploration`, `Reading`, `Cinematic`, `UI`, `Dead`) com a regra do dono único: **quem empilha é dono daquele nível**. O Capítulo 48 aplicou a regra à UI pela primeira vez: o leitor de documentos empilha `Reading`, e "nenhum widget mexe na pilha".

Este capítulo generaliza para toda a interface, em duas regras:

**1. A visibilidade das camadas de UI é derivada do modo no topo.** A UI é organizada em **camadas**, e o que cada camada mostra depende só do modo atual:

| Modo no topo | Jogo (mira, prompt, munição, avisos) | Leitura (documento) | Menu (pausa, opções, arquivo, diário) | Morte | Sobreposição (legendas, respostas) |
|---|:-:|:-:|:-:|:-:|:-:|
| `Exploration` | ✓ | | | | ✓ |
| `Reading` | | ✓ | | | ✓ |
| `Cinematic` | | | | | ✓ |
| `UI` | | | ✓ | | |
| `Dead` | | | | ✓ | ✓ |

Ninguém "esconde a mira ao abrir um documento": a mira some porque o topo da pilha passou a ser `Reading`. É o mesmo princípio do `ApplyTopMode` (Cap. 16) e do mix de áudio derivado (Cap. 52): um valor efetivo **derivado** do estado, recalculado a cada mudança, em vez de cada sistema ligar e desligar o que acha que deve.

**2. Widgets não empilham modos; eles pedem a quem é dono.** O botão "Continuar" do menu de pausa não chama `PopInputMode(UI)`: ele chama `ClosePauseMenu()` no controller, que é o dono do modo `UI` e decide. O botão de fechar do documento chama `Close()` no leitor (Cap. 48), dono de `Reading`. O "continuar" da tela de morte chama `RequestRespawn()` (Cap. 22), dono de `Dead`. A UI é a **face** dos sistemas, nunca o dono do estado deles.

Por que isso importa? Porque UI é onde os bugs de estado mais aparecem. O caso clássico: um widget empilha `UI` ao abrir, o jogador morre enquanto ele está aberto, o sistema de morte empilha `Dead` por cima, e o widget, ao fechar, desempilha... `Dead`. Com a regra, o widget nunca desempilhou nada; o controller fecha o menu, e o `PopInputMode` com o modo esperado (Cap. 16) pega o desalinhamento no `ensure` em vez de deixá-lo virar um jogo travado.

> 🌉 **Ponte:** é a separação entre *view* e *controller*/serviço numa UI: o botão dispara uma intenção ("fechar o menu"); quem é dono do estado decide e muda; a *view* reage ao estado novo.
>
> 🧱 **Onde a ponte cai:** numa aplicação, a navegação costuma ser a própria UI (o roteador é dono da pilha de telas). No jogo, a pilha de modos é do **input**, compartilhada por UI, leitura, cinemáticas e morte, e a UI é só uma das clientes. Deixar a UI ser dona da pilha é deixar uma cliente mandar nas outras.

---

## 55.4 A HUD formal da Vigília

Com as duas regras, a HUD vira uma estrutura simples: **um** widget raiz (`UVGHUDLayout`), criado pelo controller, com cinco camadas nomeadas, e os widgets de cada camada inscritos nos sistemas que mostram.

```text
 WBP_HUD (pai: UVGHUDLayout), criado pelo AVGPlayerController (local)
 │
 ├─ GameLayer      WBP_Mira (ponto, só com arma; marcador de acerto curto)
 │                 WBP_Prompt ("E — Ler", com a tecla do mapeamento atual)
 │                 WBP_Municao (só com arma na mão; some depois de 3 s parada)
 │                 WBP_AvisoObjetivo (3 s quando a etapa da quest muda)
 │                 [vinheta de dano: pós-processamento dirigido pela HUD]
 ├─ ReadingLayer   WBP_Documento (RichText, estilo por PaperStyle)
 ├─ MenuLayer      WBP_Menu: Continuar · Diário · Arquivo · Opções · Sair
 ├─ DeathLayer     WBP_Morte ("continuar")
 └─ OverlayLayer   WBP_Legenda · WBP_RespostasRadio
```

Quatro decisões de design por trás dela:

1. **Sem lista de objetivos permanente.** O Capítulo 50 decidiu: o diário diz o quê, o espaço diz onde. O aviso de objetivo aparece por 3 s quando uma etapa muda (o resumo da etapa, Cap. 45) e some; o diário completo está no menu. A HUD de objetivos de depuração do Capítulo 31 sai da tela da jogadora.
2. **Sem números de vida.** "Dois toques, o primeiro é aviso" (Cap. 21) se comunica pela vinheta, pela respiração e pelo som abafado; a recuperação (8 s, 15/s, Cap. 22) é a vinheta se desfazendo. A HUD é dona da vinheta: ela escuta `OnHealthChanged` (Cap. 22) e escreve um parâmetro no material de pós-processamento.
3. **A mira só existe com arma.** Com a lanterna, não há mira: o feixe **é** a mira. Com a pistola de sinalização na mão, um ponto discreto; no trecho dos vigias, o marcador de acerto (`OnHitConfirmed`, Cap. 27) aparece por 0,15 s, porque ali a informação tática vale a intrusão.
4. **A bateria é diegética.** Um LED na lanterna (Cap. 53, a malha na mão esquerda), com um material dinâmico cujo parâmetro vem da carga da bateria (Cap. 4); um segundo LED, menor, mostra a prontidão da sobrecarga (`GetOverchargeReadiness`, Cap. 51). Quando a bateria está fraca, o LED pisca, e pisca também com `vg.Flicker.Enabled` desligado? **Não**: com a opção desligada, ele fica aceso em vermelho, fixo.

---

## 55.5 Opções e acessibilidade

As opções da Vigília seguem as *Game Accessibility Guidelines* (ver "Para ir além") nos pontos que um jogo deste porte consegue cumprir bem. Cada opção tem **um** dono no código, e a maioria já existe como CVar ou configuração desde o capítulo que criou o sistema.

| Grupo | Opção | Padrão | Dono / mecanismo |
|---|---|---|---|
| **Legendas** | Ligadas | **Sim** | `UVGSubtitleWidget` (Cap. 44: ligadas por padrão) |
| | Tamanho (4 passos) | Médio | Escala de fonte no widget |
| | Fundo (opacidade) | 60% | Borda atrás do texto (Cap. 44: contraste) |
| | Nome do falante | Sim | Widget |
| **Câmera** | Movimento da câmera (0–100%) | 100% | `vg.Camera.Motion` (Cap. 18) |
| | Campo de visão (80–110°) | 90° | Câmera (Cap. 18) |
| | Inverter eixo vertical | Não | Mapeamento (Cap. 14: configuração, não código) |
| **Luz** | **Reduzir luzes piscando** | Não | `vg.Flicker.Enabled` (Cap. 11) |
| | Brilho (calibração) | Calibrado no primeiro início | Viés de exposição (Cap. 51) |
| **Áudio** | Geral, música, vozes, efeitos | 100% | *Sound Classes* (Cap. 52) |
| **Controles** | Remapear teclas | — | Enhanced Input (seção abaixo) |
| | Correr e agachar: segurar ou alternar | Segurar | Triggers do Enhanced Input (Cap. 17) |
| **Vídeo** | Qualidade geral, qualidade de efeitos | Automático | Escalabilidade; `vg.Fx.ImpactBudget` (Cap. 54) |

Três notas de design:

- **"Reduzir luzes piscando" muda o jogo inteiro, e por isso o jogo inteiro respeita a CVar**: as luminárias (o `UVGFlickerComponent`, Cap. 9), a lanterna (Cap. 51) e a cascata do susto (que, com a opção, vira um escurecimento em sequência, sem estroboscópio). O susto continua funcionando, e é o teste da opção: se ele depende do flicker para assustar, o design está frágil.
- **Legendas ligadas por padrão**, com a opção oferecida **antes** do jogo começar (na primeira tela, junto com o brilho). Quem precisa de legendas não deveria ter de passar por uma cena sem elas para achar o menu.
- **Opções valem no meio do jogo.** Mudar o tamanho da legenda com Sônia falando muda a legenda **agora**. O widget escuta a mudança de opções; ninguém precisa reiniciar nada.

### Remapeamento

O remapeamento é a opção mais pedida e a mais trabalhosa. No UE5, o Enhanced Input tem um sistema de configurações do jogador (*Enhanced Input User Settings*): as *Input Actions* declaram que são remapeáveis (*Player Mappable Key Settings*, com um nome estável), o jogador troca a tecla por meio das configurações do subsistema local de Enhanced Input, e as escolhas são salvas por perfil. ⚠️ Esse sistema surgiu como experimental por volta da 5.2–5.3 e teve a API ajustada desde então; confira na documentação da sua versão os nomes das funções (mapear, desmapear, salvar) e a opção de projeto que o habilita.

Duas consequências para a Vigília, independentes da API:

- **O prompt mostra a tecla atual.** "E — Ler" vira "F — Ler" se a jogadora remapeou. O `WBP_Prompt` pergunta ao sistema de input qual tecla está ligada à ação de interagir, em vez de ter "E" escrito.
- **O remapeamento cobre todos os contextos** (`IMC_Exploracao`, `IMC_Leitura`, `IMC_Cinematica`, `IMC_UI`, `IMC_Morte`): a tecla de pular cinemática remapeada não pode colidir com a de virar página, e a tela de opções avisa conflitos dentro de um mesmo contexto.

---

## 55.6 CommonUI, com cautela

O **CommonUI** é um plugin da Epic para UI de jogos multiplataforma. Ele oferece, entre outras coisas: uma pilha de widgets "ativáveis" (*activatable widgets*) que gerencia foco e input da UI; roteamento de input por camada; navegação por controle; ícones de botão que mudam com o dispositivo (teclado, Xbox, PlayStation); e estilos compartilhados.

É exatamente o tipo de ferramenta que resolve problemas que a Vigília **vai** ter se for para console ou se priorizar controle: navegação por gamepad nos menus, ícones corretos, foco que não se perde. E é exatamente o tipo de ferramenta que tem custo de adoção alto: um modelo próprio de input da UI que precisa conviver com a pilha de modos do Capítulo 16 (os dois querem ser donos de "quem recebe o input"), configuração de projeto, classes base próprias e uma documentação que pressupõe familiaridade.

**Decisão para a Vigília:** não adotar agora. A UI da Vigília é pequena (um menu de pausa com quatro abas, uma tela de opções, a HUD), a plataforma-alvo do livro é PC com mouse e teclado (e controle como bônus), e a pilha de modos já resolve quem recebe o input. A seção de Abordagens registra a reavaliação: se o Capítulo 62 decidir por um alvo de console, ou se a navegação por controle nos menus virar um problema em playtest, o CommonUI é o caminho, e a migração tem um ponto claro de encaixe (o `UVGHUDLayout` e as camadas viram a pilha de ativáveis, e o controller continua dono dos modos). ⚠️ Confira o estado e a documentação do plugin na sua versão antes de decidir.

---

## Estudos de caso

### Outlast — a interface que existe na ficção

**[FATO PÚBLICO, observável jogando]** Em *Outlast* (Red Barrels, 2013), ao erguer a câmera de vídeo, a tela passa a mostrar o visor dela: indicador de gravação, nível de bateria, zoom e, no escuro, a visão noturna esverdeada, que gasta bateria.

**[INFERÊNCIA]** A interface mais importante do jogo é diegética: a bateria é um recurso da ficção, mostrado por um objeto da ficção. Ela não quebra a imersão porque a jogadora está olhando **pela câmera do protagonista**. E o recurso cria a tensão do jogo (ver no escuro custa), como a lanterna da Vigília (Cap. 51). O Capítulo 18 já havia notado: a "câmera na ficção" da Vigília é a lanterna.

**Lição para a Vigília:** o LED da lanterna (seção 55.4) é a versão mínima dessa ideia. E é um lembrete de que a interface diegética funciona quando o objeto está **no centro da atenção** (a câmera erguida, a lanterna na mão). Uma informação diegética num objeto que a jogadora não olha é uma informação escondida.

### Call of Duty — o marcador de acerto

**[FATO PÚBLICO, observável jogando]** A série *Call of Duty* popularizou o ***hit marker***: um pequeno "X" em volta da mira, com um som seco, quando um tiro acerta um inimigo. Variações dele se espalharam por quase todos os FPS competitivos, junto com HUDs densas (minimapa, munição, *killfeed*, pontuação).

**[INFERÊNCIA]** O *hit marker* existe porque, num tiroteio rápido e a distância, o jogador não consegue ver se o tiro acertou pelo corpo do inimigo: a confirmação precisa ser imediata e inequívoca. A HUD densa serve a um jogo de decisões rápidas com muita informação tática. Ela seria o oposto do que um jogo de terror quer.

**Lição para a Vigília:** a Vigília tem a mesma necessidade, em escala menor, no trecho dos vigias, e usa o marcador ali e só ali. No resto, a confirmação é o corpo (o tranco do vigia, Cap. 53) e o efeito (a Presença queimando, Cap. 54). A mesma ferramenta de FPS, com dose mínima.

### Amnesia: The Dark Descent — o estado do corpo descrito, não medido

**[FATO PÚBLICO, observável jogando]** Em *Amnesia: The Dark Descent* (Frictional Games, 2010), não há barra de vida nem de sanidade na tela durante o jogo. O estado do protagonista aparece nos efeitos de imagem e som (distorção, respiração) e na tela de inventário, que mostra a saúde e a sanidade de forma ilustrada e descritiva, não numérica.

**[INFERÊNCIA]** A escolha protege a tensão: um número de sanidade convida à otimização ("ainda tenho 40%"); uma descrição e uma imagem distorcida convidam ao medo. A informação existe para quem a procura (no inventário), e o resto do tempo ela é **sentida**.

**Lição para a Vigília:** a vida de Helena segue o mesmo princípio (meta: vinheta e respiração). E, se um dia a Vigília quiser mostrar o estado com mais precisão, o lugar é o menu de pausa (diário), descrito na voz de Helena, nunca uma barra na tela.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| UMG | *Framework* de UI por componentes, com ciclo de vida | A UI é intrusão no produto, não o produto |
| Diegético × não diegético | Informação no objeto × em notificações | Um pouco de incerteza é desejada (exceto acessibilidade) |
| Camadas derivadas do modo | Estado derivado, recalculado na mudança | — (a analogia vale) |
| Widgets pedem, donos decidem | *View* dispara intenção; serviço muda o estado | A pilha de modos é do input, compartilhada; a UI é só uma cliente |
| Opções aplicadas na hora | Configuração com *hot reload* | O efeito é sentido (enjoo, crise fotossensível): a opção é requisito |

---

## Unreal Engine: o que existe

- **UMG**: `UUserWidget`, `UWidget`, painéis (`UCanvasPanel`, `UOverlay`, `UVerticalBox`...), `UTextBlock`, `URichTextBlock` (com *Text Style Set*, Cap. 48), `UImage`, `UButton`, `UProgressBar`, `UBorder`; `meta = (BindWidget)` e `BindWidgetOptional`; `CreateWidget`, `AddToViewport`, `RemoveFromParent`; animações de widget.
- **Input para UI**: os modos de input da engine (`FInputModeGameOnly`, `FInputModeUIOnly`, `FInputModeGameAndUI`), já aplicados pela pilha do Capítulo 16 (`bUIReceivesInput`, `bShowCursor`).
- **Configurações**: `UGameUserSettings` (subclassável; `ApplySettings`, `SaveSettings`, `GetGameUserSettings`), que já cuida de resolução e escalabilidade.
- **Enhanced Input User Settings** para remapeamento (⚠️ por versão).
- **CommonUI** (plugin) e **Slate**.
- **Widget Reflector** (ferramenta de depuração de UI) e o *Slate Insights*/estatísticas de UI (⚠️ por versão).

O que a engine **não** oferece: a regra de que a UI é derivada dos modos, a ordem de preferência diegética, e a decisão de **o que não mostrar**.

---

## Abordagens: a arquitetura da UI

| Critério | A. Cada sistema cria o seu widget (até aqui) | **B. Um layout raiz com camadas derivadas do modo** | C. CommonUI (pilha de *activatable widgets*) |
|---|---|---|---|
| **Quem decide o que aparece** | Cada widget, por conta própria | **Uma regra, a partir do modo** | A pilha de ativáveis |
| **Convivência com a pilha de modos** | Bugs de desalinhamento | **Natural (a UI lê o modo)** | Dois donos de "quem recebe input", a conciliar |
| **Navegação por controle, ícones por dispositivo** | À mão | À mão | **Pronta** |
| **Custo de adoção** | Nenhum | **Baixo** | Alto |
| **Teste** | Difícil | **Regra pura de camadas** | Difícil |
| **Adequação à Vigília** | Foi a dívida | **Sim** | Reavaliar se o alvo for console |

**Decisão: B.** O `UVGHUDLayout` com cinco camadas e a regra `VGUIRules::LayersFor`, testada. CommonUI fica registrado como a evolução natural se a plataforma mudar.

---

## Implementação

### 1. Módulos

`Build.cs`: acrescente `"UMG"`, `"Slate"` e `"SlateCore"`. Até aqui, os widgets eram só Blueprint; a partir de agora há classes C++ de UI.

### 2. A regra das camadas

```cpp
// Source/Vigilia/UI/VGUIRules.h
#pragma once

#include "CoreMinimal.h"
#include "Player/VGInputModes.h"

struct FVGUILayers
{
    bool bGame = false;
    bool bReading = false;
    bool bMenu = false;
    bool bDeath = false;
    bool bOverlay = false; // legendas e respostas
};

namespace VGUIRules
{
    /** O que cada camada mostra, derivado SÓ do modo no topo da pilha (Cap. 16). */
    FVGUILayers LayersFor(EVGInputMode TopMode);
}
```

```cpp
// Source/Vigilia/UI/VGUIRules.cpp
#include "UI/VGUIRules.h"

FVGUILayers VGUIRules::LayersFor(EVGInputMode TopMode)
{
    FVGUILayers L;
    switch (TopMode)
    {
    case EVGInputMode::Exploration: L.bGame = true;    L.bOverlay = true; break;
    case EVGInputMode::Reading:     L.bReading = true; L.bOverlay = true; break; // Sônia pode falar enquanto ela lê
    case EVGInputMode::Cinematic:   L.bOverlay = true; break;                    // legendas nas cenas (Cap. 49)
    case EVGInputMode::UI:          L.bMenu = true;    break;                    // pausa: o áudio e as falas param
    case EVGInputMode::Dead:        L.bDeath = true;   L.bOverlay = true; break;
    }
    return L;
}
```

### 3. O layout raiz

```cpp
// Source/Vigilia/UI/VGHUDLayout.h
#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "Player/VGInputModes.h"
#include "VGHUDLayout.generated.h"

class UPanelWidget;

/**
 * O widget raiz da Vigília: cinco camadas cuja visibilidade é derivada do modo de input no topo.
 * Não empilha nem desempilha modos: só os lê.
 */
UCLASS(Abstract)
class VIGILIA_API UVGHUDLayout : public UUserWidget
{
    GENERATED_BODY()

protected:
    virtual void NativeConstruct() override;
    virtual void NativeDestruct() override;

    UPROPERTY(meta = (BindWidget)) TObjectPtr<UPanelWidget> GameLayer;
    UPROPERTY(meta = (BindWidget)) TObjectPtr<UPanelWidget> ReadingLayer;
    UPROPERTY(meta = (BindWidget)) TObjectPtr<UPanelWidget> MenuLayer;
    UPROPERTY(meta = (BindWidget)) TObjectPtr<UPanelWidget> DeathLayer;
    UPROPERTY(meta = (BindWidget)) TObjectPtr<UPanelWidget> OverlayLayer;

private:
    UFUNCTION()
    void HandleInputModeChanged(EVGInputMode OldMode, EVGInputMode NewMode);

    void Apply(EVGInputMode TopMode);
};
```

```cpp
// Source/Vigilia/UI/VGHUDLayout.cpp
#include "UI/VGHUDLayout.h"

#include "Components/PanelWidget.h"
#include "Player/VGPlayerController.h"
#include "UI/VGUIRules.h"

namespace
{
    void SetShown(UWidget* Layer, bool bShown)
    {
        // Collapsed: fora do layout. HitTestInvisible: aparece, mas não rouba cliques das camadas de baixo.
        Layer->SetVisibility(bShown ? ESlateVisibility::SelfHitTestInvisible : ESlateVisibility::Collapsed);
    }
}

void UVGHUDLayout::NativeConstruct()
{
    Super::NativeConstruct();
    if (AVGPlayerController* PC = GetOwningPlayer<AVGPlayerController>())
    {
        PC->OnInputModeChanged.AddDynamic(this, &UVGHUDLayout::HandleInputModeChanged);
        Apply(PC->GetCurrentInputMode());
    }
}

void UVGHUDLayout::NativeDestruct()
{
    if (AVGPlayerController* PC = GetOwningPlayer<AVGPlayerController>())
    {
        PC->OnInputModeChanged.RemoveDynamic(this, &UVGHUDLayout::HandleInputModeChanged);
    }
    Super::NativeDestruct();
}

void UVGHUDLayout::HandleInputModeChanged(EVGInputMode OldMode, EVGInputMode NewMode)
{
    Apply(NewMode);
}

void UVGHUDLayout::Apply(EVGInputMode TopMode)
{
    const FVGUILayers L = VGUIRules::LayersFor(TopMode);
    SetShown(GameLayer, L.bGame);
    SetShown(ReadingLayer, L.bReading);
    SetShown(MenuLayer, L.bMenu);
    SetShown(DeathLayer, L.bDeath);
    SetShown(OverlayLayer, L.bOverlay);
}
```

`SelfHitTestInvisible` deixa a camada visível sem que ela mesma capture o mouse; os botões **dentro** do menu continuam clicáveis (eles têm a própria visibilidade *Visible*).

### 4. 🔁 O controller: dono da HUD e do menu de pausa

**Antes**, o `BP_VGPlayerController` criava o `WBP_PromptInteracao` no `BeginPlay` (Cap. 19), o HUD criava a legenda e as respostas (Cap. 44), e o leitor mostrava o documento (Cap. 48). **Agora**, o controller cria **um** layout, e é dono do modo `UI`:

```cpp
// VGPlayerController.h (adições)
public:
    /** Pausa: empilha UI (o controller é o dono deste nível da pilha). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|UI")
    void OpenPauseMenu();

    /** Chamado pelo botão "Continuar" e pela tecla de pausa no IMC_UI: o widget PEDE, o controller decide. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|UI")
    void ClosePauseMenu();

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|UI")
    TSubclassOf<class UVGHUDLayout> HUDLayoutClass; // WBP_HUD

private:
    UPROPERTY(Transient)
    TObjectPtr<class UVGHUDLayout> HUDLayout;
```

```cpp
// VGPlayerController.cpp (adições)
#include "Blueprint/UserWidget.h"
#include "Core/VGGameUserSettings.h"
#include "UI/VGHUDLayout.h"

// em BeginPlay, depois de empilhar Exploration (Cap. 16):
    if (IsLocalController() && HUDLayoutClass)
    {
        HUDLayout = CreateWidget<UVGHUDLayout>(this, HUDLayoutClass);
        HUDLayout->AddToViewport(); // a camada inicial vem do modo atual, no NativeConstruct
    }
    UVGGameUserSettings* Settings = UVGGameUserSettings::Get(); // nulo se a classe não foi registrada no .ini
    if (IsLocalController() && ensureMsgf(Settings, TEXT("GameUserSettingsClassName não aponta para VGGameUserSettings")))
    {
        Settings->ApplyAccessibility(); // CVars de acessibilidade valendo desde o 1º frame
        Settings->ApplyAudio(this);
    }

void AVGPlayerController::OpenPauseMenu()
{
    const EVGInputMode Top = GetCurrentInputMode();
    if (Top == EVGInputMode::UI || Top == EVGInputMode::Dead)
    {
        return; // já pausado; e na morte o "menu" é a tela de morte
    }
    PushInputMode(EVGInputMode::UI); // config do modo UI: bPausesGame, cursor, UI recebe input (Cap. 16)
}

void AVGPlayerController::ClosePauseMenu()
{
    if (GetCurrentInputMode() == EVGInputMode::UI)
    {
        PopInputMode(EVGInputMode::UI);
    }
}
```

A ação `IA_Pausa` (Esc / *Start*) entra no `IMC_Exploracao`, no `IMC_Leitura` e no `IMC_Cinematica` chamando `OpenPauseMenu`, e no `IMC_UI` chamando `ClosePauseMenu`. Pausar com um documento aberto empilha `UI` **sobre** `Reading`; ao fechar o menu, o documento continua aberto, no mesmo lugar. Abrir um documento a partir do **arquivo** (no menu) empilha `Reading` sobre `UI`, pelo leitor (Cap. 48); fechar o documento volta ao arquivo. Ninguém precisou escrever esses casos: eles saem da pilha.

### 5. As configurações

```cpp
// Source/Vigilia/Core/VGGameUserSettings.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameUserSettings.h"
#include "VGGameUserSettings.generated.h"

/**
 * Opções da jogadora, salvas em GameUserSettings.ini. Registrada em DefaultEngine.ini:
 *   [/Script/Engine.Engine]
 *   GameUserSettingsClassName=/Script/Vigilia.VGGameUserSettings
 */
UCLASS()
class VIGILIA_API UVGGameUserSettings : public UGameUserSettings
{
    GENERATED_BODY()

public:
    static UVGGameUserSettings* Get();

    virtual void ApplySettings(bool bCheckForCommandLineOverrides) override;

    /** Aplica as opções de acessibilidade (CVars) e avisa quem desenha (legendas). */
    void ApplyAccessibility();

    /** Volumes por Sound Class (Cap. 52), num mix de opções sempre empilhado. */
    void ApplyAudio(const UObject* WorldContext) const;

    /** Widgets que dependem de opções (legendas) se inscrevem aqui. */
    FSimpleMulticastDelegate OnAccessibilityApplied;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Subtitles")
    bool bSubtitlesEnabled = true;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Subtitles", meta = (ClampMin = "0.8", ClampMax = "2.0"))
    float SubtitleScale = 1.0f;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Subtitles", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float SubtitleBackgroundOpacity = 0.6f;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Subtitles")
    bool bShowSpeakerNames = true;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Camera", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float CameraMotion = 1.0f;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Camera", meta = (ClampMin = "80.0", ClampMax = "110.0"))
    float FieldOfView = 90.0f;

    /** "Reduzir luzes piscando" na tela = false aqui. */
    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Light")
    bool bFlickerEnabled = true;

    /** Viés de exposição da calibração de brilho (Cap. 51). */
    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Light", meta = (ClampMin = "-2.0", ClampMax = "2.0"))
    float BrightnessBias = 0.0f;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Audio", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float MusicVolume = 1.0f;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Audio", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float VoiceVolume = 1.0f;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Audio", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float EffectsVolume = 1.0f;

    UPROPERTY(Config, BlueprintReadWrite, Category = "Vigilia|Audio")
    bool bFirstRunDone = false; // a primeira tela (brilho + legendas) já foi mostrada?
};
```

```cpp
// Source/Vigilia/Core/VGGameUserSettings.cpp
#include "Core/VGGameUserSettings.h"

#include "Core/VGAudioSettings.h"
#include "Engine/Engine.h"
#include "HAL/IConsoleManager.h"
#include "Kismet/GameplayStatics.h"
#include "Sound/SoundClass.h"
#include "Sound/SoundMix.h"

UVGGameUserSettings* UVGGameUserSettings::Get()
{
    return GEngine ? Cast<UVGGameUserSettings>(GEngine->GetGameUserSettings()) : nullptr;
}

void UVGGameUserSettings::ApplySettings(bool bCheckForCommandLineOverrides)
{
    Super::ApplySettings(bCheckForCommandLineOverrides); // resolução, escalabilidade...
    ApplyAccessibility();
}

void UVGGameUserSettings::ApplyAccessibility()
{
    auto SetCVar = [](const TCHAR* Name, const FString& Value)
    {
        if (IConsoleVariable* Var = IConsoleManager::Get().FindConsoleVariable(Name))
        {
            Var->Set(*Value, ECVF_SetByGameSetting); // prioridade de "opção do jogo", abaixo do console
        }
    };
    SetCVar(TEXT("vg.Camera.Motion"), FString::SanitizeFloat(CameraMotion));
    SetCVar(TEXT("vg.Flicker.Enabled"), bFlickerEnabled ? TEXT("1") : TEXT("0"));
    OnAccessibilityApplied.Broadcast();
}

void UVGGameUserSettings::ApplyAudio(const UObject* WorldContext) const
{
    const UVGAudioSettings* Audio = GetDefault<UVGAudioSettings>();
    USoundMix* Mix = Audio->OptionsMix.LoadSynchronous();
    if (!Mix)
    {
        return;
    }
    auto Override = [&](const TSoftObjectPtr<USoundClass>& Class, float Volume)
    {
        if (USoundClass* Loaded = Class.LoadSynchronous())
        {
            UGameplayStatics::SetSoundMixClassOverride(WorldContext, Mix, Loaded, Volume, 1.0f, 0.2f, /*bApplyToChildren=*/true);
        }
    };
    Override(Audio->MusicClass, MusicVolume);
    Override(Audio->VoiceClass, VoiceVolume);
    Override(Audio->EffectsClass, EffectsVolume);
    UGameplayStatics::PushSoundMixModifier(WorldContext, Mix); // ⚠️ empilhar o mesmo mix de novo: confira se a sua versão conta referências
}
```

O `UVGAudioSettings` (Cap. 52) ganha quatro campos: `OptionsMix` (`SMix_Opcoes`), `MusicClass` (`SC_Trilha`), `VoiceClass` (`SC_Voz`) e `EffectsClass` (`SC_Mundo`). O volume geral é o `SC_Master` pela mesma função. ⚠️ Confira no seu projeto o comportamento de empilhar o mesmo mix mais de uma vez: se ele acumular, empilhe-o **uma vez** no início do jogo e, nas mudanças, só chame `SetSoundMixClassOverride`.

O **campo de visão** e o **brilho** são lidos pelos donos da câmera: o `AVGPlayerCameraManager` (Cap. 18) usa `FieldOfView` como base do FOV (o modificador de corrida continua multiplicando por cima), e um modificador de câmera aplica `BrightnessBias` como viés de exposição no pós-processamento (`UCameraModifier::ModifyPostProcess`; ⚠️ confira a assinatura). As opções não sabem quem as usa; os donos leem quando precisam.

### 6. A legenda

```cpp
// Source/Vigilia/UI/VGSubtitleWidget.h
#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "VGSubtitleWidget.generated.h"

class UBorder;
class UImage;
class UTextBlock;
struct FVGDialogueLineView;

/** Base do WBP_Legenda: mostra a fala atual (Cap. 44) aplicando as opções de legenda. */
UCLASS(Abstract)
class VIGILIA_API UVGSubtitleWidget : public UUserWidget
{
    GENERATED_BODY()

protected:
    virtual void NativeConstruct() override;
    virtual void NativeDestruct() override;

    UPROPERTY(meta = (BindWidget)) TObjectPtr<UBorder> Background;
    UPROPERTY(meta = (BindWidget)) TObjectPtr<UTextBlock> SpeakerText;
    UPROPERTY(meta = (BindWidget)) TObjectPtr<UTextBlock> LineText;
    UPROPERTY(meta = (BindWidget)) TObjectPtr<UImage> RadioIcon;

private:
    UFUNCTION()
    void HandleLineStarted(const FVGDialogueLineView& Line);

    UFUNCTION()
    void HandleLineEnded();

    void ApplyOptions();

    int32 BaseFontSize = 0;
    FDelegateHandle OptionsHandle;
};
```

```cpp
// Source/Vigilia/UI/VGSubtitleWidget.cpp
#include "UI/VGSubtitleWidget.h"

#include "Components/Border.h"
#include "Components/Image.h"
#include "Components/TextBlock.h"
#include "Core/VGGameUserSettings.h"
#include "Narrative/VGDialogueSubsystem.h"

void UVGSubtitleWidget::NativeConstruct()
{
    Super::NativeConstruct();
    BaseFontSize = LineText->GetFont().Size; // o tamanho desenhado no WBP é o "médio"
    if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>())
    {
        Dialogue->OnLineStarted.AddDynamic(this, &UVGSubtitleWidget::HandleLineStarted);
        Dialogue->OnLineEnded.AddDynamic(this, &UVGSubtitleWidget::HandleLineEnded);
    }
    if (UVGGameUserSettings* Settings = UVGGameUserSettings::Get())
    {
        OptionsHandle = Settings->OnAccessibilityApplied.AddUObject(this, &UVGSubtitleWidget::ApplyOptions);
    }
    ApplyOptions();
    SetVisibility(ESlateVisibility::Collapsed);
}

void UVGSubtitleWidget::NativeDestruct()
{
    if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>())
    {
        Dialogue->OnLineStarted.RemoveDynamic(this, &UVGSubtitleWidget::HandleLineStarted);
        Dialogue->OnLineEnded.RemoveDynamic(this, &UVGSubtitleWidget::HandleLineEnded);
    }
    if (UVGGameUserSettings* Settings = UVGGameUserSettings::Get())
    {
        Settings->OnAccessibilityApplied.Remove(OptionsHandle);
    }
    Super::NativeDestruct();
}

void UVGSubtitleWidget::ApplyOptions()
{
    const UVGGameUserSettings* Settings = UVGGameUserSettings::Get();
    if (!Settings)
    {
        return;
    }
    FSlateFontInfo Font = LineText->GetFont();
    Font.Size = FMath::RoundToInt(BaseFontSize * Settings->SubtitleScale);
    LineText->SetFont(Font);
    SpeakerText->SetFont(Font);
    Background->SetBrushColor(FLinearColor(0.0f, 0.0f, 0.0f, Settings->SubtitleBackgroundOpacity));
    SpeakerText->SetVisibility(Settings->bShowSpeakerNames ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed);
}

void UVGSubtitleWidget::HandleLineStarted(const FVGDialogueLineView& Line)
{
    const UVGGameUserSettings* Settings = UVGGameUserSettings::Get();
    if (Settings && !Settings->bSubtitlesEnabled)
    {
        return;
    }
    SpeakerText->SetText(Line.SpeakerName);
    SpeakerText->SetColorAndOpacity(FSlateColor(Line.SpeakerColor));
    LineText->SetText(Line.Text);
    RadioIcon->SetVisibility(Line.bOverRadio ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed);
    SetVisibility(ESlateVisibility::HitTestInvisible);
}

void UVGSubtitleWidget::HandleLineEnded()
{
    SetVisibility(ESlateVisibility::Collapsed);
}
```

⚠️ `UTextBlock::GetFont`/`SetFont` são os acessores das versões UE5 recentes (o acesso direto à propriedade `Font` foi depreciado); confira na sua. O tempo de cada legenda continua sendo do subsistema de diálogo (Cap. 44: duração mínima de leitura, relógio de áudio): o widget só mostra e esconde.

### 7. O teste

```cpp
// Source/Vigilia/Tests/VGUIRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "UI/VGUIRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGUIRulesTest, "Vigilia.UI.Layers",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGUIRulesTest::RunTest(const FString& Parameters)
{
    const FVGUILayers Explore = VGUIRules::LayersFor(EVGInputMode::Exploration);
    TestTrue(TEXT("Explorando: HUD de jogo e legendas"), Explore.bGame && Explore.bOverlay && !Explore.bMenu);

    const FVGUILayers Read = VGUIRules::LayersFor(EVGInputMode::Reading);
    TestTrue(TEXT("Lendo: sem mira/prompt, com documento"), !Read.bGame && Read.bReading);
    TestTrue(TEXT("Lendo: Sônia ainda é legendada"), Read.bOverlay);

    const FVGUILayers Scene = VGUIRules::LayersFor(EVGInputMode::Cinematic);
    TestTrue(TEXT("Cena: só legendas"), Scene.bOverlay && !Scene.bGame && !Scene.bReading && !Scene.bMenu);

    const FVGUILayers Pause = VGUIRules::LayersFor(EVGInputMode::UI);
    TestTrue(TEXT("Pausa: só o menu"), Pause.bMenu && !Pause.bGame && !Pause.bOverlay && !Pause.bReading);

    const FVGUILayers Dead = VGUIRules::LayersFor(EVGInputMode::Dead);
    TestTrue(TEXT("Morte: tela de morte, legendas, sem HUD"), Dead.bDeath && Dead.bOverlay && !Dead.bGame);
    return true;
}

#endif
```

### Explicação das decisões

- **Uma regra pura decide as camadas**, e o teste fixa cada decisão de design ("Sônia é legendada enquanto ela lê") como propriedade. Se alguém esconder as legendas na leitura, o teste falha e obriga a pensar.
- **O layout se inscreve sozinho no controller**: o controller cria a HUD, mas não precisa lembrar de avisá-la. `OnInputModeChanged` (Cap. 16) existia exatamente para isso.
- **O controller é dono do modo `UI`** e expõe intenções (`OpenPauseMenu`, `ClosePauseMenu`). Widgets chamam intenções; a pilha valida a ordem.
- **Opções em `UGameUserSettings`**, que a engine já tem e já salva em `.ini`, com resolução e escalabilidade junto. Subclassar é o degrau "já existe".
- **CVars com `ECVF_SetByGameSetting`**: o console de desenvolvimento ainda consegue sobrescrever (prioridade maior), e a opção do jogo não briga com o `DefaultEngine.ini`.
- **Opções aplicadas na hora, por um delegate nativo**, sem reiniciar nada. A legenda escuta; a câmera e as luzes leem as CVars quando precisam.
- **A legenda não controla o tempo**: ela mostra o que o subsistema de diálogo diz e esconde quando ele diz. O tempo de leitura é regra do diálogo (Cap. 44).
- **`HitTestInvisible` em tudo que é só informação**: legendas e HUD nunca roubam um clique do menu nem o foco do controle.

---

## Projeto Vigília — a HUD formal e as opções

### Do provisório ao definitivo

| Provisório | Final | Camada | O que mudou |
|---|---|---|---|
| `WBP_Legenda` (Cap. 44) | `WBP_Legenda` (pai: `UVGSubtitleWidget`) | Sobreposição | Opções de tamanho, fundo e nomes; ícone de rádio |
| `WBP_RespostasRadio` (Cap. 44) | Igual, com a mesma escala de fonte e a barra de tempo consultada por frame | Sobreposição | Segue as opções da legenda |
| `WBP_PromptInteracao` (Cap. 19) | `WBP_Prompt` | Jogo | Tecla do mapeamento atual; a inscrição por possessão continua (Cap. 19) |
| Texto de munição (Cap. 20) | `WBP_Municao` | Jogo | Só com arma na mão; some depois de 3 s sem mudança |
| HUD de objetivos (Cap. 31) | **Removida**; `WBP_AvisoObjetivo` (3 s ao mudar de etapa) | Jogo | Sem lista permanente (Cap. 50) |
| `WBP_Diario` (Cap. 45) | Aba "Diário" do `WBP_Menu` | Menu | Título da quest e resumo da etapa, na voz de Helena |
| `WBP_Documento` (Cap. 48) | Igual, no `ReadingLayer` | Leitura | Estilos de papel por `PaperStyle` no *Text Style Set* |
| `WBP_Arquivo` (Cap. 48) | Aba "Arquivo" do `WBP_Menu` | Menu | Abre no leitor (empilha `Reading` sobre `UI`) |
| `WBP_Notificacoes` (Cap. 24) | Só em desenvolvimento, ligada por `IMC_Debug` | — | Fora da tela da jogadora |
| *Hit marker* (Cap. 27) | `WBP_Mira` | Jogo | Ponto só com arma; marcador de 0,15 s só no trecho dos vigias |
| Vinheta de dano (Caps. 21–22) | `M_PP_Dano`, dirigido pela HUD a partir de `OnHealthChanged` | Jogo (pós) | Some com a regeneração; com `CameraMotion` baixo, sem pulsar |
| — | LED da lanterna (Cap. 53) | Mundo (diegético) | Carga e prontidão da sobrecarga; fixo em vermelho sem flicker |
| — | `WBP_Morte` | Morte | "Continuar" chama `RequestRespawn` (Cap. 22) |
| — | `WBP_Opcoes`, `WBP_PrimeiraVez` (brilho + legendas) | Menu | `bFirstRunDone` |

O `BP_VGPlayerController` perde a criação do prompt e o HUD perde a criação de legenda e respostas: tudo está no `WBP_HUD`. O inventário de dores do Interlúdio não tinha uma dor de UI, mas o Capítulo 76 tem um *must* de "legendas e opções de acessibilidade" (escopo MoSCoW): está cumprido para o setor 1.

### A primeira vez

Na primeira execução (`bFirstRunDone` falso), antes do Pátio, a `WBP_PrimeiraVez` mostra duas coisas, e só duas: a calibração de brilho (uma imagem com três símbolos em cinzas escuros; "ajuste até o da esquerda quase sumir") e as legendas (ligadas, com a prévia do tamanho). Depois, `SaveSettings()` e o jogo começa. Todo o resto está no menu. (🔁 No Cap. 83, o menu principal chama `DetectQualityOnce` antes desta tela, e a primeira vez já começa no preset certo para a máquina.)

### O teste da acessibilidade

Jogue o setor 1 inteiro com: legendas no maior tamanho, movimento de câmera em 0%, "reduzir luzes piscando" ligado e FOV em 110°. Responda no `DEVLOG.md`: o susto ainda funciona? Alguma informação foi perdida (algo que só o flicker comunicava)? As legendas cabem na tela em duas linhas (Cap. 44) com o tamanho máximo? Se a resposta a qualquer uma for ruim, o problema é de design, não da opção.

---

## Decisões arquiteturais

1. **Ordem de preferência diegético > meta > espacial > não diegético**, com acessibilidade acima de imersão.
2. **Um layout raiz com cinco camadas** cuja visibilidade deriva só do modo no topo (`VGUIRules::LayersFor`, testada).
3. **Widgets não empilham modos**: pedem ao dono (controller, leitor, sistema de morte).
4. **Sem lista de objetivos, sem números de vida, sem mira sem arma**; marcador de acerto só no trecho dos vigias.
5. **Opções em `UVGGameUserSettings`**, aplicadas na hora por CVars e por um delegate; os donos dos sistemas leem.
6. **Legendas ligadas por padrão**, oferecidas antes do jogo, junto com a calibração de brilho.
7. **"Reduzir luzes piscando" vale para o jogo inteiro**, e o susto precisa funcionar com ela.
8. **CommonUI não adotado agora**; reavaliar se o alvo for console.

---

## Armadilhas

- **Widget empilhando ou desempilhando modo de input.**
- **Cada sistema criando o seu widget**, com regras de visibilidade espalhadas.
- ***Property bindings* por frame** para o que muda por evento.
- **Inscrição em delegates fora de `NativeConstruct`/`NativeDestruct`**, vazando a cada abertura.
- **Inscrever no pawn uma vez só**, e perder a HUD depois do respawn (Cap. 19).
- **Lista permanente de objetivos** num jogo que decidiu guiar pelo espaço.
- **Legenda sem fundo** num jogo escuro com lanterna em paredes claras.
- **Opção de flicker que não cobre tudo** (as luminárias param, a lanterna continua).
- **Prompt com a tecla escrita à mão**, que mente depois do remapeamento.
- **Elementos de informação capturando cliques** (`Visible` em vez de `HitTestInvisible`).
- **Pausa que não pausa as falas**, deixando a legenda correr sob o menu.

---

## Exercício

**Parte 1 — o esqueleto (1,5 h).** Acrescente os módulos ao `Build.cs`. Implemente `VGUIRules`, o teste e `UVGHUDLayout`. Crie o `WBP_HUD` com as cinco camadas e faça o 🔁 do controller (layout, `OpenPauseMenu`, `ClosePauseMenu`, `IA_Pausa`). Teste a pilha: pausar lendo; abrir um documento pelo arquivo; morrer com um documento aberto (o que acontece? por quê?).

**Parte 2 — a migração (2 h).** Migre os widgets provisórios conforme a tabela do Projeto. Remova a HUD de objetivos do Capítulo 31 e o texto de munição do 20; crie o `WBP_AvisoObjetivo` escutando `OnQuestChanged` (Cap. 45).

**Parte 3 — opções (2 h).** Implemente `UVGGameUserSettings` (e registre a classe no `DefaultEngine.ini`), `UVGSubtitleWidget` e a `WBP_Opcoes` com os grupos da seção 55.5 (deixe o remapeamento para a Parte 4). Mude o tamanho da legenda com Sônia falando: muda na hora?

**Parte 4 — remapeamento (1,5 h).** Com a documentação da sua versão, habilite as configurações de usuário do Enhanced Input, marque as ações remapeáveis e faça uma tela simples de remapeamento para `IA_Interact`, `IA_Lanterna` e `IA_SobrecargaLanterna`. Faça o `WBP_Prompt` mostrar a tecla atual.

**Parte 5 — a primeira vez e o teste de acessibilidade (1 h).** Faça a `WBP_PrimeiraVez` e jogue o setor 1 com as quatro opções extremas da seção do Projeto.

---

## Desafio — o diário na voz de Helena

O diário (Cap. 45) mostra o título da quest e o resumo da etapa. O Capítulo 48 propôs um caderno de perita com anotações de Helena. Junte os dois: o diário passa a ser **o caderno**.

1. Cada etapa de quest ganha um texto curto (até 25 palavras) **na voz de Helena**, em vez de um resumo neutro ("Os disjuntores estão no subsolo. O livro do turno C tinha uma ordem. Não confio nessa usina."). Onde esse texto mora: na etapa da quest (`UVGQuestData`) ou num documento (`UVGDocumentData`)?
2. O caderno é **diegético** (Helena escrevendo num caderno, aberto no modo `Reading`) ou **não diegético** (uma aba de menu)? Pense na pilha: se é diegético, quem empilha o modo? E o mundo para?
3. O texto pode **errar**? Uma Helena que anota "a sala de controle deve estar vazia" antes do final é narrativa (Cap. 47). Registre no `DEVLOG.md` o que você decidiu e um teste com alguém: a pessoa usou o caderno para saber o que fazer, ou para entender a história?

---

## Uso de IA

1. **Para auditar a HUD:**
   > "Esta é a lista de elementos de interface de um FPS de terror (abaixo: elemento, informação, quando aparece, tipo diegético/meta/espacial/não diegético). Para cada um: a informação poderia subir na ordem diegético > meta > espacial > não diegético? Ele precisa estar na tela o tempo todo? Algum compete com a escuridão ou com a legenda? [lista]"

2. **Para revisar acessibilidade:**
   > "Aqui está a tela de opções de um jogo de terror em primeira pessoa (abaixo). Compare com as Game Accessibility Guidelines nos níveis básico e intermediário: o que está faltando, o que está mal resolvido e o que é mais importante para um jogo com luzes piscando, sustos sonoros e muito escuro. Ordene por impacto. [opções]"

3. **Para testar a pilha de modos com a UI:**
   > "Uma pilha de modos de input tem Exploration (base), Reading, Cinematic, UI e Dead, com a regra 'quem empilha é dono do nível'. Widgets não empilham modos; o controller é dono de UI, o leitor de documentos é dono de Reading, o sistema de morte é dono de Dead e as cinemáticas são donas de Cinematic. Liste 10 sequências de eventos com interrupções (pausar lendo, morrer pausado, uma cena começando com o menu aberto...) e, para cada uma, diga o estado da pilha depois e se alguma operação viola a regra."

**Cuidado específico:** a IA tende a propor UI "completa": minimapa, barra de vida, lista de objetivos, marcadores, porque esse é o padrão estatístico dos jogos. Num jogo de terror, cada um desses é uma decisão contra a experiência. Peça a ela para justificar a **presença** de cada elemento, não só a forma; e confira qualquer API de UMG, de Enhanced Input User Settings ou de CommonUI na documentação da sua versão, porque todas mudaram ao longo do UE5.

---

## Checklist

- [ ] Sei o modelo do UMG (árvore, slots, âncoras, `BindWidget`, ciclo de vida) e evito *bindings* por frame.
- [ ] Sei classificar elementos em diegético, meta, espacial e não diegético, e a ordem de preferência da Vigília.
- [ ] A HUD da Vigília é um layout com cinco camadas derivadas do modo, e a regra está testada.
- [ ] Nenhum widget empilha modos; o controller é dono do menu de pausa.
- [ ] Os widgets provisórios dos Caps. 19–48 foram migrados ou removidos.
- [ ] As opções de acessibilidade existem, valem na hora e cobrem o jogo inteiro (inclusive o flicker do susto).
- [ ] O prompt mostra a tecla remapeada.
- [ ] Sei o que o CommonUI oferece e por que a Vigília não o adotou ainda.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **UMG UI Designer** (*widget blueprints*, âncoras, *Rich Text Block*), **Game User Settings**, **Enhanced Input** (incluindo as configurações de usuário para remapeamento) e **Common UI Plugin**.
- **Game Accessibility Guidelines** (gameaccessibilityguidelines.com): o guia de referência citado desde o Capítulo 44, com recomendações por nível.
- **GDC Vault** (gdcvault.com): palestras sobre interfaces diegéticas e sobre acessibilidade em jogos, incluindo apresentações de estúdios grandes sobre suas opções de acessibilidade (confira títulos e autores lá).
- **Jesse Schell, *The Art of Game Design*** — o capítulo sobre interface.

---

## Estado do Livro (fim da Parte VII)

- **Capítulos concluídos:** Introdução; Caps. 1–55 (Partes I–VII); Interlúdio I.
- **Projetos:** 1 a 6 concluídos; a Vigília com o setor 1 em qualidade de produção (espaço com documento de nível, luz, som, animação, efeitos e interface) e os setores 2 e 3 em blockout jogável.
- **Conceitos consolidados na Parte VII:**
  - level design como sistema: métricas, guiar sem setas, gates, pacing espacial, espaços de horror, documento de nível;
  - luz como composição e mecânica, com uma linguagem que não mente; a lanterna definitiva e a sobrecarga;
  - som como informação e como medo; mixagem derivada do estado; paridade som × ruído; o rádio de Sônia;
  - animação que lê e não decide; corpos que comunicam; física parcial;
  - efeitos com função; *pooling* e orçamento;
  - UI derivada da pilha de modos; acessibilidade como requisito.
- **Ponto de continuação:** Parte VIII, Capítulo 56 — Save Systems.

---

➡️ **Próximo:** [Parte VIII — Capítulo 56: Save Systems](../parte-08/cap-56-save-systems.md)
