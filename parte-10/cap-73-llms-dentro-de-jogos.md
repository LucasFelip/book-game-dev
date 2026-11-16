# Capítulo 73 — LLMs dentro de jogos

## Objetivo

Ao final deste capítulo você deve conseguir:

- desenhar a **arquitetura** de uma funcionalidade com modelo de linguagem dentro de um jogo, do pedido à reserva;
- raciocinar sobre **latência**, **custo**, ***streaming*** e **nuvem × modelo local**;
- nunca bloquear a game thread: `FHttpModule` assíncrono, callback na game thread, tempo de vida protegido, módulos no `Build.cs`;
- implementar **prazo, reserva e cache**, com o relógio certo;
- tratar **segurança de conteúdo** (classificação etária, *prompt injection* pela própria jogadora) e **privacidade** como requisitos de arquitetura;
- tornar o sistema **testável** apesar do não determinismo, entender por que texto gerado **não é localizável**, e isolar o protótipo **fora do build de release**.

---

## Contexto

Até o Capítulo 72, a IA generativa ficou do lado de fora do jogo: no seu editor, no seu terminal, nos seus documentos. A partir daqui ela entra no **runtime**, diante da jogadora. É uma mudança de natureza, e convém olhar para ela com os olhos de tudo o que o livro construiu.

O livro inteiro foi escrito contra um orçamento de **16,67 ms** por frame; um modelo de linguagem responde em **segundos**. O Capítulo 3 tratou o **determinismo** como propriedade valiosa; um modelo pode responder diferente à mesma pergunta. O Capítulo 44 decidiu que texto exibível é `FText`, localizável; o texto de um modelo nasce como `FString`, sem chave. E a Parte VI construiu uma narrativa em que cada fala foi escrita, revisada e condicionada a fatos; um modelo **pode dizer qualquer coisa**.

Nada disso proíbe usar um modelo dentro do jogo; isso define **como**. A pergunta é: **onde vale a pena, e como conter um componente lento, caro, não determinístico e que pode dizer qualquer coisa?** Quem trabalha com sistemas distribuídos a reconhece: é integrar um serviço instável no caminho crítico. Num jogo, o caminho crítico é a ficção.

Este capítulo constrói a **infraestrutura** (transporte, prazos, reserva, cache, orçamento, segurança, testes). O Capítulo 74 constrói a **semântica**: Sônia respondendo a perguntas livres, com a Game AI decidindo e o modelo só verbalizando.

---

## 73.1 Anatomia de uma chamada

```text
 JOGO (game thread)                              GATEWAY DO PROJETO               MODELO
 ─────────────────                              ──────────────────               ──────
 1. decide QUE precisa de texto
    (Game AI / narrativa decidem; Cap. 74)
 2. monta o pedido: instruções AUTORADAS
    + entrada NÃO CONFIÁVEL (sanitizada)
    + idioma + limite + versão do prompt
 3. cache? orçamento? ligado? ──não──► reserva autorada (no mesmo frame)
    │ sim
 4. HTTP assíncrono ─────────────────────────► 5. chave, moderação da entrada,
    (o frame segue; o jogo NÃO espera)            limite por instalação, log sem
                                                  dados pessoais ──────────────────► 6. gera tokens
                                                 7. moderação da saída ◄──────────────┘
 8. callback na game thread ◄─────────────────── resposta (ou erro)
    prazo vencido? → descarta (a reserva já tocou)
 9. VALIDA (formato, tamanho, vocabulário; Cap. 74)
10. entrega pelo canal do jogo (rádio, legenda) ── ou reserva autorada
```

Três ideias organizam o desenho. **O jogo decide; o modelo produz texto**: os passos 1, 2 e 9 são do jogo, e o modelo ocupa só o 6. **O gateway é do projeto** (seção 73.12). E **toda chamada termina**, com resposta, reserva ou silêncio, dentro de um prazo que o **jogo** define.

---

## 73.2 Latência: o frame e o segundo

Algumas ordens de grandeza, para calibrar a intuição. Não são medidas de nenhum serviço específico: meça as suas, porque elas dependem do modelo, do tamanho da saída, da infraestrutura e da carga.

| Coisa | Ordem de grandeza |
|---|---|
| Um frame a 60 FPS | 16,7 ms |
| Uma decisão de Utility (Cap. 40) | microssegundos |
| Ida e volta de rede até um servidor na mesma região | dezenas de milissegundos |
| Tempo até o primeiro token de um modelo | de centenas de milissegundos a segundos |
| Uma frase curta inteira | de frações de segundo a vários segundos |
| Quanto uma jogadora tolera de silêncio numa conversa | depende da ficção: num rádio com chiado, mais; numa conversa cara a cara, quase nada |

A última linha é a mais importante, e é de **design**, não de engenharia. Latência não se elimina; **se acomoda na ficção** ou **se esconde**. As técnicas, da mais barata à mais cara:

1. **Latência diegética.** Um rádio tem chiado, um clique de transmissão, a outra pessoa "procurando nos papéis". Um segundo e meio de estática soa natural num rádio e soaria absurdo numa conversa frente a frente. É uma das razões pelas quais o Capítulo 74 escolhe Sônia, e não um NPC na sala, para o protótipo.
2. **Saída curta.** O tempo de geração cresce com o tamanho da saída. Uma fala de rádio de 160 caracteres é barata; um parágrafo, não.
3. **Prazo, reserva e cache** (seção 73.7): a resposta atrasada é descartada e uma fala autorada toca no lugar.
4. **Pré-geração.** Gerar antes de precisar: offline (Capítulo 71) ou num momento calmo. Funciona quando a **entrada** é previsível; com texto livre da jogadora, não funciona.
5. ***Streaming*** (seção 73.3).

---

## 73.3 *Streaming* de tokens

Um modelo produz a resposta token a token, e o cliente pode receber os pedaços à medida que saem (*streaming*, em geral por respostas HTTP em partes ou *server-sent events*). O ganho é no **tempo até o primeiro token**: a legenda começa antes de a frase existir inteira.

O custo é que **validar uma frase pela metade é impossível**. Se a frase precisa passar por verificação de tamanho, vocabulário, nomes e conteúdo (Capítulo 74), ela precisa existir inteira antes de chegar à tela. Mostrar e depois apagar é pior do que esperar.

Para a Vigília, a conta fecha assim: falas curtas, validação obrigatória, latência acomodada pelo rádio, e por isso **sem *streaming***. Num jogo com narração longa e risco de conteúdo baixo, a conta pode fechar ao contrário.

⚠️ O suporte do módulo HTTP da Unreal a corpos de resposta recebidos em partes (delegates de progresso, *streams* de resposta) mudou ao longo das versões do UE5. Confira na documentação e nos headers da sua versão antes de desenhar algo que dependa disso. O módulo `WebSockets` é outra via para comunicação bidirecional contínua.

---

## 73.4 Custo

Um modelo na nuvem costuma ser cobrado por quantidade de texto processado (tokens de entrada e de saída). Um modelo local é cobrado em hardware, energia e tamanho de instalação. Os preços mudam rápido e variam muito entre fornecedores; este livro não cita nenhum. A forma do custo, porém, é estável:

```text
 custo por sessão = chamadas por sessão × (tokens de entrada + tokens de saída) × preço por token
 custo total      = custo por sessão × sessões             ← cresce com o SUCESSO do jogo
```

Quatro consequências de arquitetura:

- **As instruções são pagas em toda chamada.** Instruções enxutas são economia, não estética.
- **O custo cresce com o sucesso.** Num jogo vendido uma vez, quanto mais jogam, mais caro fica. A funcionalidade precisa de **orçamento** por minuto, no cliente e no gateway.
- **O serviço pode acabar**, e o jogo precisa continuar **completo** sem ele (Capítulo 75).
- **Cache é dinheiro.** Toda resposta reaproveitada é uma chamada a menos.

---

## 73.5 Nuvem × modelo local

| Critério | Modelo na nuvem (via API) | Modelo local (na máquina da jogadora) |
|---|---|---|
| **Latência** | Rede + fila do serviço; varia com a carga | Sem rede; depende da GPU/CPU da jogadora |
| **Custo** | Por chamada, recorrente, seu | Hardware da jogadora; tamanho do download |
| **Qualidade** | Em geral, modelos maiores | Modelos que cabem na memória disponível |
| **Disputa com o jogo** | Nenhuma no cliente | **Direta**: a inferência disputa GPU, VRAM e CPU com o renderizador e com o frame de 16,7 ms |
| **Privacidade** | O texto da jogadora sai do dispositivo | Fica no dispositivo |
| **Offline** | Não funciona | Funciona |
| **Plataformas** | Qualquer uma com rede | Depende de suporte de runtime e memória (consoles, máquinas modestas) |
| **Licença** | Termos de uso do serviço | Licença dos pesos; confira se permite distribuição em produto comercial |

A linha da **disputa com o jogo** costuma ser subestimada por quem vem de backend. A Vigília usa Lumen (Capítulo 51), e cada megabyte de VRAM e cada milissegundo de GPU já tem dono. Rodar inferência local na mesma GPU, durante o jogo, é colocar um segundo programa pesado dentro do orçamento de frame. Não é impossível, mas é uma decisão de performance que pertence aos Capítulos 58–60, não um detalhe de integração.

Há arquiteturas mistas: um modelo local pequeno para tarefas baratas (classificar uma pergunta numa lista fechada de intenções, Capítulo 74) e um modelo maior na nuvem só para o que precisa de qualidade. O desenho do gateway (seção 73.12) permite trocar isso sem mudar o jogo.

---

## 73.6 A game thread não espera

A regra é absoluta: **nenhuma chamada a modelo bloqueia a game thread.** Um bloqueio de três segundos é um jogo congelado por três segundos: sem render, sem input, sem áudio atualizado, e, no PIE, um editor travado.

O antipadrão aparece com frequência em código sugerido por IA, porque é o padrão mais comum em scripts:

```cpp
// ❌ NUNCA: espera ativa na game thread. O jogo congela até a resposta chegar.
Request->ProcessRequest();
while (Request->GetStatus() == EHttpRequestStatus::Processing)
{
    FPlatformProcess::Sleep(0.01f);
}
```

O padrão certo na Unreal é o **assíncrono com callback**: `FHttpModule::Get().CreateRequest()` cria o pedido, `OnProcessRequestComplete()` recebe o delegate de conclusão, e `ProcessRequest()` **volta imediatamente**. O módulo HTTP processa o pedido em segundo plano e, **por padrão**, chama o delegate na **game thread**, durante o tick do próprio módulo. ⚠️ Confira em `Interfaces/IHttpRequest.h` da sua versão a política de thread dos delegates: versões recentes permitem concluir em outra thread. O código deste capítulo **afirma** a suposição com `check(IsInGameThread())`, para que uma mudança de política vire um erro visível, e não uma corrida silenciosa.

Dois cuidados de tempo de vida, que valem para qualquer callback assíncrono:

- **Quem pediu pode não existir mais** quando a resposta chegar: a jogadora trocou de nível, o subsistema de mundo foi destruído. O callback precisa estar ligado de forma **fraca** (`BindUObject`, `CreateWeakLambda`): se o objeto morreu, o delegate não executa.
- **A resposta pode chegar depois do prazo**, quando a reserva já tocou. O callback precisa reconhecer um pedido **já resolvido** e descartá-lo.

E um cuidado de build: os módulos `HTTP` e `Json` entram no `Vigilia.Build.cs` neste capítulo, em que passam a ser usados (seção de implementação). Sem eles, o erro aparece no **link**, como o Capítulo 7 avisou.

> 🌉 **Ponte:** é o mesmo raciocínio de não bloquear a *event loop* de um servidor assíncrono, ou a thread de UI de um app: a chamada lenta vira uma *future*, e a continuação roda quando o resultado chega.
>
> 🧱 **Onde a ponte cai:** num servidor, a continuação roda "quando der". No jogo, ela precisa rodar **na game thread**, e o mundo pode ter mudado inteiro entre o pedido e a resposta (outro nível, outra fase do Diretor, outros fatos). A continuação precisa reconferir o mundo antes de agir.

---

## 73.7 Prazo, reserva e cache

**Prazo.** Cada pedido tem um prazo definido pelo **jogo**, independente do *timeout* da camada de rede. O *timeout* HTTP protege conexões; o prazo do jogo protege a **ficção**. A pergunta é "quanto tempo esta fala continua fazendo sentido?", e a resposta, para uma pergunta ao rádio, é da ordem de alguns segundos.

**Em que relógio?** O Capítulo 6 exige que cada sistema declare o seu. O prazo de rede é medido em **relógio de parede** (`FPlatformTime::Seconds`): a rede não pausa quando o jogo pausa e não acelera em câmera lenta. Se a jogadora pausar no meio de um pedido, o prazo pode vencer durante a pausa; a reserva entra na fila do rádio, que mede o tempo no relógio de **áudio** (Capítulo 44) e, portanto, espera a pausa acabar. Os dois relógios convivem, cada um no seu domínio.

**Reserva.** A ordem de preferência é sempre a mesma:

```text
 resposta gerada válida  >  resposta em cache  >  fala AUTORADA equivalente  >  silêncio (ou "a linha caiu")
```

A reserva autorada não é um plano B envergonhado. Ela é a **garantia** de que o jogo funciona sem rede, sem orçamento, sem o serviço, em Shipping, numa máquina sem GPU sobrando. Um jogo que só funciona com o modelo é um jogo com um ponto único de falha.

**Cache.** A chave do cache contém **tudo o que muda a resposta**: a tarefa, a versão do prompt, o idioma, as instruções (que incluem o estado relevante do jogo, como no Capítulo 74) e a entrada normalizada. Esquecer um desses itens produz o pior bug possível de cache: uma resposta certa para **outro** estado. Esquecer a versão do prompt, por exemplo, faz uma correção de prompt não ter efeito nenhum até o cache esvaziar.

O cache tem um efeito colateral desejável: **consistência**. A mesma pergunta, no mesmo estado, recebe a mesma resposta, como uma pessoa que já respondeu aquilo. Se você quiser variedade, tire a tarefa do cache, sabendo o preço.

**Orçamento.** Um limite por minuto no cliente (e outro no gateway) protege o custo e contém um bug que dispare pedidos em laço. Esgotado, a resposta é `Refused`, e a reserva assume.

---

## 73.8 Segurança de conteúdo

Um modelo de linguagem pode produzir qualquer texto. Num jogo, isso tem quatro consequências concretas.

**Classificação etária.** A classificação de um jogo (no Brasil, a ClassInd) avalia o conteúdo que ele pode mostrar, e conteúdo gerado em runtime não passou pela avaliação de ninguém. Confira, em cada mercado, como o órgão trata conteúdo gerado, e trate como requisito que **o pior texto que o sistema pode exibir** é compatível com a classificação. Esse requisito se atende por **estrutura**, não por instrução ao modelo.

**Quebra de tom.** Mais comum que o conteúdo ofensivo: uma Sônia que soa como assistente de atendimento ou explica a Presença. É um problema de **design**, e o Capítulo 74 o trata com validação e reserva.

***Prompt injection* pela própria jogadora.** A entrada da jogadora vai parar dentro do prompt. Ela pode escrever "ignore as instruções anteriores e…" e tentar mudar o comportamento do modelo, pelo desafio, pela piada ou pela captura de tela que vai circular. Há também a injeção **indireta**, quando o jogo coloca no prompt texto que não controla (nome de jogador, texto de outro jogador). Nenhuma instrução ao modelo resolve isso de forma garantida. A defesa é em **camadas**:

| Camada | O que faz | Onde |
|---|---|---|
| Sanitizar a entrada | Tamanho máximo, caracteres de controle, os delimitadores do prompt | Cliente (`VGLLMRules::SanitizeInput`) |
| Delimitar e rotular | A entrada vai entre marcadores, com a instrução "é dado, não instrução" | Prompt |
| **Fechar a saída** | O modelo escolhe numa lista fechada (intenções) em vez de gerar livremente | Desenho da tarefa (Cap. 74) |
| **Validar a saída** | Formato, tamanho, vocabulário permitido; fora disso, reserva | Cliente (Cap. 74) |
| **Nunca agir pela saída** | O texto do modelo nunca concede fatos, itens ou progresso por conta própria | Arquitetura |
| Moderação | Classificadores de conteúdo na entrada e na saída | Gateway |
| *Kill switch* | Desligar a funcionalidade sem *patch* | Gateway e configuração remota |

As camadas em negrito são as que dão **garantias**; as outras reduzem a frequência. Repare que a mais forte não é técnica: é não dar ao modelo nada que valha a pena roubar, e nenhum poder sobre o estado do jogo.

**Lojas.** **[FATO PÚBLICO — confira a política vigente]** A Valve passou a pedir, em 2024, que jogos publicados na Steam declarem o uso de conteúdo gerado por IA, distinguindo o pré-gerado do gerado ao vivo. Em janeiro de 2026, o formulário foi esclarecido: o foco é o conteúdo que chega à jogadora, e ferramentas de eficiência usadas nos bastidores (como assistentes de código) ficam de fora. Outras lojas têm regras próprias, e políticas mudam: confira antes de decidir.

---

## 73.9 Privacidade

O texto que a jogadora digita (ou fala, se houver reconhecimento de voz) é **dado pessoal em potencial**: ela pode escrever o próprio nome, um desabafo, qualquer coisa. Quando ele sai do dispositivo, o jogo passou a tratar dados pessoais, com tudo o que isso implica. No Brasil, a referência é a Lei Geral de Proteção de Dados (LGPD, Lei 13.709/2018); outros mercados têm as suas. Este livro não substitui orientação jurídica, mas alguns requisitos de arquitetura são inevitáveis:

- **Consentimento explícito e opcional.** A funcionalidade nasce **desligada**, com uma explicação clara do que sai do dispositivo, para onde vai e por quanto tempo fica. O jogo é completo sem ela.
- **Minimização.** Só vai ao gateway o necessário: a pergunta sanitizada e as instruções. Nenhum identificador de jogadora, de máquina ou de conta.
- **Logs sem conteúdo.** Métricas (latência, resultado, intenção escolhida) sim; o texto da jogadora, não, a menos que ela tenha consentido com isso especificamente (por exemplo, num playtest).
- **Retenção.** Saiba o que o **fornecedor** faz com o texto enviado (guarda? por quanto tempo? usa para treinar?). Está nos termos do serviço. Voz e público infantil pedem cuidados adicionais.

O cliente deste capítulo segue a minimização e os logs sem conteúdo por construção.

---

## 73.10 Determinismo e testabilidade

Um modelo amostra a próxima palavra de uma distribuição. Mesmo com parâmetros que reduzem a aleatoriedade, o mesmo pedido pode produzir respostas diferentes, entre execuções, entre máquinas e, principalmente, **entre versões do modelo**, que um serviço na nuvem pode trocar sem aviso. Isso quebra a forma como o livro vinha testando (entrada fixa, saída esperada) e exige três camadas de teste:

| Camada | O que testa | Como | Frequência |
|---|---|---|---|
| **Regras puras** | Sanitização, chave de cache, orçamento, *parsing*, validação, reserva | Testes de automação, sem rede (`VGLLMRules`, `VGRadioTalkRules`) | A cada build |
| **Integração sem rede** | O fluxo inteiro do jogo com uma resposta controlada | **Modo falso**: a CVar `vg.GenAI.Fake` responde com um arquivo, com latência configurável | Ao mexer no fluxo |
| **Avaliação** (*eval*) | A qualidade do modelo para a **sua** tarefa | Um conjunto fixo de entradas com resultados esperados (por exemplo, perguntas e intenções), rodado contra o gateway; mede-se taxa de acerto, de resposta inválida, de reserva, latência p50/p90 | A cada mudança de prompt, de modelo ou de versão do modelo |

A avaliação é estatística ("93% classificadas certo, 4% inválidas"), não binária, e é a única camada que detecta a troca silenciosa de modelo. Por isso a **versão do prompt** entra no pedido e nas métricas.

O modo falso é a costura que torna o resto testável: ele reproduz *timeout*, resposta malformada e resposta perfeita sem gateway, sem rede e sem custo, como um *stub* de serviço externo num teste de integração.

---

## 73.11 Localização do texto gerado

O texto da Vigília é `FText` desde o Capítulo 44, coletado pelo painel de localização, traduzido em *String Tables*, trocado quando o idioma muda. O texto de um modelo **não participa de nada disso**. Ele chega como `FString` em runtime e vira `FText` com `FText::FromString`, que produz um texto **sem chave e sem namespace**: o coletor de localização não o encontra, nenhum tradutor o revisa, e ele não muda quando a jogadora troca o idioma.

Consequências práticas:

- **Peça a resposta no idioma atual.** O pedido carrega a cultura corrente (`FInternationalization::Get().GetCurrentCulture()->GetName()`), e o prompt diz em que idioma responder.
- **O idioma entra na chave do cache.** Senão, quem trocar para inglês recebe a resposta guardada em português.
- **A validação é por idioma.** Regras como "nomes próprios só da lista permitida" (Capítulo 74) foram escritas pensando em português; em inglês, letras maiúsculas aparecem em outros lugares.
- **A reserva é localizada.** A fala autorada vem da *String Table*, traduzida.
- **Sem dublagem.** Síntese de voz é outra camada de latência, custo e licença (a voz de uma atriz não se clona sem autorização), e fica fora deste livro.

---

## 73.12 O gateway do projeto

O jogo não fala com a API de nenhum fornecedor. Ele fala com um serviço **do projeto**, com um contrato **do projeto**:

```text
 POST /v1/complete                        (contrato da Vigília, não de um fornecedor)

 pedido   { "task": "radio_talk", "prompt_version": 3,
            "instructions": "...", "input": "<<<...>>>",
            "culture": "pt-BR", "max_output_chars": 220 }

 resposta 200 { "text": "..." }
          4xx/5xx { "error": "budget" | "moderation" | "upstream" }

 O gateway:
   - guarda a chave do fornecedor (o jogo nunca tem chave nenhuma);
   - traduz o pedido para a API ou o runtime local da vez;
   - aplica moderação na entrada e na saída;
   - limita a taxa por instalação e por tarefa;
   - registra métricas SEM o texto da jogadora;
   - pode ser desligado sem patch do jogo (kill switch).
```

Para um engenheiro de backend, este é o pedaço mais familiar do capítulo, e o livro não mostra o código dele: é um microsserviço de um endpoint, na linguagem que você preferir. A parte que fala com o modelo depende do fornecedor ou do runtime escolhido; **leia a documentação atual**, porque formatos, limites e preços mudam rápido demais para um livro.

Para o protótipo, o gateway roda em `localhost`. Ele pode encaminhar para um modelo local (um runtime de modelos abertos rodando na sua máquina) ou para uma API na nuvem, com a chave numa variável de ambiente **do gateway**. O jogo não muda em nenhum dos casos.

Por que não pôr a chave no jogo e chamar o fornecedor direto? Porque **tudo o que vai no build é público**: uma chave num `.ini` ou num binário ofuscado é extraível, e a conta é sua.

---

## Estudo de caso: AI Dungeon — geração aberta e moderação depois

**[FATO PÚBLICO — confira a fonte]** *AI Dungeon* (Latitude, lançado em 2019) é uma aventura em texto em que o jogador escreve qualquer ação e um modelo de linguagem continua a história. Foi um dos primeiros jogos amplamente conhecidos construídos em torno de um modelo de linguagem. Em 2021, depois de casos de conteúdo gerado que violava as políticas da própria empresa, a Latitude introduziu filtros e moderação de conteúdo. A mudança gerou reação forte de parte da comunidade, com reclamações sobre bloqueios indevidos (falsos positivos) e sobre a possibilidade de revisão humana de histórias que os jogadores consideravam privadas.

**[INFERÊNCIA]** Com **entrada e saída abertas**, o espaço de conteúdo possível não tem fim, e só dá para moderar **depois**. Moderação depois do fato cobra duas vezes: em falsos positivos (a experiência quebra para quem não fez nada errado) e em privacidade (alguém precisa olhar o que foi escrito). E um modelo de segurança desenhado depois do produto colide com expectativas que o produto já criou.

**Lição para a Vigília:** o desenho de segurança vem **antes** da funcionalidade, e a ferramenta mais forte não é o filtro: é **fechar o espaço de saída**. Uma Sônia que só pode escolher entre sete intenções e parafrasear uma fala já aprovada pelos fatos (Capítulo 74) tem um pior caso pequeno o bastante para ser conhecido de antemão.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Chamada a modelo | Chamada a um serviço de terceiros lento, caro e instável | O "resultado certo" não é definido; é aceitável ou não, e às vezes isso depende do tom |
| Prazo + reserva + cache | *Timeout*, *fallback*, cache, *circuit breaker* (o seu repertório de resiliência) | A reserva é **conteúdo autorado** com voz e tradução, não um valor padrão |
| Gateway do projeto | *API gateway*, *backend for frontend*, *anti-corruption layer* (DDD) | Ele também faz moderação de conteúdo e protege uma ficção, não só um contrato |
| *Prompt injection* | Injeção de SQL, de comandos | Não existe "consulta parametrizada" que garanta a separação entre dado e instrução; a defesa é fechar a saída e não dar poder ao modelo |
| Avaliação (*eval*) | Testes de regressão de um modelo de ML | É a única camada que detecta a troca silenciosa do modelo pelo fornecedor |

Uma reserva genérica ("erro, tente novamente") é tão quebrada quanto uma resposta errada: no jogo, a resposta degradada precisa continuar **na ficção**.

---

## Unreal Engine: o que existe e o que não existe

**O que existe:**

- **Módulo `HTTP`** (`FHttpModule`, `IHttpRequest`, `IHttpResponse`): pedidos assíncronos com delegate de conclusão.
- **Módulo `Json`** (`FJsonObject`, `FJsonSerializer`). O `JsonUtilities` (conversão automática de `USTRUCT`) não é necessário: o contrato tem campos com nomes explícitos.
- **`UDeveloperSettings`**, **CVars** e ***cheats*** para configurar, ligar e depurar.
- **`FTSTicker`**, o ticker do núcleo, chamado na game thread a cada volta do loop, inclusive com o jogo pausado: o lugar natural para prazos em relógio de parede.
- **`FInternationalization`** (cultura atual) e o módulo **`WebSockets`**, se um dia houver comunicação contínua com o gateway.

**O que não existe** (como sistema de jogo, até onde este livro alcança): cliente de modelos pronto, moderação, gestão de prompts, avaliação. Há plugins da comunidade e de fornecedores; confira manutenção, termos e a documentação da sua versão, porque esse ecossistema muda depressa.

---

## Abordagens

| Critério | A. Cliente chama a API do fornecedor | **B. Cliente → gateway do projeto** | C. Modelo local dentro do processo do jogo | D. Só pré-geração offline |
|---|---|---|---|---|
| **Complexidade** | Baixa | Média: um serviço a mais | Alta: runtime de inferência, pesos, memória | Baixa |
| **Performance** | Rede + serviço | Rede + serviço (+ um salto) | Disputa GPU/VRAM/CPU com o frame | Nenhum custo em runtime |
| **Extensibilidade** | Presa a um fornecedor | Troca de modelo/fornecedor sem *patch* | Presa aos pesos distribuídos | — |
| **Manutenção** | **Chave no cliente: inaceitável** | Moderação, logs e *kill switch* num lugar | Atualizar é *patch* do jogo | Conteúdo revisado como qualquer outro |
| **Prototipação** | Rápida (e perigosa) | Rápida, com gateway em `localhost` | Lenta | Rápida |
| **Adequação à Vigília** | Não | **Sim, para o protótipo** | Não agora (orçamento de frame, Lumen) | **Sim, para tudo que vai no jogo** |

**Decisão:** **B** para o protótipo dos Capítulos 73–74, com o gateway em `localhost`, encaminhando para um modelo local ou na nuvem. **D** continua sendo o padrão para todo conteúdo que vai no jogo (Capítulos 71–72). **A** fica de fora por segurança, e **C** por performance, até que os Capítulos 58–60 e uma medição concreta digam o contrário.

---

## Implementação

O código mora numa pasta nova, `Source/Vigilia/GenAI/`. A pasta não estava na lista do projeto, e a criação é deliberada: tudo o que é IA generativa em runtime fica **num lugar só**, fácil de auditar, de excluir do build e, se o experimento for abandonado, de apagar.

### 1. Módulos e a *flag* de build

```csharp
// Vigilia.Build.cs — adições (Cap. 73)
PublicDependencyModuleNames.AddRange(new string[] { "HTTP", "Json" });

// IA generativa em runtime: compilada em Debug, Development e Test; FORA do Shipping.
// Ligá-la num Shipping é decisão de release (Cap. 84), não ajuste de build.
bool bWithGenAI = Target.Configuration != UnrealTargetConfiguration.Shipping;
PublicDefinitions.Add("VG_WITH_GENAI=" + (bWithGenAI ? "1" : "0"));
```

### 2. Configurações

```cpp
// Source/Vigilia/GenAI/VGGenAISettings.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VGGenAISettings.generated.h"

/** Project Settings → Vigília — IA generativa (protótipo). NADA secreto aqui: este .ini vai no build. */
UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Vigília — IA generativa (protótipo)"))
class VIGILIA_API UVGGenAISettings : public UDeveloperSettings
{
    GENERATED_BODY()

public:
    /** O gateway DO PROJETO (seção 73.12), nunca a API de um fornecedor. */
    UPROPERTY(Config, EditAnywhere, Category = "Gateway")
    FString GatewayUrl = TEXT("http://127.0.0.1:8787/v1/complete");

    /** Prazo padrão do jogo para uma resposta, em segundos de relógio de parede. */
    UPROPERTY(Config, EditAnywhere, Category = "Gateway", meta = (ClampMin = "0.5"))
    float DeadlineSeconds = 3.0f;

    UPROPERTY(Config, EditAnywhere, Category = "Budget", meta = (ClampMin = "1"))
    int32 MaxRequestsPerMinute = 6;

    /** 0 desliga o cache. */
    UPROPERTY(Config, EditAnywhere, Category = "Cache", meta = (ClampMin = "0"))
    int32 MaxCacheEntries = 64;
};
```

### 3. Tipos

```cpp
// Source/Vigilia/GenAI/VGLLMTypes.h
#pragma once

#include "CoreMinimal.h"

/** Como uma chamada terminou. Toda chamada termina em exatamente um destes. */
enum class EVGLLMResult : uint8
{
    Ok,       // resposta nova do gateway
    Cached,   // mesma tarefa, mesmo prompt, mesmo estado, mesma entrada
    Timeout,  // passou do prazo do JOGO; se a resposta vier depois, é descartada
    Failed,   // rede, HTTP fora de 2xx, corpo inválido
    Refused   // desligado (CVar, Shipping) ou orçamento esgotado
};

/** O que o jogo pede. O contrato é do PROJETO; o gateway traduz para o modelo da vez. */
struct FVGLLMRequest
{
    FName Task;                    // "radio_talk": separa prompts, limites e métricas no gateway
    int32 PromptVersion = 1;       // sobe quando o prompt muda: invalida o cache e separa medições
    FString Instructions;          // AUTORADAS (dados do jogo); nunca vêm da jogadora
    FString Input;                 // NÃO CONFIÁVEL, já passada por VGLLMRules::SanitizeInput
    FString Culture;               // idioma pedido para a resposta (ex.: "pt-BR")
    int32 MaxOutputChars = 200;
    float DeadlineSeconds = 0.0f;  // 0 = o padrão das configurações; relógio de PAREDE
};

struct FVGLLMResponse
{
    EVGLLMResult Result = EVGLLMResult::Failed;
    FString Text;
    double LatencySeconds = 0.0;
};

DECLARE_DELEGATE_OneParam(FVGLLMResponseDelegate, const FVGLLMResponse& /*Response*/);
```

### 4. Regras puras

```cpp
// Source/Vigilia/GenAI/VGLLMRules.h
#pragma once

#include "CoreMinimal.h"
#include "GenAI/VGLLMTypes.h"

/** Regras do cliente de LLM: sem rede, sem mundo, testáveis. */
namespace VGLLMRules
{
    /** Texto da jogadora → texto seguro para o prompt: sem caracteres de controle, espaços colapsados,
     *  sem os caracteres dos delimitadores (< e >), no máximo MaxChars. */
    FString SanitizeInput(const FString& Raw, int32 MaxChars);

    /** Tudo o que muda a resposta entra na chave: tarefa, versão do prompt, idioma, instruções, entrada. */
    FString MakeCacheKey(const FVGLLMRequest& Request);

    /** Janela deslizante de 60 s. true = pode gastar (e registra o gasto). */
    bool TryConsumeBudget(TArray<double>& RecentRequests, double Now, int32 MaxPerMinute);

    /** O corpo JSON do contrato do projeto (seção 73.12). */
    FString BuildRequestBody(const FVGLLMRequest& Request);

    /** {"text": "..."} → true e o texto. */
    bool ParseResponseBody(const FString& Body, FString& OutText);
}
```

```cpp
// Source/Vigilia/GenAI/VGLLMRules.cpp
#include "GenAI/VGLLMRules.h"

#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

FString VGLLMRules::SanitizeInput(const FString& Raw, int32 MaxChars)
{
    FString Out;
    bool bPendingSpace = false;
    for (int32 i = 0; i < Raw.Len() && Out.Len() < MaxChars; ++i)
    {
        const TCHAR C = Raw[i];
        if (C == TEXT('<') || C == TEXT('>'))
        {
            continue; // reservados aos delimitadores: a jogadora não fecha o próprio bloco
        }
        if (C < 32 || FChar::IsWhitespace(C))
        {
            bPendingSpace = !Out.IsEmpty(); // controle, quebra e tab viram UM espaço; nada no início
            continue;
        }
        if (bPendingSpace)
        {
            Out.AppendChar(TEXT(' '));
            bPendingSpace = false;
        }
        Out.AppendChar(C);
    }
    // Simplificação: corta por TCHAR; um caractere fora do plano básico pode ser partido no limite.
    return Out.Left(MaxChars).TrimEnd();
}

FString VGLLMRules::MakeCacheKey(const FVGLLMRequest& Request)
{
    // Atenção: FString compara SEM diferenciar maiúsculas, inclusive como chave de TMap.
    // "Onde fica?" e "onde fica?" caem na mesma entrada — aqui, é o que queremos.
    return FString::Printf(TEXT("%s|v%d|%s|%s|%s"), *Request.Task.ToString(), Request.PromptVersion,
                           *Request.Culture, *Request.Instructions, *Request.Input);
}

bool VGLLMRules::TryConsumeBudget(TArray<double>& RecentRequests, double Now, int32 MaxPerMinute)
{
    RecentRequests.RemoveAll([Now](double Time) { return Now - Time >= 60.0; });
    if (RecentRequests.Num() >= MaxPerMinute)
    {
        return false;
    }
    RecentRequests.Add(Now);
    return true;
}

FString VGLLMRules::BuildRequestBody(const FVGLLMRequest& Request)
{
    const TSharedRef<FJsonObject> Json = MakeShared<FJsonObject>();
    Json->SetStringField(TEXT("task"), Request.Task.ToString());
    Json->SetNumberField(TEXT("prompt_version"), Request.PromptVersion);
    Json->SetStringField(TEXT("instructions"), Request.Instructions);
    Json->SetStringField(TEXT("input"), Request.Input);
    Json->SetStringField(TEXT("culture"), Request.Culture);
    Json->SetNumberField(TEXT("max_output_chars"), Request.MaxOutputChars);

    FString Body;
    const TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Body);
    FJsonSerializer::Serialize(Json, Writer); // o serializador escapa aspas e quebras: nada de JSON com Printf
    return Body;
}

bool VGLLMRules::ParseResponseBody(const FString& Body, FString& OutText)
{
    TSharedPtr<FJsonObject> Json;
    const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Body);
    return FJsonSerializer::Deserialize(Reader, Json) && Json.IsValid()
        && Json->TryGetStringField(TEXT("text"), OutText);
}
```

### 5. O subsistema

```cpp
// Source/Vigilia/GenAI/VGLLMSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Containers/Ticker.h"
#include "GenAI/VGLLMTypes.h"
#include "Interfaces/IHttpRequest.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "VGLLMSubsystem.generated.h"

/**
 * Cliente de LLM do protótipo: assíncrono, com prazo, cache, orçamento e modo falso.
 * Relógio: PAREDE (FPlatformTime::Seconds) — a rede não pausa nem dilata com o jogo.
 * Não existe em Shipping (VG_WITH_GENAI = 0): quem usa trata nullptr como "desligado".
 */
UCLASS()
class VIGILIA_API UVGLLMSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    virtual bool ShouldCreateSubsystem(UObject* Outer) const override;
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;

    static UVGLLMSubsystem* Get(const UObject* WorldContextObject);

    /** vg.GenAI.Enabled (e VG_WITH_GENAI). */
    bool IsEnabled() const;

    /**
     * NUNCA bloqueia. OnDone é chamado na game thread exatamente uma vez (Ok, Cached, Timeout,
     * Failed ou Refused), às vezes antes de Complete retornar (cache, recusa).
     * Exceção: no encerramento do jogo, pedidos pendentes são descartados sem aviso.
     */
    void Complete(const FVGLLMRequest& Request, FVGLLMResponseDelegate OnDone);

    FString DescribeForDebug() const;

private:
    struct FPending
    {
        FVGLLMRequest Request;
        FVGLLMResponseDelegate OnDone;
        FString CacheKey;
        TSharedPtr<IHttpRequest, ESPMode::ThreadSafe> Http; // vazio no modo falso
        double StartedAt = 0.0;
        double Deadline = 0.0;
    };

    void Send(uint64 Id);
    void HandleHttpComplete(FHttpRequestPtr HttpRequest, FHttpResponsePtr HttpResponse,
                            bool bConnectedSuccessfully, uint64 Id);
    bool TickDeadlines(float DeltaTime);
    void Resolve(uint64 Id, EVGLLMResult Result, const FString& Text);
    void RememberInCache(const FString& Key, const FString& Text);

    TMap<uint64, FPending> Pending;
    TMap<FString, FString> Cache;
    TArray<FString> CacheOrder;     // Simplificação: FIFO, não LRU; basta para dezenas de entradas
    TArray<double> RecentRequests;  // orçamento: janela de 60 s
    uint64 NextId = 1;
    FTSTicker::FDelegateHandle TickerHandle;

    int32 Counts[5] = {};           // por EVGLLMResult, para vg.Debug.GenAI
    double LastLatency = 0.0;
};
```

```cpp
// Source/Vigilia/GenAI/VGLLMSubsystem.cpp
#include "GenAI/VGLLMSubsystem.h"

#include "Core/VGLog.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "GenAI/VGGenAISettings.h"
#include "GenAI/VGLLMRules.h"
#include "HAL/IConsoleManager.h"
#include "HttpModule.h"
#include "Interfaces/IHttpResponse.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

static TAutoConsoleVariable<bool> CVarVGGenAIEnabled(
    TEXT("vg.GenAI.Enabled"), false,
    TEXT("Liga a IA generativa em runtime (protótipo; não existe em Shipping)."), ECVF_Default);

static TAutoConsoleVariable<bool> CVarVGGenAIFake(
    TEXT("vg.GenAI.Fake"), false,
    TEXT("Sem rede: responde com Saved/GenAI/fake_reply.txt depois de vg.GenAI.FakeLatency s."), ECVF_Default);

static TAutoConsoleVariable<float> CVarVGGenAIFakeLatency(
    TEXT("vg.GenAI.FakeLatency"), 0.8f,
    TEXT("Latência do modo falso, em segundos (acima do prazo = testa o Timeout)."), ECVF_Default);

static TAutoConsoleVariable<bool> CVarVGDebugGenAI(
    TEXT("vg.Debug.GenAI"), false,
    TEXT("Mostra pedidos pendentes, resultados por tipo, última latência e cache."), ECVF_Default);

bool UVGLLMSubsystem::ShouldCreateSubsystem(UObject* Outer) const
{
    // Em Shipping, o subsistema não existe, e o código de rede de Send nem é compilado.
    return VG_WITH_GENAI != 0 && Super::ShouldCreateSubsystem(Outer);
}

void UVGLLMSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);
    // Ticker do núcleo: game thread, a cada volta do loop, inclusive com o jogo pausado.
    TickerHandle = FTSTicker::GetCoreTicker().AddTicker(
        FTickerDelegate::CreateUObject(this, &UVGLLMSubsystem::TickDeadlines), 0.1f);
}

void UVGLLMSubsystem::Deinitialize()
{
    FTSTicker::GetCoreTicker().RemoveTicker(TickerHandle);
    for (TPair<uint64, FPending>& Pair : Pending)
    {
        if (Pair.Value.Http.IsValid())
        {
            Pair.Value.Http->OnProcessRequestComplete().Unbind();
            Pair.Value.Http->CancelRequest();
        }
    }
    Pending.Empty(); // o jogo está acabando: ninguém é avisado
    Super::Deinitialize();
}

UVGLLMSubsystem* UVGLLMSubsystem::Get(const UObject* WorldContextObject)
{
    const UWorld* World = GEngine
        ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull)
        : nullptr;
    const UGameInstance* GameInstance = World ? World->GetGameInstance() : nullptr;
    return GameInstance ? GameInstance->GetSubsystem<UVGLLMSubsystem>() : nullptr;
}

bool UVGLLMSubsystem::IsEnabled() const
{
    return VG_WITH_GENAI != 0 && CVarVGGenAIEnabled.GetValueOnGameThread();
}

void UVGLLMSubsystem::Complete(const FVGLLMRequest& Request, FVGLLMResponseDelegate OnDone)
{
    check(IsInGameThread());
    const UVGGenAISettings* Settings = GetDefault<UVGGenAISettings>();
    const double Now = FPlatformTime::Seconds();

    const uint64 Id = NextId++;
    FPending& Entry = Pending.Add(Id);
    Entry.Request = Request;
    Entry.OnDone = MoveTemp(OnDone);
    Entry.CacheKey = VGLLMRules::MakeCacheKey(Request);
    Entry.StartedAt = Now;
    Entry.Deadline = Now + (Request.DeadlineSeconds > 0.0f ? Request.DeadlineSeconds : Settings->DeadlineSeconds);

    // Entry não é usada depois de Resolve/Send: o mapa pode mudar dentro do callback.
    if (!IsEnabled())
    {
        Resolve(Id, EVGLLMResult::Refused, FString());
    }
    else if (const FString* Hit = Cache.Find(Entry.CacheKey))
    {
        Resolve(Id, EVGLLMResult::Cached, *Hit);
    }
    else if (!VGLLMRules::TryConsumeBudget(RecentRequests, Now, Settings->MaxRequestsPerMinute))
    {
        Resolve(Id, EVGLLMResult::Refused, FString()); // orçamento: a reserva autorada assume
    }
    else
    {
        Send(Id);
    }
}

void UVGLLMSubsystem::Send(uint64 Id)
{
#if VG_WITH_GENAI
    FPending& Entry = Pending.FindChecked(Id);
    if (CVarVGGenAIFake.GetValueOnGameThread())
    {
        return; // modo falso: TickDeadlines responde depois de vg.GenAI.FakeLatency, sem rede
    }
    const TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Http = FHttpModule::Get().CreateRequest();
    Http->SetURL(GetDefault<UVGGenAISettings>()->GatewayUrl);
    Http->SetVerb(TEXT("POST"));
    Http->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
    Http->SetContentAsString(VGLLMRules::BuildRequestBody(Entry.Request));
    // O delegate liga o pedido ao SUBSISTEMA (vida longa) e ao Id; quem pediu é avisado em Resolve.
    Http->OnProcessRequestComplete().BindUObject(this, &UVGLLMSubsystem::HandleHttpComplete, Id);
    Entry.Http = Http;
    Http->ProcessRequest(); // volta na hora; a resposta chega num frame futuro
#else
    Resolve(Id, EVGLLMResult::Refused, FString());
#endif
}

void UVGLLMSubsystem::HandleHttpComplete(FHttpRequestPtr /*HttpRequest*/, FHttpResponsePtr HttpResponse,
                                         bool bConnectedSuccessfully, uint64 Id)
{
    // O módulo HTTP conclui na game thread por padrão (⚠️ confira a política de thread dos delegates
    // em IHttpRequest.h na sua versão). Se este check falhar, a política mudou: não toque em UObjects
    // aqui; leve o trabalho para a game thread com AsyncTask(ENamedThreads::GameThread, ...).
    check(IsInGameThread());

    FString Text;
    const bool bOk = bConnectedSuccessfully && HttpResponse.IsValid()
        && EHttpResponseCodes::IsOk(HttpResponse->GetResponseCode())
        && VGLLMRules::ParseResponseBody(HttpResponse->GetContentAsString(), Text);
    Resolve(Id, bOk ? EVGLLMResult::Ok : EVGLLMResult::Failed, Text); // já resolvido pelo prazo? Resolve ignora
}

bool UVGLLMSubsystem::TickDeadlines(float /*DeltaTime*/)
{
    const double Now = FPlatformTime::Seconds();
    const double FakeLatency = CVarVGGenAIFakeLatency.GetValueOnGameThread();

    // Junta primeiro, resolve depois: Resolve mexe em Pending e chama código de fora.
    TArray<uint64> Expired;
    TArray<uint64> FakeReady;
    for (const TPair<uint64, FPending>& Pair : Pending)
    {
        if (Now >= Pair.Value.Deadline)
        {
            Expired.Add(Pair.Key);
        }
        else if (!Pair.Value.Http.IsValid() && Now - Pair.Value.StartedAt >= FakeLatency)
        {
            FakeReady.Add(Pair.Key);
        }
    }

    for (const uint64 Id : Expired)
    {
        TSharedPtr<IHttpRequest, ESPMode::ThreadSafe> Http;
        if (const FPending* Entry = Pending.Find(Id))
        {
            Http = Entry->Http;
        }
        Resolve(Id, EVGLLMResult::Timeout, FString()); // primeiro sai de Pending...
        if (Http.IsValid())
        {
            Http->CancelRequest(); // ...depois cancela: o callback que vier encontra o Id resolvido
        }
    }

    if (!FakeReady.IsEmpty())
    {
        FString FakeReply;
        FFileHelper::LoadFileToString(FakeReply, *(FPaths::ProjectSavedDir() / TEXT("GenAI/fake_reply.txt")));
        for (const uint64 Id : FakeReady)
        {
            Resolve(Id, EVGLLMResult::Ok, FakeReply);
        }
    }

    if (CVarVGDebugGenAI.GetValueOnGameThread() && GEngine)
    {
        GEngine->AddOnScreenDebugMessage(static_cast<uint64>(GetUniqueID()), 0.2f, FColor::Orange, DescribeForDebug());
    }
    return true; // continua no ticker
}

void UVGLLMSubsystem::Resolve(uint64 Id, EVGLLMResult Result, const FString& Text)
{
    FPending Done;
    if (!Pending.RemoveAndCopyValue(Id, Done))
    {
        return; // já resolvido: a resposta que chega depois do prazo é descartada, como a fala atrasada do Cap. 44
    }

    FVGLLMResponse Response;
    Response.Result = Result;
    Response.Text = Text;
    Response.LatencySeconds = FPlatformTime::Seconds() - Done.StartedAt;

    if (Result == EVGLLMResult::Ok)
    {
        RememberInCache(Done.CacheKey, Text);
    }
    ++Counts[static_cast<int32>(Result)];
    LastLatency = Response.LatencySeconds;
    // Privacidade (seção 73.9): tarefa, resultado e latência. NUNCA a entrada da jogadora.
    UE_LOG(LogVigilia, Verbose, TEXT("GenAI %s: resultado %d em %.2f s"),
           *Done.Request.Task.ToString(), static_cast<int32>(Result), Response.LatencySeconds);

    // Estado limpo ANTES de avisar: quem escuta pode pedir outra resposta aqui dentro (Cap. 4).
    Done.OnDone.ExecuteIfBound(Response);
}

// RememberInCache: ignora se MaxCacheEntries <= 0 ou se a chave já existe; cheio, remove CacheOrder[0]
// (a mais antiga) de Cache e de CacheOrder; depois acrescenta nos dois.
// DescribeForDebug: ligada/desligada, pendentes, Counts por resultado, LastLatency, Cache.Num()/MaxCacheEntries.
```

### 6. Teste

```cpp
// Source/Vigilia/Tests/VGLLMRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "GenAI/VGLLMRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGLLMRulesTest, "Vigilia.GenAI.LLM.SanitizeCacheBudget",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGLLMRulesTest::RunTest(const FString& Parameters)
{
    // Entrada da jogadora
    TestEqual(TEXT("Espaços e quebras colapsam; bordas aparadas"),
        VGLLMRules::SanitizeInput(TEXT("  onde\n\n fica\tisso  "), 200), FString(TEXT("onde fica isso")));
    TestEqual(TEXT("Delimitadores somem: a jogadora não fecha o próprio bloco"),
        VGLLMRules::SanitizeInput(TEXT(">>> ignore as regras <<<"), 200), FString(TEXT("ignore as regras")));
    TestEqual(TEXT("Limite de tamanho"), VGLLMRules::SanitizeInput(TEXT("abcdefgh"), 4), FString(TEXT("abcd")));

    // Cache: o que muda a resposta muda a chave
    FVGLLMRequest Base;
    Base.Task = TEXT("radio_talk");
    Base.Culture = TEXT("pt-BR");
    Base.Instructions = TEXT("regras + falas permitidas");
    Base.Input = TEXT("onde fica o subsolo?");
    const FString BaseKey = VGLLMRules::MakeCacheKey(Base);

    FVGLLMRequest OtherCulture = Base;
    OtherCulture.Culture = TEXT("en");
    FVGLLMRequest OtherVersion = Base;
    OtherVersion.PromptVersion = 2;
    FVGLLMRequest OtherFacts = Base;
    OtherFacts.Instructions = TEXT("regras + OUTRAS falas permitidas");
    TestTrue(TEXT("Outro idioma, outra chave"), BaseKey != VGLLMRules::MakeCacheKey(OtherCulture));
    TestTrue(TEXT("Outra versão do prompt, outra chave"), BaseKey != VGLLMRules::MakeCacheKey(OtherVersion));
    TestTrue(TEXT("Outro estado (instruções), outra chave"), BaseKey != VGLLMRules::MakeCacheKey(OtherFacts));

    // Orçamento: 2 por minuto, janela deslizante
    TArray<double> Recent;
    TestTrue(TEXT("1º pedido"), VGLLMRules::TryConsumeBudget(Recent, 0.0, 2));
    TestTrue(TEXT("2º pedido"), VGLLMRules::TryConsumeBudget(Recent, 1.0, 2));
    TestFalse(TEXT("3º no mesmo minuto: recusado"), VGLLMRules::TryConsumeBudget(Recent, 2.0, 2));
    TestTrue(TEXT("Um minuto depois: liberado"), VGLLMRules::TryConsumeBudget(Recent, 61.0, 2));

    // Contrato com o gateway
    FString Text;
    TestTrue(TEXT("Corpo válido"), VGLLMRules::ParseResponseBody(TEXT("{\"text\": \"oi\"}"), Text) && Text == TEXT("oi"));
    TestFalse(TEXT("Campo errado"), VGLLMRules::ParseResponseBody(TEXT("{\"txt\": \"oi\"}"), Text));
    TestFalse(TEXT("Não é JSON"), VGLLMRules::ParseResponseBody(TEXT("tempo esgotado"), Text));
    TestTrue(TEXT("O pedido sai como JSON com a tarefa"), VGLLMRules::BuildRequestBody(Base).Contains(TEXT("\"task\"")));
    return true;
}

#endif
```

### Explicação das decisões

- **`UGameInstanceSubsystem`.** O cliente sobrevive à troca de nível (o cache e o orçamento também), como o estado narrativo do Capítulo 46. Quem consome (um subsistema de mundo, no Capítulo 74) morre com o nível, e é por isso que o consumidor se liga de forma fraca.
- **Duas travas, de natureza diferente.** `VG_WITH_GENAI` decide se o código **existe** (compilação); `vg.GenAI.Enabled` decide se ele **roda** (runtime, desligado por padrão). Em Shipping, o subsistema não é criado (`ShouldCreateSubsystem`) e o caminho de rede de `Send` nem é compilado. A pasta `GenAI/` torna as duas coisas fáceis de auditar.
- **Uma porta só (`Complete`) e uma saída só (`Resolve`)**, como o canal de rádio do Capítulo 44. `Resolve` tira o pedido do mapa **antes** de avisar: o callback pode pedir outra resposta, e uma segunda tentativa de resolver o mesmo Id (resposta depois do prazo) é ignorada.
- **No prazo vencido, resolve primeiro e cancela depois.** Se `CancelRequest` disparar o callback na hora, ele encontra o pedido já resolvido como `Timeout`.
- **Relógio de parede com `FTSTicker`.** O ticker do núcleo continua durante a pausa, como a rede. Um *timer* do mundo (`FTimerManager`) mede tempo de jogo, que pausa e dilata.
- **Modo falso por arquivo.** Uma resposta JSON com aspas e acentos é chata de digitar no console; num arquivo, você edita e testa de novo. Latência acima do prazo reproduz o `Timeout` sem rede.

---

## Projeto Vigília — o cliente de LLM, isolado

O que muda:

```text
Source/Vigilia/GenAI/
├── VGGenAISettings.h · VGLLMTypes.h · VGLLMRules.h/.cpp · VGLLMSubsystem.h/.cpp
Source/Vigilia/Tests/VGLLMRulesTest.cpp
Vigilia.Build.cs                    HTTP, Json; VG_WITH_GENAI
Saved/GenAI/fake_reply.txt          modo falso (não versionado)
tools/gateway/ · docs/ia/gateway.md o gateway e o contrato (seção 73.12)
```

**O que este capítulo ainda não faz:** nenhum sistema do jogo usa o cliente. Ele é infraestrutura, testada sozinha. O Capítulo 74 é o primeiro (e, por decisão, o único) consumidor.

**O protocolo do protótipo**, para que ele nunca vaze para a jogadora:

1. `vg.GenAI.Enabled` nasce `0`. Ninguém liga por padrão, nem em `DefaultEngine.ini`.
2. Em Shipping, nada disto existe. O **Capítulo 84** (build de release) registra por escrito a decisão de manter assim; mudar a linha do `Build.cs` é decisão de produto, com privacidade, segurança e regras de loja cumpridas.
3. O `DefaultGame.ini` contém só o endereço do gateway. Nenhuma chave, em nenhum arquivo do projeto do jogo.
4. Toda sessão de playtest com a funcionalidade ligada tem consentimento das pessoas para o que sai do dispositivo.

---

## Decisões arquiteturais

1. **O jogo decide, o modelo produz texto, o jogo valida.** O modelo nunca altera estado; filtros reduzem frequência, estrutura dá garantia.
2. **Gateway do projeto, nunca o fornecedor direto.** Chave, moderação, limite por instalação e *kill switch* moram nele.
3. **Nenhuma chamada bloqueia a game thread**, e toda chamada termina em exatamente um resultado, num prazo do jogo em relógio de parede.
4. **Reserva autorada sempre**, e cache com chave completa. O jogo é completo sem o modelo.
5. **Privacidade por construção** e **três camadas de teste** (regras, modo falso, avaliação versionada pelo prompt).
6. **Isolamento**: pasta `GenAI/`, `VG_WITH_GENAI` fora do Shipping, `vg.GenAI.Enabled = 0`.

---

## Armadilhas

- **Espera ativa na game thread**, ou qualquer chamada síncrona de rede no caminho do frame.
- **Chave de API no cliente**, em qualquer forma. Tudo o que vai no build é público.
- **Callback que toca num objeto morto.** Ligue de forma fraca; reconfira o mundo ao receber.
- **Tratar o *timeout* HTTP como o prazo do jogo**, ou medir o prazo no tempo de jogo. Um protege a conexão; o outro protege a ficção, em relógio de parede.
- **Cache sem a versão do prompt, o idioma ou o estado.** A resposta certa para outro estado é o pior bug de cache.
- **Montar JSON com `Printf`.** A primeira aspa na pergunta da jogadora quebra o protocolo; use o serializador.
- **Confiar numa instrução ao modelo como defesa** ("não fale sobre X"). Instruções reduzem; não garantem.
- **Logar o texto da jogadora** "para depurar".
- **Esquecer que `FText::FromString` não é localizável.**
- **Um jogo que só funciona com o modelo.** O serviço vai cair, ficar caro ou acabar.

---

## Exercício

**Parte 1 — o cliente (2 h).** Implemente os arquivos de `GenAI/` e o teste, e rode-o. Abra `Interfaces/IHttpRequest.h` da sua versão, confira a assinatura do delegate de conclusão e a política de thread, e registre ambas em `docs/ia/apis-verificadas.md`.

**Parte 2 — o modo falso (1 h).** Com `vg.GenAI.Enabled 1` e `vg.GenAI.Fake 1`, crie um *cheat* temporário que chame `Complete` com um pedido de teste e imprima o resultado. Reproduza os cinco resultados: `Ok` (qualquer conteúdo no `fake_reply.txt`: o modo falso devolve o arquivo inteiro como texto, sem o envelope `{"text": …}` do gateway), `Cached` (o mesmo pedido de novo), `Timeout` (`vg.GenAI.FakeLatency 5`), `Refused` (orçamento: sete pedidos seguidos com o limite em 6) e `Refused` por estar desligado. Acompanhe tudo com `vg.Debug.GenAI`.

**Parte 3 — o gateway (2 h).** Escreva o gateway da seção 73.12 na sua linguagem preferida: primeiro com resposta fixa, depois encaminhando para um modelo local ou na nuvem, conforme a documentação atual. Faça-o dormir 5 s de propósito e confirme, no jogo, `Timeout` sem travamento.

**Parte 4 — privacidade (45 min).** Escreva o texto de consentimento: o que sai do dispositivo, para onde, por quanto tempo, o que acontece se a jogadora recusar. Confira nos termos do serviço o que o fornecedor faz com o texto recebido e registre em `docs/ia/gateway.md`.

---

## Desafio — o disjuntor

Quando o gateway está fora do ar, cada pergunta espera o prazo inteiro (3 s) antes de cair na reserva. Implemente um ***circuit breaker*** no `UVGLLMSubsystem`:

1. Depois de N resultados `Failed` ou `Timeout` seguidos, o disjuntor **abre**: por M segundos, `Complete` responde `Refused` imediatamente, sem tentar a rede.
2. Passado esse tempo, o disjuntor fica **meio aberto**: deixa passar **um** pedido. Se ele der certo, fecha; se falhar, abre de novo.
3. Escreva a lógica de estados como regra pura em `VGLLMRules`, com casos no teste existente, e mostre o estado no `vg.Debug.GenAI`.

Responda no `DEVLOG.md`: qual relógio o disjuntor usa, e por quê? Que N e M fazem sentido para uma sessão de 15 minutos com algumas dezenas de perguntas?

---

## Uso de IA

Prompts meta, para avaliar o uso de IA **dentro** do jogo antes de escrever código:

1. **Para argumentar contra a funcionalidade:**
   > "Quero colocar um modelo de linguagem em runtime no meu jogo para [funcionalidade]. Faça o papel de quem é contra. Dê os cinco argumentos mais fortes (latência, custo recorrente, segurança, privacidade, controle de design, ludonarrativa), e para cada um a pergunta que eu precisaria responder com uma medição ou um playtest antes de seguir."

2. **Para checar se o problema pede um modelo em runtime:**
   > "Descrevo abaixo o problema de design. Responda só isto: a ENTRADA é aberta (texto livre da jogadora) ou enumerável? A SAÍDA precisa ser gerada no momento, ou pode ser escrita/gerada antes e escolhida por regras? Se as duas respostas apontarem para 'enumerável' e 'antes', diga qual sistema autoral resolveria. [problema]"

3. **Para desenhar a avaliação antes do prompt:**
   > "Para a tarefa [classificar perguntas da jogadora em N intenções], me ajude a montar o conjunto de avaliação ANTES de eu escrever o prompt: categorias de pergunta, quantas de cada, casos adversariais (injeção, fora de escopo, ambíguas), e as métricas que vou acompanhar a cada versão do prompt. Não escreva o prompt."

**Cuidado específico:** pedida para integrar um modelo de linguagem, uma IA tende ao caminho dos tutoriais: API do fornecedor chamada do cliente, chave numa configuração, às vezes espera síncrona. Os três são inaceitáveis num jogo. Peça o desenho com gateway, prazo, reserva e callback na game thread, e confira cada um no diff.

---

## Checklist

- [ ] Sei desenhar a anatomia de uma chamada e dizer o que é responsabilidade do jogo, do gateway e do modelo.
- [ ] Sei acomodar latência, por que o rádio é um bom lugar para ela e por que *streaming* briga com validação.
- [ ] Sei a forma do custo e comparar nuvem e modelo local, incluindo a disputa com o orçamento de frame.
- [ ] Implementei um cliente que nunca bloqueia, com callback na game thread, prazo em relógio de parede, reserva, cache e orçamento.
- [ ] Sei por que a defesa contra *prompt injection* é fechar a saída e não dar poder ao modelo.
- [ ] Sei os requisitos mínimos de privacidade, as três camadas de teste e por que texto gerado não é localizável.
- [ ] O protótipo está fora do Shipping e desligado por padrão.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): a referência de API do módulo **HTTP** (`FHttpModule`, `IHttpRequest`), de **Json**, de **Developer Settings** e de **Internationalization**. Leia também os headers da sua versão: são a fonte da verdade sobre threads e delegates.
- **OWASP Top 10 for Large Language Model Applications** (owasp.org): a lista de riscos de aplicações com modelos de linguagem, com *prompt injection* no topo, e as mitigações discutidas pela comunidade de segurança.
- **Michael T. Nygard, *Release It!*.** *Timeouts*, *circuit breakers*, *bulkheads* e *fail fast*: o repertório de resiliência que o gateway e o cliente deste capítulo aplicam.
- **Lei Geral de Proteção de Dados** (Lei 13.709/2018), texto oficial em planalto.gov.br, e a documentação da Autoridade Nacional de Proteção de Dados.
- **A documentação atual** do provedor de modelos ou do runtime local que o seu gateway usar: formatos, limites, retenção de dados e preços mudam rápido, e são o tipo de informação que nenhum livro deve fixar.

---

➡️ **Próximo:** [Capítulo 74 — NPCs com IA generativa](cap-74-npcs-ia-generativa.md)
